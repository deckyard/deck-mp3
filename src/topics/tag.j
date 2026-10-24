# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the version-independent view of a tag, and the mapping under it.
# Spliced into mp3.j via include - not a standalone module.

/**
 * What an `APIC` picture shows, by its numeric type, 0-20.
 *
 * Index 17, "A bright coloured fish", is in the ID3v2 specification.
 */
export def const PICTURE_TYPES as list of string init [
    "Other",
    "32x32 file icon",
    "Other file icon",
    "Cover (front)",
    "Cover (back)",
    "Leaflet page",
    "Media",
    "Lead artist",
    "Artist",
    "Conductor",
    "Band",
    "Composer",
    "Lyricist",
    "Recording location",
    "During recording",
    "During performance",
    "Movie screen capture",
    "A bright coloured fish",
    "Illustration",
    "Band logotype",
    "Publisher logotype"
];

/** The `APIC` picture type for the front cover, the one players show. */
export def const PICTURE_FRONT_COVER as int init 3;

# ID3v2.2 used three-character frame identifiers; ID3v2.3 renamed every one
# of them to four. Reading normalises to the four-character form, so the rest
# of the deck only ever sees one spelling, and writing ID3v2.2 maps back.
def const V22_TO_V23 as map of string to string init {
    "TT1": "TIT1",
    "TT2": "TIT2",
    "TT3": "TIT3",
    "TP1": "TPE1",
    "TP2": "TPE2",
    "TP3": "TPE3",
    "TP4": "TPE4",
    "TAL": "TALB",
    "TCM": "TCOM",
    "TXT": "TEXT",
    "TCO": "TCON",
    "TRK": "TRCK",
    "TPA": "TPOS",
    "TYE": "TYER",
    "TDA": "TDAT",
    "TIM": "TIME",
    "TRD": "TRDA",
    "TLE": "TLEN",
    "TBP": "TBPM",
    "TPB": "TPUB",
    "TEN": "TENC",
    "TCR": "TCOP",
    "TSS": "TSSE",
    "TOT": "TOAL",
    "TOA": "TOPE",
    "TOL": "TOLY",
    "TOR": "TORY",
    "TRC": "TSRC",
    "TKE": "TKEY",
    "TLA": "TLAN",
    "TMT": "TMED",
    "TFT": "TFLT",
    "TDY": "TDLY",
    "TXX": "TXXX",
    "COM": "COMM",
    "ULT": "USLT",
    "PIC": "APIC",
    "GEO": "GEOB",
    "CNT": "PCNT",
    "POP": "POPM",
    "UFI": "UFID",
    "SLT": "SYLT",
    "MCI": "MCDI",
    "WAR": "WOAR",
    "WAF": "WOAF",
    "WAS": "WOAS",
    "WCM": "WCOM",
    "WCP": "WCOP",
    "WPB": "WPUB",
    "WXX": "WXXX"
};

def const V23_TO_V22 as map of string to string init {
    "TIT1": "TT1",
    "TIT2": "TT2",
    "TIT3": "TT3",
    "TPE1": "TP1",
    "TPE2": "TP2",
    "TPE3": "TP3",
    "TPE4": "TP4",
    "TALB": "TAL",
    "TCOM": "TCM",
    "TEXT": "TXT",
    "TCON": "TCO",
    "TRCK": "TRK",
    "TPOS": "TPA",
    "TYER": "TYE",
    "TDAT": "TDA",
    "TIME": "TIM",
    "TRDA": "TRD",
    "TLEN": "TLE",
    "TBPM": "TBP",
    "TPUB": "TPB",
    "TENC": "TEN",
    "TCOP": "TCR",
    "TSSE": "TSS",
    "TOAL": "TOT",
    "TOPE": "TOA",
    "TOLY": "TOL",
    "TORY": "TOR",
    "TSRC": "TRC",
    "TKEY": "TKE",
    "TLAN": "TLA",
    "TMED": "TMT",
    "TFLT": "TFT",
    "TDLY": "TDY",
    "TXXX": "TXX",
    "COMM": "COM",
    "USLT": "ULT",
    "APIC": "PIC",
    "GEOB": "GEO",
    "PCNT": "CNT",
    "POPM": "POP",
    "UFID": "UFI",
    "SYLT": "SLT",
    "MCDI": "MCI",
    "WOAR": "WAR",
    "WOAF": "WAF",
    "WOAS": "WAS",
    "WCOM": "WCM",
    "WCOP": "WCP",
    "WPUB": "WPB",
    "WXXX": "WXX"
};

