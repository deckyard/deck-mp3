# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - M3U and M3U8 playlists.
# Spliced into mp3.j via include - not a standalone module.

/** The duration an `#EXTINF` line carries when it does not know one. */
export def const DURATION_UNKNOWN as int init -1;

/** The line an extended M3U playlist opens with. */
def const EXTM3U as string init "#EXTM3U";

/** The code point a UTF-8 byte-order mark decodes to. */
def const BOM as int init 0xfeff;

/**
 * One entry of a playlist.
 *
 * Everything but `path` comes from the `#EXT...` lines before it, and is
 * empty in a plain playlist.
 *
 * @field path {string} the file, as written in the playlist
 * @field title {string} what to show, conventionally `artist - title`
 * @field duration {int} how long it plays in seconds, or `DURATION_UNKNOWN`
 * @field group {string} the `#EXTGRP` group the entry belongs to
 * @field album {string} the `#EXTALB` album
 * @field artist {string} the `#EXTART` artist
 */
export def struct PlaylistEntry {
    path as string,
    title as string,
    duration as int,
    group as string,
    album as string,
    artist as string
};

/**
 * A playlist.
 *
 * @field title {string} the `#PLAYLIST` name, or `""`
 * @field extended {bool} whether the file opened with `#EXTM3U`
 * @field entries {list of PlaylistEntry} the entries, in order
 */
export def struct Playlist {
    title as string,
    extended as bool,
    entries as list of PlaylistEntry
};

/**
 * An empty extended playlist.
 *
 * @return {Playlist} no title, no entries, `extended` true
 * @example
 *   def pl as mp3.Playlist init mp3.newPlaylist();
 *   $pl = mp3.addEntry($pl, mp3.entryFromTrack($track));
 */
export func newPlaylist() {
    return Playlist{title: "", extended: true, entries: []};
}

/**
 * Build one playlist entry.
 *
 * @param path {string} the file to play
 * @param title {string} what to show
 * @param duration {int} how long it plays in seconds, or `DURATION_UNKNOWN`
 * @return {PlaylistEntry} the entry
 */
export func playlistEntry(path as string, title as string, duration as int) {
    return PlaylistEntry{
        path: $path,
        title: $title,
        duration: $duration,
        group: "",
        album: "",
        artist: ""
    };
}

/**
 * Append an entry to a playlist.
 *
 * Copies the entry list, so calling it once per track is quadratic: 2000
 * entries take seconds. For more than a handful, append to a
 * `list of PlaylistEntry` with `$xs[]` and assign the field once:
 *
 *     def entries as list of PlaylistEntry init [];
 *     for (def t in $tracks) { $entries[] = entryFromTrack($t); }
 *     $pl.entries = $entries;
 *
 * {@link addEntries} appends a list you already have with one copy.
 *
 * @param playlist {Playlist} the playlist to add to
 * @param entry {PlaylistEntry} the entry to append
 * @return {Playlist} a fresh playlist; the argument is not changed
 */
export func addEntry(playlist as Playlist, entry as PlaylistEntry) {
    def entries as list of PlaylistEntry init $playlist.entries;
    $entries[] = $entry;
    return Playlist{title: $playlist.title, extended: $playlist.extended, entries: $entries};
}

/**
 * Append several entries to a playlist.
 *
 * One copy of the entry list for the whole batch.
 *
 * @param playlist {Playlist} the playlist to add to
 * @param entries {list of PlaylistEntry} the entries to append, in order
 * @return {Playlist} a fresh playlist; neither argument is changed
 * @example
 *   $pl = mp3.addEntries($pl, $album);
 */
export func addEntries(playlist as Playlist, entries as list of PlaylistEntry) {
    def grown as list of PlaylistEntry init $playlist.entries;
    for (def e in $entries) {
        $grown[] = $e;
    }
    return Playlist{title: $playlist.title, extended: $playlist.extended, entries: $grown};
}

/**
 * Build a playlist entry from a track that has been read.
 *
 * The title is `artist - title` when the tag has both, otherwise whichever
 * one it has, otherwise the base name of `track.path`. `album` and `artist`
 * are copied from the tag. The duration is the stream's, rounded to the
 * nearest second, or `DURATION_UNKNOWN` when the track has no audio.
 *
 * @param track {Track} a track read by {@link open}
 * @return {PlaylistEntry} the entry, pointing at `track.path`
 * @example
 *   $pl = mp3.addEntry($pl, mp3.entryFromTrack(mp3.open("song.mp3")));
 */
export func entryFromTrack(track as Track) {
    def entry as PlaylistEntry init playlistEntry($track.path, "", DURATION_UNKNOWN);
    $entry.title = entryTitle($track);
    $entry.album = $track.tag.album;
    $entry.artist = $track.tag.artist;
    if ($track.audio.present and $track.audio.durationMs > 0) {
        $entry.duration = ($track.audio.durationMs + 500) // 1000;
    }
    return $entry;
}

