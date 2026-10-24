# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the whole file: where the audio is, and how to put a tag back.
# Spliced into mp3.j via include - not a standalone module.

/** How much padding {@link defaultOptions} leaves after the frames. */
export def const DEFAULT_PADDING as int init 1024;

/** The ID3v2 version {@link defaultOptions} writes. */
export def const DEFAULT_MAJOR as int init 4;

/** The suffix the atomic writer gives its temporary file. */
def const TEMP_SUFFIX as string init ".mp3tmp";

/**
 * The name of the temporary file the atomic writer builds the result in.
 *
 * It sits beside the target, because `fs.rename` cannot cross a filesystem,
 * and it carries a random component, because a fixed name beside the target
 * is a name an attacker who can write to that directory could create first -
 * as a symlink to somewhere else, which `fs.open` would follow. A v4 UUID is
 * crypto-grade random, so there is nothing to guess.
 *
 * @param target {string} where the finished file goes
 * @return {string} a path beside it that nothing else is using
 */
func tempPath(target as string) {
    return $target + "." + uuid.v4() + TEMP_SUFFIX;
}

/**
 * One MP3 file, read.
 *
 * Holds no audio bytes, so it is cheap to copy; {@link save} reads the file
 * again. `tag` is the ID3v2 tag merged over the ID3v1 tag; `id3v2` and
 * `id3v1` are the raw tags.
 *
 * @field path {string} where the file was read from, or `""` for a buffer
 * @field tag {Tag} the unified view of everything the file says
 * @field audio {AudioInfo} what the MPEG stream says
 * @field id3v2 {Id3v2} the ID3v2 tag, with every frame as stored
 * @field id3v1 {Id3v1} the ID3v1 tag
 */
export def struct Track {
    path as string,
    tag as Tag,
    audio as AudioInfo,
    id3v2 as Id3v2,
    id3v1 as Id3v1
};

/**
 * What to write, and how.
 *
 * @field major {int} the ID3v2 version to write: 2, 3 or 4
 * @field padding {int} how many NUL bytes to leave after the frames
 * @field id3v2 {bool} whether to write an ID3v2 tag at the front
 * @field id3v1 {bool} whether to write an ID3v1 tag at the end
 */
export def struct WriteOptions {
    major as int,
    padding as int,
    id3v2 as bool,
    id3v1 as bool
};

/**
 * Where the audio starts and ends within a file.
 *
 * @field start {int} the first audio byte, past any ID3v2 tag
 * @field end {int} one past the last, before any ID3v1 tag
 */
export def struct AudioRange {
    start as int,
    end as int
};

/**
 * The default write options: ID3v2.4, 1 KiB of padding, no ID3v1 tag.
 *
 * ID3v1 is off: next to an ID3v2 tag it is a lossy copy. Turn it on for
 * players that read nothing else, or use {@link optionsFor}.
 *
 * @return {WriteOptions} the defaults
 */
export func defaultOptions() {
    return WriteOptions{major: DEFAULT_MAJOR, padding: DEFAULT_PADDING, id3v2: true, id3v1: false};
}

/**
 * Write options that preserve what a file already had.
 *
 * The ID3v2 version it used, and an ID3v1 tag if and only if it carried one.
 * A file with no ID3v2 tag at all gets {@link DEFAULT_MAJOR}.
 *
 * @param track {Track} the file as read
 * @return {WriteOptions} options matching the file
 * @example
 *   def opts as mp3.WriteOptions init mp3.optionsFor($track);
 *   def out as bytes init mp3.write($data, $tag, $opts);
 */
export func optionsFor(track as Track) {
    def opts as WriteOptions init defaultOptions();
    if ($track.id3v2.present) {
        $opts.major = $track.id3v2.major;
    }
    $opts.id3v1 = $track.id3v1.present;
    return $opts;
}

/**
 * Where the MPEG audio sits inside a file.
 *
 * Excludes the ID3v2 tag at the front and the ID3v1 tag at the end. APE,
 * Lyrics3 and `TAG+` blocks are not recognised and count as audio.
 *
 * @param data {bytes} the whole file
 * @return {AudioRange} the half-open range of audio bytes
 * @example
 *   def r as mp3.AudioRange init mp3.audioRange($data);
 *   io.printf("%d audio bytes\n", $r.end - $r.start);
 */
export func audioRange(data as bytes) {
    def start as int init id3v2Size($data);
    def end as int init len($data);
    def v1 as int init id3v1Offset($data);
    if ($v1 >= $start) {
        $end = $v1;
    }
    if ($start > $end) {
        $start = $end;
    }
    return AudioRange{start: $start, end: $end};
}

/**
 * The MPEG audio of a file, with every tag taken off.
 *
 * @param data {bytes} the whole file
 * @return {bytes} the audio stream alone
 * @example
 *   fs.writeBytes("bare.mp3", mp3.strip(fs.readBytes("tagged.mp3")));
 */