/**
 * One embedded picture.
 *
 * @field mimeType {string} the media type, `"image/jpeg"` or `"image/png"`
 *     in practice; ID3v2.2's three-letter image format is mapped onto it
 * @field kind {int} the picture type, an index into {@link PICTURE_TYPES}
 * @field description {string} a short label, often empty
 * @field data {bytes} the image itself
 */
export def struct Picture {
    mimeType as string,
    kind as int,
    description as string,
    data as bytes
};

/**
 * One comment.
 *
 * Players show the one with an empty description. Taggers add others keyed
 * by description, such as iTunes' `iTunNORM` and `iTunSMPB`.
 *
 * @field language {string} the ISO-639-2 language code, `"eng"` by default
 * @field description {string} what distinguishes this comment from the others
 * @field text {string} the comment itself
 */
export def struct Comment {
    language as string,
    description as string,
    text as string
};

/**
 * Everything a tag says, independent of which version said it.
 *
 * Filled from ID3v2.2, 2.3, 2.4 or ID3v1, and rendered back by
 * {@link framesFromTag} and {@link id3v1FromTag}. A missing value is `""`,
 * `0` or empty. `extra` holds the `TXXX` frames (MusicBrainz ids, ReplayGain
 * values) by description.
 *
 * @field title {string} the track title
 * @field artist {string} the performing artist
 * @field album {string} the album title
 * @field albumArtist {string} the album's artist, when it differs
 * @field composer {string} who wrote it
 * @field genre {string} the genre as text, with numeric references resolved
 * @field year {string} the four-digit year
 * @field date {string} the `TDRC` or `TDRL` timestamp, else the year
 * @field track {int} the track number, or `0`
 * @field trackTotal {int} how many tracks the release has, or `0`
 * @field disc {int} the disc number, or `0`
 * @field discTotal {int} how many discs the release has, or `0`
 * @field bpm {int} beats per minute, or `0`
 * @field publisher {string} the label
 * @field encodedBy {string} the encoding software or person
 * @field copyright {string} the copyright notice
 * @field lyrics {string} the unsynchronised lyrics
 * @field comments {list of Comment} every comment, in the order stored
 * @field pictures {list of Picture} every embedded picture
 * @field extra {map of string to string} the `TXXX` frames, by description
 */
export def struct Tag {
    title as string,
    artist as string,
    album as string,
    albumArtist as string,
    composer as string,
    genre as string,
    year as string,
    date as string,
    track as int,
    trackTotal as int,
    disc as int,
    discTotal as int,
    bpm as int,
    publisher as string,
    encodedBy as string,
    copyright as string,
    lyrics as string,
    comments as list of Comment,
    pictures as list of Picture,
    extra as map of string to string
};

/**
 * A tag with nothing in it.
 *
 * The same as the zero value of `Tag`, for use in an expression.
 *
 * @return {Tag} every field empty
 * @example
 *   def tag as mp3.Tag init mp3.emptyTag();
 *   $tag.title = "Ich war müde leer nicht mehr da";
 */
export func emptyTag() {
    def tag as Tag;
    return $tag;
}

/**
 * The four-character name of a frame identifier.
 *
 * Maps an ID3v2.2 three-character identifier to its ID3v2.3 name; any other
 * id is returned unchanged.
 *
 * @param id {string} the identifier as stored
 * @return {string} the ID3v2.3 identifier
 * @example
 *   mp3.canonicalFrameId("TT2");    # "TIT2"
 *   mp3.canonicalFrameId("TIT2");   # "TIT2"
 */
export func canonicalFrameId(id as string) {
    if (maps.has(V22_TO_V23, $id)) {
        return V22_TO_V23[$id];
    }
    return $id;
}