/**
 * What to show for a track in a playlist.
 *
 * @param track {Track} the track
 * @return {string} `artist - title`, the title, the artist, or the base name
 */
func entryTitle(track as Track) {
    def who as string init $track.tag.artist;
    def what as string init $track.tag.title;
    if ($who != "" and $what != "") {
        return $who + " - " + $what;
    }
    if ($what != "") {
        return $what;
    }
    if ($who != "") {
        return $who;
    }
    if ($track.path == "") {
        return "";
    }
    return path.base($track.path);
}

/**
 * Read a playlist.
 *
 * Reads plain and extended M3U. An `#EXTINF` with attributes before its comma
 * (the IPTV form) keeps its leading duration and drops the attributes.
 * Unknown `#` lines and blank lines are skipped, a leading BOM is dropped, and
 * nothing in the text raises an error. Appends with {@link addEntry}, so the
 * cost is quadratic in the number of entries.
 *
 * @param text {string} the playlist
 * @return {Playlist} the entries, in order
 * @example
 *   def pl as mp3.Playlist init mp3.parsePlaylist($text);
 *   for (def e in $pl.entries) { io.printf("%s\n", $e.path); }
 */
export func parsePlaylist(text as string) {
    def playlist as Playlist init Playlist{title: "", extended: false, entries: []};
    def pending as PlaylistEntry init playlistEntry("", "", DURATION_UNKNOWN);
    def group as string init "";
    def lines as list of string init strings.split(stripBom($text), "\n");

    for (def raw in $lines) {
        def line as string init strings.trim($raw);
        if ($line == "") {
            continue;
        }
        if (strings.startsWith($line, "#")) {
            if ($line == EXTM3U) {
                $playlist.extended = true;
                continue;
            }
            if (strings.startsWith($line, "#PLAYLIST:")) {
                $playlist.title = strings.trim(strings.substring($line, 10));
                continue;
            }
            if (strings.startsWith($line, "#EXTGRP:")) {
                $group = strings.trim(strings.substring($line, 8));
                continue;
            }
            if (strings.startsWith($line, "#EXTALB:")) {
                $pending.album = strings.trim(strings.substring($line, 8));
                continue;
            }
            if (strings.startsWith($line, "#EXTART:")) {
                $pending.artist = strings.trim(strings.substring($line, 8));
                continue;
            }
            if (strings.startsWith($line, "#EXTINF:")) {
                $pending = readExtinf($pending, strings.substring($line, 8));
                $playlist.extended = true;
            }
            continue;
        }
        $pending.path = $line;
        $pending.group = $group;
        $playlist = addEntry($playlist, $pending);
        $pending = playlistEntry("", "", DURATION_UNKNOWN);
    }
    return $playlist;
}

/**
 * Read the body of an `#EXTINF:` line into the entry it describes.
 *
 * The duration comes first; everything after the first comma is the title.
 * A negative duration means the length is not known.
 *
 * @param entry {PlaylistEntry} the entry being built
 * @param body {string} the line after `#EXTINF:`
 * @return {PlaylistEntry} a fresh entry with the duration and title set
 */
func readExtinf(entry as PlaylistEntry, body as string) {
    def out as PlaylistEntry init $entry;
    def cut as int init strings.indexOf($body, ",");
    def head as string init $body;
    if ($cut >= 0) {
        $head = strings.substring($body, 0, $cut);
        $out.title = strings.trim(strings.substring($body, $cut + 1));
    }
    $out.duration = readDuration(strings.trim($head));
    return $out;
}

/**
 * The duration an `#EXTINF` head states.
 *
 * @param head {string} the text before the comma
 * @return {int} whole seconds, or `DURATION_UNKNOWN`
 */
func readDuration(head as string) {
    if (strings.startsWith($head, "-")) {
        return DURATION_UNKNOWN;
    }
    if ($head == "") {
        return DURATION_UNKNOWN;
    }
    def seconds as int init leadingInt($head);
    if ($seconds == 0 and not strings.startsWith($head, "0")) {
        return DURATION_UNKNOWN;
    }
    return $seconds;
}

/**
 * Drop a leading byte-order mark.
 *
 * @param text {string} the decoded playlist
 * @return {string} the text without its mark
 */
func stripBom(text as string) {
    if ($text == "") {
        return $text;
    }
    def first as string init strings.substring($text, 0, 1);
    if (convert.toCodepoint($first) != BOM) {
        return $text;
    }
    return strings.substring($text, 1);
}

/**
 * Render a playlist.
 *
 * An extended playlist opens with `#EXTM3U`, then `#PLAYLIST` when `title` is
 * set, and an `#EXTINF` line per entry, with `#EXTGRP` where the group
 * changes to a non-empty value. `album` and `artist` are not written. A plain
 * playlist is paths only. Lines end in `\n`.
 *
 * @param playlist {Playlist} the playlist to render
 * @return {string} the playlist text, ending in a newline; `""` when empty
 * @example
 *   fs.writeString("set.m3u8", mp3.buildPlaylist($pl));
 */