export func strip(data as bytes) {
    def range as AudioRange init audioRange($data);
    return binary.slice($data, $range.start, $range.end);
}

/**
 * Read an MP3 out of a buffer.
 *
 * Reads both tags and the stream. `tag` is the ID3v2 tag merged over the
 * ID3v1 tag (see {@link mergeTags}). Does not throw on malformed content.
 *
 * @param data {bytes} the whole file
 * @return {Track} everything the file says; `path` is `""`
 * @example
 *   def track as mp3.Track init mp3.parse(fs.readBytes("song.mp3"));
 *   io.printf("%s\n", $track.tag.title);
 */
export func parse(data as bytes) {
    return parseWith($data, true);
}

/**
 * Read an MP3 out of a buffer, choosing whether to count every frame.
 *
 * With `scan` false, a file with no VBR header gets an estimated duration
 * (`audio.exact` false); see {@link readAudioWith}.
 *
 * @param data {bytes} the whole file
 * @param scan {bool} whether to walk the frame chain when nothing states its
 *     length
 * @return {Track} everything the file says
 */
export func parseWith(data as bytes, scan as bool) {
    def track as Track;
    def range as AudioRange init audioRange($data);
    $track.id3v2 = readId3v2($data);
    $track.id3v1 = readId3v1($data);
    $track.audio = readAudioWith($data, $range.start, $range.end, $scan);
    $track.tag = mergeTags(tagFromId3v2($track.id3v2), tagFromId3v1($track.id3v1));
    return $track;
}

/**
 * Read an MP3 from disk.
 *
 * @param path {string} the file to read
 * @return {Track} everything the file says, with `path` set
 * @throws {Error} kind "runtime" from `fs` when the file cannot be read
 * @example
 *   def track as mp3.Track init mp3.open("song.mp3");
 *   io.printf("%s - %s\n", $track.tag.artist, $track.tag.title);
 */
export func open(path as string) {
    def track as Track init parse(fs.readBytes($path));
    $track.path = $path;
    return $track;
}

/**
 * The same track with a different tag.
 *
 * @param track {Track} the track to change
 * @param tag {Tag} the tag to put on it
 * @return {Track} a fresh track; the argument is not changed
 * @example
 *   def tag as mp3.Tag init $track.tag;
 *   $tag.genre = "Ambient";
 *   $track = mp3.withTag($track, $tag);
 */
export func withTag(track as Track, tag as Tag) {
    def out as Track init $track;
    $out.tag = $tag;
    return $out;
}

/**
 * Rebuild a file with a new tag.
 *
 * Copies the audio byte for byte and writes new tags as `options` says. The
 * old tags are discarded, including frames {@link Tag} does not name; use
 * {@link renderId3v2} with frames from {@link readId3v2} to keep them.
 *
 * @param data {bytes} the whole file as it is now
 * @param tag {Tag} the tag to write
 * @param options {WriteOptions} what to write
 * @return {bytes} the new file
 * @throws {Error} kind "mp3" when `options.major` is not 2-4 or
 *     `options.padding` is negative
 * @example
 *   def out as bytes init mp3.write($data, $tag, mp3.defaultOptions());
 */
export func write(data as bytes, tag as Tag, options as WriteOptions) {
    def parts as list of bytes init [];
    def head as bytes init headerBytes($tag, $options);
    if (len($head) > 0) {
        $parts[] = $head;
    }
    $parts[] = strip($data);
    def tail as bytes init trailerBytes($tag, $options);
    if (len($tail) > 0) {
        $parts[] = $tail;
    }
    return binary.join($parts);
}

/**
 * The ID3v2 tag to put in front of the audio, if any.
 *
 * @param tag {Tag} the tag to write
 * @param options {WriteOptions} what to write
 * @return {bytes} the rendered tag, or no bytes
 */
func headerBytes(tag as Tag, options as WriteOptions) {
    if (not $options.id3v2) {
        return binary.make(0);
    }
    def frames as list of Id3v2Frame init framesFromTag($tag, $options.major);
    return renderId3v2($frames, $options.major, $options.padding);
}

/**
 * The ID3v1 tag to put after the audio, if any.
 *
 * @param tag {Tag} the tag to write
 * @param options {WriteOptions} what to write
 * @return {bytes} the 128-byte tag, or no bytes
 */
func trailerBytes(tag as Tag, options as WriteOptions) {
    if (not $options.id3v1) {
        return binary.make(0);
    }
    return renderId3v1(id3v1FromTag($tag));
}