/**
 * The name a frame identifier has in one ID3v2 version.
 *
 * @param id {string} the canonical four-character identifier
 * @param major {int} the ID3v2 major version to write
 * @return {string} the three-character form on ID3v2.2, else `id`
 * @throws {Error} when ID3v2.2 has no name for the frame
 */
func versionFrameId(id as string, major as int) {
    if ($major != 2) {
        return $id;
    }
    if (not maps.has(V23_TO_V22, $id)) {
        fail("ID3v2.2 has no frame for " + $id);
    }
    return V23_TO_V22[$id];
}

/**
 * Read an ID3v2 tag into the version-independent view.
 *
 * Every `COMM` and `APIC` is kept. For a repeated text frame, `USLT`, or
 * `TXXX` with the same description, the first wins. The year comes from
 * `TDRC`, else `TDRL`, else `TYER`; `TCON` goes through {@link resolveGenre}.
 *
 * @param id3 {Id3v2} the tag to read
 * @return {Tag} the unified view; an absent tag gives an empty one
 * @example
 *   def tag as mp3.Tag init mp3.tagFromId3v2(mp3.readId3v2($data));
 */
export func tagFromId3v2(id3 as Id3v2) {
    def tag as Tag;
    if (not $id3.present) {
        return $tag;
    }
    def texts as map of string to string init {};
    def comments as list of Comment init [];
    def pictures as list of Picture init [];
    def extra as map of string to string init {};
    def lyrics as string init "";

    for (def f in $id3.frames) {
        def id as string init canonicalFrameId($f.id);
        if ($id == "TXXX") {
            def key as string init frameDescription($f);
            if (not maps.has($extra, $key)) {
                $extra[$key] = frameText($f);
            }
            continue;
        }
        if ($id == "COMM") {
            $comments[] = commentOf($f);
            continue;
        }
        if ($id == "APIC") {
            $pictures[] = pictureOf($f, $id3.major);
            continue;
        }
        if ($id == "USLT") {
            if ($lyrics == "") {
                $lyrics = commentOf($f).text;
            }
            continue;
        }
        if (strings.startsWith($id, "T") and not maps.has($texts, $id)) {
            $texts[$id] = frameText($f);
        }
    }

    $tag.title = textOr($texts, "TIT2");
    $tag.artist = textOr($texts, "TPE1");
    $tag.album = textOr($texts, "TALB");
    $tag.albumArtist = textOr($texts, "TPE2");
    $tag.composer = textOr($texts, "TCOM");
    $tag.genre = resolveGenre(textOr($texts, "TCON"));
    $tag.publisher = textOr($texts, "TPUB");
    $tag.encodedBy = textOr($texts, "TENC");
    $tag.copyright = textOr($texts, "TCOP");
    $tag.bpm = leadingInt(textOr($texts, "TBPM"));
    $tag.lyrics = $lyrics;
    $tag.comments = $comments;
    $tag.pictures = $pictures;
    $tag.extra = $extra;

    def track as Pair init splitPair(textOr($texts, "TRCK"));
    $tag.track = $track.first;
    $tag.trackTotal = $track.second;
    def disc as Pair init splitPair(textOr($texts, "TPOS"));
    $tag.disc = $disc.first;
    $tag.discTotal = $disc.second;

    def stamp as string init textOr($texts, "TDRC");
    if ($stamp == "") {
        $stamp = textOr($texts, "TDRL");
    }
    if ($stamp != "") {
        $tag.date = $stamp;
        $tag.year = yearOf($stamp);
    } else {
        $tag.year = textOr($texts, "TYER");
        $tag.date = $tag.year;
    }
    return $tag;
}

/**
 * A pair of numbers written as `a/b`.
 *
 * @field first {int} the number before the slash, or `0`
 * @field second {int} the number after it, or `0`
 */
def struct Pair {
    first as int,
    second as int
};

/**
 * Split a `3/12` track or disc field.
 *
 * @param s {string} the field text
 * @return {Pair} the two numbers, each `0` when absent
 */
func splitPair(s as string) {
    if ($s == "") {
        return Pair{first: 0, second: 0};
    }
    def cut as int init strings.indexOf($s, "/");
    if ($cut < 0) {
        return Pair{first: leadingInt($s), second: 0};
    }
    def head as string init strings.substring($s, 0, $cut);
    def tail as string init strings.substring($s, $cut + 1);
    return Pair{first: leadingInt($head), second: leadingInt($tail)};
}