export func buildPlaylist(playlist as Playlist) {
    def lines as list of string init [];
    if ($playlist.extended) {
        $lines[] = EXTM3U;
        if ($playlist.title != "") {
            $lines[] = "#PLAYLIST:" + $playlist.title;
        }
    }
    # The group line is written inline rather than through a helper: threading
    # the growing line list through a call would deep-copy it per entry, which
    # is the quadratic shape JENNIFER.md warns about.
    def group as string init "";
    for (def e in $playlist.entries) {
        if (not $playlist.extended) {
            $lines[] = $e.path;
            continue;
        }
        if ($e.group != $group and $e.group != "") {
            $lines[] = "#EXTGRP:" + $e.group;
        }
        $group = $e.group;
        $lines[] = "#EXTINF:" + convert.toString($e.duration) + "," + $e.title;
        $lines[] = $e.path;
    }
    if (len($lines) == 0) {
        return "";
    }
    return strings.join($lines, "\n") + "\n";
}

/**
 * How long a playlist plays.
 *
 * Entries whose duration is unknown count as nothing.
 *
 * @param playlist {Playlist} the playlist to total
 * @return {int} seconds
 * @example
 *   mp3.formatDuration(mp3.playlistDuration($pl) * 1000);   # "1:14:02"
 */
export func playlistDuration(playlist as Playlist) {
    def total as int init 0;
    for (def e in $playlist.entries) {
        if ($e.duration > 0) {
            $total = $total + $e.duration;
        }
    }
    return $total;
}

/**
 * Resolve every relative entry path against a directory.
 *
 * Relative paths are joined onto `baseDir` and cleaned. Absolute paths,
 * empty paths and `http://`, `https://` and `file://` URLs are unchanged.
 *
 * Does not confine paths: an untrusted playlist can name `../../etc/passwd`
 * or an absolute path and still does afterwards. Check the results before
 * opening them.
 *
 * @param playlist {Playlist} the playlist to resolve
 * @param baseDir {string} the directory the playlist lives in
 * @return {Playlist} a fresh playlist; the argument is not changed
 * @example
 *   $pl = mp3.resolvePlaylist($pl, path.dir("/music/set.m3u8"));
 */
export func resolvePlaylist(playlist as Playlist, baseDir as string) {
    def out as Playlist init $playlist;
    def entries as list of PlaylistEntry init [];
    for (def e in $playlist.entries) {
        def resolved as PlaylistEntry init $e;
        if ($e.path != "" and not path.isAbs($e.path) and not isUrl($e.path)) {
            $resolved.path = path.clean(path.join($baseDir, $e.path));
        }
        $entries[] = $resolved;
    }
    $out.entries = $entries;
    return $out;
}

/**
 * Whether an entry names a URL rather than a file.
 *
 * Case-insensitive.
 *
 * @param entryPath {string} the entry's path
 * @return {bool} true when it starts with a scheme this deck leaves alone
 */
func isUrl(entryPath as string) {
    def lower as string init strings.lower($entryPath);
    if (strings.startsWith($lower, "http://") or strings.startsWith($lower, "https://")) {
        return true;
    }
    return strings.startsWith($lower, "file://");
}

/**
 * Read a playlist from disk.
 *
 * Decoded as UTF-8 when the bytes are valid UTF-8, otherwise as ISO-8859-1,
 * whatever the extension.
 *
 * @param playlistPath {string} the file to read
 * @return {Playlist} the entries, in order
 * @throws {Error} kind "runtime" from `fs` when the file cannot be read
 * @example
 *   def pl as mp3.Playlist init mp3.openPlaylist("/music/set.m3u8");
 */
export func openPlaylist(playlistPath as string) {
    def raw as bytes init fs.readBytes($playlistPath);
    def text as string init "";
    try {
        $text = convert.stringFromBytes($raw, "utf-8");
    } catch (e) {
        $text = decodeLatin1($raw);
    }
    return parsePlaylist($text);
}

/**
 * Write a playlist to disk.
 *
 * `.m3u8` (any case) is written as UTF-8. Any other extension is written as
 * ISO-8859-1 when every character fits, and as UTF-8 when one does not.
 *
 * @param playlist {Playlist} the playlist to write
 * @param playlistPath {string} where to write it
 * @throws {Error} kind "runtime" from `fs` when the file cannot be written
 * @example
 *   mp3.savePlaylist($pl, "/music/set.m3u8");
 */
export func savePlaylist(playlist as Playlist, playlistPath as string) {
    def text as string init buildPlaylist($playlist);
    def extension as string init strings.lower(path.ext($playlistPath));
    if ($extension != ".m3u8" and isLatin1($text)) {
        fs.writeBytes($playlistPath, latin1Bytes($text));
        return;
    }
    fs.writeBytes($playlistPath, convert.bytesFromString($text, "utf-8"));
}