/**
 * Write a file's audio out under a new tag, atomically.
 *
 * The new file is built beside the target under an unguessable name and
 * renamed over it, so an interrupted write cannot leave a half-tagged file
 * where the original was, and nothing can pre-create the temporary file to
 * redirect the write. Source and target may be the same path.
 *
 * Being a rename, it replaces the target rather than writing through it: a
 * target that was a symlink becomes a regular file, and a hard link to it
 * stops sharing.
 *
 * The audio is streamed from the source buffer to the file, so a write holds
 * one copy of the audio in memory, not two.
 *
 * @param source {string} the file to take the audio from
 * @param target {string} where to write the result
 * @param tag {Tag} the tag to write
 * @param options {WriteOptions} what to write
 * @throws {Error} kind "mp3" for invalid `options`; kind "runtime" from
 *     `fs` when the source cannot be read or the target cannot be written
 * @example
 *   mp3.writeFile("song.mp3", "song.mp3", $tag, mp3.defaultOptions());
 */
export func writeFile(source as string, target as string, tag as Tag, options as WriteOptions) {
    def data as bytes init fs.readBytes($source);
    def range as AudioRange init audioRange($data);
    def head as bytes init headerBytes($tag, $options);
    def tail as bytes init trailerBytes($tag, $options);
    def temp as string init tempPath($target);
    errdefer removeQuietly($temp);
    streamOut($temp, $head, $data, $range, $tail);
    fs.rename($temp, $target);
}

/**
 * Write the three pieces of a file to a fresh handle.
 *
 * Split out so the handle's `defer fs.close` runs before the caller renames.
 *
 * @param temp {string} the file to create
 * @param head {bytes} the ID3v2 tag, or no bytes
 * @param data {bytes} the source file
 * @param range {AudioRange} which bytes of it are audio
 * @param tail {bytes} the ID3v1 tag, or no bytes
 * @throws {Error} when the file cannot be written
 */
func streamOut(temp as string, head as bytes, data as bytes, range as AudioRange, tail as bytes) {
    def handle as fs.File init fs.open($temp, "write");
    defer fs.close($handle);
    if (len($head) > 0) {
        fs.writeBytes($handle, $head);
    }
    if ($range.end > $range.start) {
        fs.writeBytes($handle, binary.slice($data, $range.start, $range.end));
    }
    if (len($tail) > 0) {
        fs.writeBytes($handle, $tail);
    }
}

/**
 * Remove a file, ignoring the failure to.
 *
 * The cleanup path of a failed write: the write already threw, and the
 * reason the temporary file cannot be removed is not the one worth
 * reporting.
 *
 * @param path {string} the file to remove
 */
func removeQuietly(path as string) {
    try {
        if (fs.exists($path)) {
            fs.remove($path);
        }
    } catch (e) {
        return;
    }
}

/**
 * Write a track's tag back to disk.
 *
 * The audio comes from `track.path`, which is read again: a `Track` holds no
 * audio of its own. The options are {@link optionsFor} the track, so the
 * file keeps the ID3v2 version it had and keeps or omits its ID3v1 tag to
 * match.
 *
 * @param track {Track} the track to write; its `path` is the source
 * @param target {string} where to write it, which may be `track.path`
 * @throws {Error} kind "mp3" when `track.path` is empty; kind "runtime"
 *     from `fs` when a file cannot be read or written
 * @example
 *   def tag as mp3.Tag init $track.tag;
 *   $tag.title = "Ich war müde leer nicht mehr da";
 *   mp3.save(mp3.withTag($track, $tag), $track.path);
 */
export func save(track as Track, target as string) {
    if ($track.path == "") {
        fail("this track was parsed from a buffer and has no source file");
    }
    writeFile($track.path, $target, $track.tag, optionsFor($track));
}

/**
 * A one-line summary of a track.
 *
 * Fields are separated by two spaces: `artist - title` (or whichever is
 * set), duration, bitrate with `VBR` when variable, sampling rate, channel
 * mode. A track with no audio ends in `no audio`.
 *
 * @param track {Track} the track to describe
 * @return {string} the summary line
 * @example
 *   mp3.describe($track);
 *   # "Maike Vandervaart - Ich war müde leer nicht mehr da  4:18  160 kbit/s VBR  44100 Hz  stereo"
 */
export func describe(track as Track) {
    def parts as list of string init [];
    def who as string init $track.tag.artist;
    def what as string init $track.tag.title;
    if ($who != "" and $what != "") {
        $parts[] = $who + " - " + $what;
    } elseif ($what != "") {
        $parts[] = $what;
    } elseif ($who != "") {
        $parts[] = $who;
    }
    if (not $track.audio.present) {
        $parts[] = "no audio";
        return strings.join($parts, "  ");
    }
    $parts[] = formatDuration($track.audio.durationMs);
    def rate as string init convert.toString($track.audio.bitrate // 1000) + " kbit/s";
    if ($track.audio.vbr) {
        $rate = $rate + " VBR";
    }
    $parts[] = $rate;
    $parts[] = convert.toString($track.audio.sampleRate) + " Hz";
    $parts[] = channelModeName($track.audio.channelMode);
    return strings.join($parts, "  ");
}