/**
 * The four-digit year at the front of an ID3v2.4 timestamp.
 *
 * @param stamp {string} a timestamp like `2003-05-01T13:00`
 * @return {string} the year, or `""` when there is not one
 */
func yearOf(stamp as string) {
    if (len($stamp) < 4) {
        return "";
    }
    def head as string init strings.substring($stamp, 0, 4);
    if (leadingInt($head) == 0) {
        return "";
    }
    return $head;
}

/**
 * A text frame's value, or `""`.
 *
 * @param texts {map of string to string} the frames collected by identifier
 * @param id {string} the canonical frame identifier
 * @return {string} the value, or `""` when the frame was absent
 */
func textOr(texts as map of string to string, id as string) {
    if (maps.has($texts, $id)) {
        return $texts[$id];
    }
    return "";
}

/**
 * Read a `COMM` or `USLT` frame.
 *
 * Both have the same shape: an encoding byte, a three-character language
 * code, a description, then the text.
 *
 * @param f {Id3v2Frame} the frame to read
 * @return {Comment} the comment; an unreadable frame gives an empty one
 */
func commentOf(f as Id3v2Frame) {
    def out as Comment init Comment{language: "", description: "", text: ""};
    if (len($f.data) < 4) {
        return $out;
    }
    def enc as int init textEncodingOf($f.data[0]);
    $out.language = decodeLatin1(binary.slice($f.data, 1, 4));
    def body as bytes init binary.slice($f.data, 4, len($f.data));
    def description as TextField init readTerminated($body, 0, $enc);
    $out.description = $description.text;
    def text as TextField init readTerminated($body, $description.next, $enc);
    $out.text = $text.text;
    return $out;
}

/**
 * Read an `APIC` frame, or the `PIC` frame ID3v2.2 called it.
 *
 * ID3v2.2 stores a three-character image format instead of a media type;
 * `JPG` and `PNG` map to `image/jpeg` and `image/png`, anything else to
 * `image/` plus the format in lower case.
 *
 * @param f {Id3v2Frame} the frame to read
 * @param major {int} the ID3v2 major version the frame came from
 * @return {Picture} the picture; an unreadable frame gives an empty one
 */
func pictureOf(f as Id3v2Frame, major as int) {
    def out as Picture init Picture{mimeType: "", kind: 0, description: "", data: binary.make(0)};
    if (len($f.data) < 2) {
        return $out;
    }
    def enc as int init textEncodingOf($f.data[0]);
    def at as int init 1;
    if ($major == 2) {
        if (len($f.data) < 6) {
            return $out;
        }
        $out.mimeType = mediaTypeOf(decodeLatin1(binary.slice($f.data, 1, 4)));
        $at = 4;
    } else {
        def mime as TextField init readTerminated($f.data, 1, TEXT_LATIN1);
        $out.mimeType = $mime.text;
        $at = $mime.next;
    }
    if ($at >= len($f.data)) {
        return $out;
    }
    $out.kind = $f.data[$at];
    def body as bytes init binary.slice($f.data, $at + 1, len($f.data));
    def description as TextField init readTerminated($body, 0, $enc);
    $out.description = $description.text;
    $out.data = binary.slice($body, $description.next, len($body));
    return $out;
}

/**
 * The media type an ID3v2.2 three-character image format names.
 *
 * @param format {string} the format as stored, `"JPG"` or `"PNG"` in practice
 * @return {string} the media type
 */
func mediaTypeOf(format as string) {
    def upper as string init strings.upper(strings.trim($format));
    if ($upper == "JPG" or $upper == "JPEG") {
        return "image/jpeg";
    }
    if ($upper == "PNG") {
        return "image/png";
    }
    if ($upper == "") {
        return "";
    }
    return "image/" + strings.lower($upper);
}

/**
 * The three-character image format ID3v2.2 writes for a media type.
 *
 * @param mimeType {string} the media type
 * @return {string} three characters, `"JPG"` when nothing else fits
 */
func imageFormatOf(mimeType as string) {
    def lower as string init strings.lower(strings.trim($mimeType));
    if ($lower == "image/png") {
        return "PNG";
    }
    if ($lower == "image/gif") {
        return "GIF";
    }
    return "JPG";
}

/**
 * What an `APIC` picture type means.
 *
 * @param kind {int} the picture type
 * @return {string} the name, or `""` outside 0-20
 * @example
 *   mp3.pictureTypeName(3);   # "Cover (front)"
 */
export func pictureTypeName(kind as int) {
    if ($kind < 0 or $kind >= len(PICTURE_TYPES)) {
        return "";
    }
    return PICTURE_TYPES[$kind];
}

/**
 * The picture a player would show.
 *
 * The front cover if the tag has one, otherwise the first picture.
 *
 * @param tag {Tag} the tag to look in
 * @return {Picture} the cover, or an empty picture when there is none
 * @example
 *   def cover as mp3.Picture init mp3.coverArt($tag);
 *   if (len($cover.data) > 0) { fs.writeBytes("cover.jpg", $cover.data); }
 */
export func coverArt(tag as Tag) {
    for (def p in $tag.pictures) {
        if ($p.kind == PICTURE_FRONT_COVER) {
            return $p;
        }
    }
    if (len($tag.pictures) > 0) {
        return $tag.pictures[0];
    }
    return Picture{mimeType: "", kind: 0, description: "", data: binary.make(0)};
}

/**
 * The comment a player would show.
 *
 * The first comment with an empty description, else the first comment.
 *
 * @param tag {Tag} the tag to look in
 * @return {string} the comment text, or `""` when there are none
 */
export func commentText(tag as Tag) {
    for (def c in $tag.comments) {
        if ($c.description == "") {
            return $c.text;
        }
    }
    if (len($tag.comments) > 0) {
        return $tag.comments[0].text;
    }
    return "";
}

/**
 * Read an ID3v1 tag into the version-independent view.
 *
 * @param v1 {Id3v1} the tag to read
 * @return {Tag} the unified view; an absent tag gives an empty one
 */
export func tagFromId3v1(v1 as Id3v1) {
    def tag as Tag;
    if (not $v1.present) {
        return $tag;
    }
    $tag.title = $v1.title;
    $tag.artist = $v1.artist;
    $tag.album = $v1.album;
    $tag.year = $v1.year;
    $tag.date = $v1.year;
    $tag.track = $v1.track;
    $tag.genre = genreName($v1.genre);
    if ($v1.comment != "") {
        def comments as list of Comment init [];
        $comments[] = Comment{language: "eng", description: "", text: $v1.comment};
        $tag.comments = $comments;
    }
    return $tag;
}

/**
 * Fill the gaps in one tag from another.
 *
 * Each text field that is `""` and each number that is `0` in `primary` is
 * taken from `fallback`. `comments` and `pictures` are taken whole when
 * `primary` has none. `extra` is not merged. {@link parse} uses this to back
 * the ID3v2 tag with the ID3v1 tag.
 *
 * @param primary {Tag} the tag that wins
 * @param fallback {Tag} the tag that fills its gaps
 * @return {Tag} a fresh tag; neither argument is changed
 */
export func mergeTags(primary as Tag, fallback as Tag) {
    def out as Tag init $primary;
    $out.title = firstSet($out.title, $fallback.title);
    $out.artist = firstSet($out.artist, $fallback.artist);
    $out.album = firstSet($out.album, $fallback.album);
    $out.albumArtist = firstSet($out.albumArtist, $fallback.albumArtist);
    $out.composer = firstSet($out.composer, $fallback.composer);
    $out.genre = firstSet($out.genre, $fallback.genre);
    $out.year = firstSet($out.year, $fallback.year);
    $out.date = firstSet($out.date, $fallback.date);
    $out.publisher = firstSet($out.publisher, $fallback.publisher);
    $out.encodedBy = firstSet($out.encodedBy, $fallback.encodedBy);
    $out.copyright = firstSet($out.copyright, $fallback.copyright);
    $out.lyrics = firstSet($out.lyrics, $fallback.lyrics);
    if ($out.track == 0) {
        $out.track = $fallback.track;
    }
    if ($out.trackTotal == 0) {
        $out.trackTotal = $fallback.trackTotal;
    }
    if ($out.disc == 0) {
        $out.disc = $fallback.disc;
    }
    if ($out.discTotal == 0) {
        $out.discTotal = $fallback.discTotal;
    }
    if ($out.bpm == 0) {
        $out.bpm = $fallback.bpm;
    }
    if (len($out.comments) == 0) {
        $out.comments = $fallback.comments;
    }
    if (len($out.pictures) == 0) {
        $out.pictures = $fallback.pictures;
    }
    return $out;
}

/**
 * The first of two strings that is not empty.
 *
 * @param preferred {string} the string that wins when it is set
 * @param fallback {string} the string to fall back to
 * @return {string} `preferred` when it is not empty, else `fallback`
 */
func firstSet(preferred as string, fallback as string) {
    if ($preferred != "") {
        return $preferred;
    }
    return $fallback;
}

/**
 * Render the version-independent view back to ID3v2 frames.
 *
 * Only set fields produce frames; comments with empty text and pictures with
 * no data are skipped. Text uses the narrowest encoding that holds it:
 * ISO-8859-1, else UTF-8 on ID3v2.4 and UTF-16 on earlier versions.
 *
 * The year goes to `TDRC` on ID3v2.4 (the full `date` when set) and `TYER`
 * on ID3v2.3 and 2.2.
 *
 * @param tag {Tag} the tag to render
 * @param major {int} the ID3v2 major version to write: 2, 3 or 4
 * @return {list of Id3v2Frame} the frames, ready for {@link renderId3v2}
 * @throws {Error} when `major` is not 2, 3 or 4
 * @example
 *   def frames as list of Id3v2Frame init mp3.framesFromTag($tag, 4);
 *   def raw as bytes init mp3.renderId3v2($frames, 4, 1024);
 */
export func framesFromTag(tag as Tag, major as int) {
    requireWritableMajor($major);
    # Collected as two parallel lists and appended in one pass. Threading the
    # growing frame list through a per-field helper would deep-copy it on
    # every call - the shape JENNIFER.md warns about - and a frame list holds
    # the artwork.
    def ids as list of string init textFrameIds($major);
    def values as list of string init textFrameValues($tag, $major);
    def frames as list of Id3v2Frame init [];
    for (def i as int init 0; $i < len($ids); $i = $i + 1) {
        if ($values[$i] != "") {
            $frames[] = textFrame($ids[$i], $values[$i], $major);
        }
    }

    for (def c in $tag.comments) {
        if ($c.text != "") {
            $frames[] = commentFrame("COMM", $c, $major);
        }
    }
    if ($tag.lyrics != "") {
        def lyric as Comment init Comment{language: "eng", description: "", text: $tag.lyrics};
        $frames[] = commentFrame("USLT", $lyric, $major);
    }
    for (def p in $tag.pictures) {
        if (len($p.data) > 0) {
            $frames[] = pictureFrame($p, $major);
        }
    }
    def keys as list of string init maps.keys($tag.extra);
    for (def k in $keys) {
        $frames[] = userTextFrame($k, $tag.extra[$k], $major);
    }
    return $frames;
}

/**
 * Which frame carries the year in this ID3v2 version.
 *
 * @param major {int} the ID3v2 major version
 * @return {string} `"TDRC"` on ID3v2.4, `"TYER"` before it
 */
func dateFrameId(major as int) {
    if ($major >= 4) {
        return "TDRC";
    }
    return "TYER";
}

/**
 * What to write into the date frame.
 *
 * ID3v2.4 takes a full timestamp, so the recorded date is written when there
 * is one. The older versions take a bare year.
 *
 * @param tag {Tag} the tag being written
 * @param major {int} the ID3v2 major version
 * @return {string} the text for the date frame, possibly empty
 */
func dateText(tag as Tag, major as int) {
    if ($major >= 4 and $tag.date != "") {
        return $tag.date;
    }
    return $tag.year;
}

/**
 * The text frames {@link framesFromTag} writes, in order.
 *
 * Paired position for position with {@link textFrameValues}.
 *
 * @param major {int} the ID3v2 major version
 * @return {list of string} canonical frame identifiers
 */
func textFrameIds(major as int) {
    def ids as list of string init [
        "TIT2",
        "TPE1",
        "TALB",
        "TPE2",
        "TCOM",
        "TCON",
        "TRCK",
        "TPOS",
        "TPUB",
        "TENC",
        "TCOP",
        "TBPM"
    ];
    $ids[] = dateFrameId($major);
    return $ids;
}

/**
 * What goes in each of those frames, in the same order.
 *
 * An empty string means the frame is not written.
 *
 * @param tag {Tag} the tag being written
 * @param major {int} the ID3v2 major version
 * @return {list of string} one value per identifier
 */
func textFrameValues(tag as Tag, major as int) {
    def values as list of string init [
        $tag.title,
        $tag.artist,
        $tag.album,
        $tag.albumArtist,
        $tag.composer,
        $tag.genre,
        pairText($tag.track, $tag.trackTotal),
        pairText($tag.disc, $tag.discTotal),
        $tag.publisher,
        $tag.encodedBy,
        $tag.copyright,
        numberText($tag.bpm)
    ];
    $values[] = dateText($tag, $major);
    return $values;
}

/**
 * Build a text frame.
 *
 * Uses the narrowest encoding that holds `value` in this version and removes
 * NULs from it. The identifier is mapped for ID3v2.2:
 * `textFrame("TIT2", t, 2)` builds a `TT2` frame.
 *
 * @param id {string} the canonical frame identifier
 * @param value {string} the text to write
 * @param major {int} the ID3v2 major version
 * @return {Id3v2Frame} the frame
 * @throws {Error} when `major` is not 2, 3 or 4, or when ID3v2.2 has no name
 *     for the frame
 * @example
 *   def f as Id3v2Frame init mp3.textFrame("TIT2", "Ich war müde leer nicht mehr da", 4);
 */
export func textFrame(id as string, value as string, major as int) {
    requireWritableMajor($major);
    def text as string init withoutNuls($value);
    def enc as int init pickEncoding($text, $major);
    def parts as list of bytes init [];
    $parts[] = binary.make(1, $enc);
    $parts[] = encodeText($text, $enc);
    return Id3v2Frame{id: versionFrameId($id, $major), flags: 0, data: binary.join($parts)};
}

/**
 * Build a `TXXX` user-defined text frame.
 *
 * @param description {string} what the value is
 * @param value {string} the value
 * @param major {int} the ID3v2 major version
 * @return {Id3v2Frame} the frame
 */
func userTextFrame(description as string, value as string, major as int) {
    def label as string init withoutNuls($description);
    def pair as list of string init [];
    $pair[] = $label;
    $pair[] = $value;
    def enc as int init pickEncodingAll($pair, $major);
    def parts as list of bytes init [];
    $parts[] = binary.make(1, $enc);
    $parts[] = encodeText($label, $enc);
    $parts[] = terminatorBytes($enc);
    $parts[] = encodeText($value, $enc);
    return Id3v2Frame{id: versionFrameId("TXXX", $major), flags: 0, data: binary.join($parts)};
}

/**
 * Build a `COMM` or `USLT` frame.
 *
 * @param id {string} `"COMM"` or `"USLT"`
 * @param c {Comment} the comment to write
 * @param major {int} the ID3v2 major version
 * @return {Id3v2Frame} the frame
 */
func commentFrame(id as string, c as Comment, major as int) {
    def label as string init withoutNuls($c.description);
    def texts as list of string init [];
    $texts[] = $label;
    $texts[] = $c.text;
    def enc as int init pickEncodingAll($texts, $major);
    def parts as list of bytes init [];
    $parts[] = binary.make(1, $enc);
    $parts[] = latin1Bytes(languageCode($c.language));
    $parts[] = encodeText($label, $enc);
    $parts[] = terminatorBytes($enc);
    $parts[] = encodeText($c.text, $enc);
    return Id3v2Frame{id: versionFrameId($id, $major), flags: 0, data: binary.join($parts)};
}

/**
 * Build an `APIC` frame, or the `PIC` frame ID3v2.2 called it.
 *
 * @param p {Picture} the picture to write
 * @param major {int} the ID3v2 major version
 * @return {Id3v2Frame} the frame
 */
func pictureFrame(p as Picture, major as int) {
    def label as string init withoutNuls($p.description);
    def enc as int init pickEncoding($label, $major);
    def parts as list of bytes init [];
    $parts[] = binary.make(1, $enc);
    if ($major == 2) {
        $parts[] = latin1Bytes(imageFormatOf($p.mimeType));
    } else {
        $parts[] = latin1Bytes(mediaTypeOrDefault($p.mimeType));
        $parts[] = binary.make(1, 0);
    }
    $parts[] = binary.make(1, pictureKind($p.kind));
    $parts[] = encodeText($label, $enc);
    $parts[] = terminatorBytes($enc);
    $parts[] = $p.data;
    return Id3v2Frame{id: versionFrameId("APIC", $major), flags: 0, data: binary.join($parts)};
}

/**
 * The media type to write for a picture.
 *
 * The field is ISO-8859-1 and ends at a NUL, so a type that is not printable
 * ASCII would fail the write or end the field early; it is written as the
 * default instead.
 *
 * @param mimeType {string} the picture's media type
 * @return {string} the type, or `"image/jpeg"` when it is not set or not
 *     printable ASCII
 */
func mediaTypeOrDefault(mimeType as string) {
    def trimmed as string init strings.trim($mimeType);
    if ($trimmed == "" or not isPrintableAscii($trimmed)) {
        return "image/jpeg";
    }
    return $trimmed;
}

/**
 * The picture type byte to write.
 *
 * @param kind {int} the picture type
 * @return {int} the type when it is one of the defined ones, else `0`
 */
func pictureKind(kind as int) {
    if ($kind < 0 or $kind >= len(PICTURE_TYPES)) {
        return 0;
    }
    return $kind;
}

/**
 * A three-character ISO-639-2 language code.
 *
 * @param language {string} the code as given
 * @return {string} three lower-case ISO-8859-1 characters; `"eng"` when unusable
 */
func languageCode(language as string) {
    def code as string init strings.lower(strings.trim($language));
    if (len($code) != 3 or not isLatin1($code)) {
        return "eng";
    }
    return $code;
}

/**
 * The string terminator for an encoding.
 *
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {bytes} one NUL, or two for the UTF-16 encodings
 */
func terminatorBytes(enc as int) {
    return binary.make(terminatorSize($enc), 0);
}

/**
 * A number and its total as `3/12`, `3`, or nothing.
 *
 * @param number {int} the track or disc number
 * @param total {int} how many there are, or `0`
 * @return {string} the field text, or `""` when `number` is not set
 */
func pairText(number as int, total as int) {
    if ($number <= 0) {
        return "";
    }
    if ($total <= 0) {
        return convert.toString($number);
    }
    return convert.toString($number) + "/" + convert.toString($total);
}

/**
 * A number as text, or nothing when it is not set.
 *
 * @param number {int} the value
 * @return {string} the number, or `""` when it is zero or negative
 */
func numberText(number as int) {
    if ($number <= 0) {
        return "";
    }
    return convert.toString($number);
}

/**
 * Render the version-independent view back to an ID3v1 tag.
 *
 * Keeps title, artist, album, year, {@link commentText}, a track number in
 * 1-255 and the genre number; everything else is dropped. A genre the table
 * does not know becomes `GENRE_NONE`. Truncation to field widths happens in
 * {@link renderId3v1}.
 *
 * @param tag {Tag} the tag to render
 * @return {Id3v1} the tag, with `present` set
 * @example
 *   def block as bytes init mp3.renderId3v1(mp3.id3v1FromTag($tag));
 */
export func id3v1FromTag(tag as Tag) {
    def out as Id3v1;
    $out.present = true;
    $out.title = $tag.title;
    $out.artist = $tag.artist;
    $out.album = $tag.album;
    $out.year = $tag.year;
    $out.comment = commentText($tag);
    $out.track = 0;
    if ($tag.track > 0 and $tag.track < 256) {
        $out.track = $tag.track;
        $out.version11 = true;
    }
    def number as int init genreNumber($tag.genre);
    if ($number < 0) {
        $out.genre = GENRE_NONE;
    } else {
        $out.genre = $number;
    }
    return $out;
}
