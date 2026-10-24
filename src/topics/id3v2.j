# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the ID3v2 container: header, frames, unsynchronisation.
# Spliced into mp3.j via include - not a standalone module.

/** How long an ID3v2 header is, and an ID3v2.4 footer with it. */
export def const ID3V2_HEADER_SIZE as int init 10;

/** Tag header flag: the tag body is unsynchronised. */
def const TAG_FLAG_UNSYNC as int init 0x80;

/** Tag header flag: an extended header follows the header. ID3v2.3 and up. */
def const TAG_FLAG_EXTENDED as int init 0x40;

/** Tag header flag: a footer closes the tag. ID3v2.4 only. */
def const TAG_FLAG_FOOTER as int init 0x10;

/** ID3v2.3 frame format flag: the frame body is zlib-compressed. */
def const V3_FRAME_COMPRESSED as int init 0x80;

/** ID3v2.3 frame format flag: the frame body is encrypted. */
def const V3_FRAME_ENCRYPTED as int init 0x40;

/** ID3v2.3 frame format flag: the frame belongs to a group. */
def const V3_FRAME_GROUPED as int init 0x20;

/** ID3v2.4 frame format flag: the frame belongs to a group. */
def const V4_FRAME_GROUPED as int init 0x40;

/** ID3v2.4 frame format flag: the frame body is zlib-compressed. */
def const V4_FRAME_COMPRESSED as int init 0x08;

/** ID3v2.4 frame format flag: the frame body is encrypted. */
def const V4_FRAME_ENCRYPTED as int init 0x04;

/** ID3v2.4 frame format flag: the frame body is unsynchronised on its own. */
def const V4_FRAME_UNSYNC as int init 0x02;

/** ID3v2.4 frame format flag: a data length indicator opens the frame body. */
def const V4_FRAME_LENGTH as int init 0x01;

/**
 * The largest frame this deck will decompress.
 *
 * A compressed frame states its decompressed length, and a hostile file can
 * state one that would exhaust memory, or none. 16 MiB is far past any real
 * frame (the largest are cover art), so a frame claiming more, or nothing, is
 * kept compressed.
 */
def const MAX_DECOMPRESSED as int init 16777216;

/**
 * One ID3v2 frame, as stored.
 *
 * The body is kept raw: already de-unsynchronised and decompressed, but not
 * interpreted. {@link frameText} and the readers in the tag layer turn it
 * into values.
 *
 * @field id {string} the frame identifier - three characters on ID3v2.2,
 *     four on ID3v2.3 and ID3v2.4
 * @field flags {int} the two frame flag bytes, status high and format low;
 *     `0` on ID3v2.2, which has none
 * @field data {bytes} the frame body
 */
export def struct Id3v2Frame {
    id as string,
    flags as int,
    data as bytes
};

/**
 * An ID3v2 tag.
 *
 * @field present {bool} whether the file opened with an ID3v2 tag
 * @field major {int} the ID3v2 major version: 2, 3 or 4
 * @field minor {int} the revision number, almost always 0
 * @field flags {int} the header flag byte
 * @field size {int} how many bytes the whole tag occupies in the file,
 *     header and footer included
 * @field frames {list of Id3v2Frame} every frame, in the order stored
 */
export def struct Id3v2 {
    present as bool,
    major as int,
    minor as int,
    flags as int,
    size as int,
    frames as list of Id3v2Frame
};

/**
 * One frame body, with the per-frame extras taken off the front.
 *
 * @field data {bytes} the body proper
 * @field compressed {bool} whether the body is still zlib-compressed
 * @field encrypted {bool} whether the body is encrypted, so unreadable here
 */
def struct FramePayload {
    data as bytes,
    compressed as bool,
    encrypted as bool
};

/**
 * How many bytes of ID3v2 tag a file opens with.
 *
 * Reads only the ten-byte header. The result is clamped to `len(data)`.
 *
 * @param data {bytes} the whole file
 * @return {int} the tag size including header and footer, or `0` when the
 *     file does not open with an ID3v2 tag
 */
export func id3v2Size(data as bytes) {
    if (not magicAt($data, 0, "ID3") or len($data) < ID3V2_HEADER_SIZE) {
        return 0;
    }
    if ($data[3] == 0xff or $data[4] == 0xff) {
        return 0;
    }
    def body as int init syncsafe32($data, 6);
    def total as int init ID3V2_HEADER_SIZE + $body;
    if (($data[5] & TAG_FLAG_FOOTER) != 0) {
        $total = $total + ID3V2_HEADER_SIZE;
    }
    if ($total > len($data)) {
        return len($data);
    }
    return $total;
}

/**
 * Read the ID3v2 tag a file opens with.
 *
 * Reads ID3v2.2, 2.3 and 2.4. Frame identifiers come back as stored
 * (three characters on ID3v2.2). Unsynchronisation is undone, compressed
 * frames are expanded, and encrypted frames are dropped. A frame that runs
 * past the end of the tag, or an illegal identifier, ends the frame list
 * without an error, so a damaged tag yields the frames before the damage.
 * A major version outside 2-4 or a version byte of `ff` reads as absent.
 *
 * @param data {bytes} the whole file
 * @return {Id3v2} the tag, or an absent one with `present` false
 * @example
 *   def id3 as mp3.Id3v2 init mp3.readId3v2($data);
 *   io.printf("ID3v2.%d, %d frames\n", $id3.major, len($id3.frames));
 */
export func readId3v2(data as bytes) {
    def tag as Id3v2;
    if (not magicAt($data, 0, "ID3") or len($data) < ID3V2_HEADER_SIZE) {
        return $tag;
    }
    def major as int init $data[3];
    def minor as int init $data[4];
    if ($major == 0xff or $minor == 0xff or $major < 2 or $major > 4) {
        return $tag;
    }
    $tag.present = true;
    $tag.major = $major;
    $tag.minor = $minor;
    $tag.flags = $data[5];
    $tag.size = id3v2Size($data);

    def declared as int init syncsafe32($data, 6);
    def bodyEnd as int init ID3V2_HEADER_SIZE + $declared;
    if ($bodyEnd > len($data)) {
        $bodyEnd = len($data);
    }
    def body as bytes init binary.slice($data, ID3V2_HEADER_SIZE, $bodyEnd);
    def unsync as bool init ($tag.flags & TAG_FLAG_UNSYNC) != 0;
    if ($unsync and $major < 4) {
        $body = deunsynchronise($body);
    }
    def start as int init extendedHeaderSize($body, $major, $tag.flags);
    $tag.frames = readFrames($body, $start, $major, $unsync);
    return $tag;
}

/**
 * How many bytes of extended header sit in front of the first frame.
 *
 * ID3v2.3 states a size that excludes its own four-byte length field;
 * ID3v2.4 states one that includes it. ID3v2.2 has no extended header - the
 * bit means whole-tag compression there, which no encoder ever wrote.
 *
 * @param body {bytes} the tag body, after the header
 * @param major {int} the ID3v2 major version
 * @param flags {int} the header flag byte
 * @return {int} where the first frame starts within `body`
 */
func extendedHeaderSize(body as bytes, major as int, flags as int) {
    if (($flags & TAG_FLAG_EXTENDED) == 0 or $major < 3) {
        return 0;
    }
    if (len($body) < 4) {
        return len($body);
    }
    def size as int init 0;
    if ($major == 3) {
        $size = beUint32($body, 0) + 4;
    } else {
        $size = syncsafe32($body, 0);
    }
    if ($size < 0 or $size > len($body)) {
        return len($body);
    }
    return $size;
}

/**
 * Read every frame out of a tag body.
 *
 * @param body {bytes} the tag body, after any extended header
 * @param start {int} where the first frame starts
 * @param major {int} the ID3v2 major version
 * @param unsync {bool} whether the header asked for unsynchronisation
 * @return {list of Id3v2Frame} the frames, in the order stored
 */
func readFrames(body as bytes, start as int, major as int, unsync as bool) {
    def frames as list of Id3v2Frame init [];
    def idLength as int init frameIdLength($major);
    def headerLength as int init frameHeaderLength($major);
    def size as int init len($body);
    def at as int init $start;

    while ($at + $headerLength <= $size) {
        if ($body[$at] == 0) {
            break;
        }
        def id as string init decodeLatin1(binary.slice($body, $at, $at + $idLength));
        if (not isFrameId($id)) {
            break;
        }
        def bodyLength as int init frameBodyLength($body, $at, $major, $headerLength);
        if ($bodyLength < 0) {
            break;
        }
        def from as int init $at + $headerLength;
        if ($from + $bodyLength > $size) {
            break;
        }
        def flags as int init frameFlags($body, $at, $major, $idLength);
        def raw as bytes init binary.slice($body, $from, $from + $bodyLength);
        if ($major == 4 and ($unsync or ($flags & V4_FRAME_UNSYNC) != 0)) {
            $raw = deunsynchronise($raw);
        }
        def payload as FramePayload init stripFrameExtras($raw, $major, $flags);
        if (not $payload.encrypted) {
            $frames[] = Id3v2Frame{id: $id, flags: $flags, data: $payload.data};
        }
        $at = $from + $bodyLength;
    }
    return $frames;
}

/**
 * How many characters a frame identifier has in this version.
 *
 * @param major {int} the ID3v2 major version
 * @return {int} 3 on ID3v2.2, 4 on ID3v2.3 and ID3v2.4
 */
func frameIdLength(major as int) {
    if ($major == 2) {
        return 3;
    }
    return 4;
}

/**
 * How many bytes a frame header occupies in this version.
 *
 * @param major {int} the ID3v2 major version
 * @return {int} 6 on ID3v2.2, 10 on ID3v2.3 and ID3v2.4
 */
func frameHeaderLength(major as int) {
    if ($major == 2) {
        return 6;
    }
    return 10;
}

/**
 * The two frame flag bytes, as one integer.
 *
 * @param body {bytes} the tag body
 * @param at {int} where the frame header starts
 * @param major {int} the ID3v2 major version
 * @param idLength {int} how long the identifier is
 * @return {int} status byte shifted left eight, format byte below it; `0` on
 *     ID3v2.2, which has no frame flags
 */
func frameFlags(body as bytes, at as int, major as int, idLength as int) {
    if ($major == 2) {
        return 0;
    }
    return beUint16($body, $at + $idLength + 4);
}

/**
 * How long the frame at `at` says its body is.
 *
 * ID3v2.4 defines the field as synchsafe, but several widely used taggers
 * wrote a plain 32-bit integer there. When the two readings differ, the
 * synchsafe one wins if it ends on a frame boundary, else the plain one if
 * it does, else the synchsafe one.
 *
 * @param body {bytes} the tag body
 * @param at {int} where the frame header starts
 * @param major {int} the ID3v2 major version
 * @param headerLength {int} how long a frame header is in this version
 * @return {int} the body length in bytes, or `-1` when it is unusable
 */
func frameBodyLength(body as bytes, at as int, major as int, headerLength as int) {
    if ($major == 2) {
        return beUint24($body, $at + 3);
    }
    if ($major == 3) {
        def plain as int init beUint32($body, $at + 4);
        if ($plain < 0) {
            return -1;
        }
        return $plain;
    }
    def safe as int init syncsafe32($body, $at + 4);
    def raw as int init beUint32($body, $at + 4);
    if ($safe == $raw) {
        return $safe;
    }
    if (frameBoundaryAt($body, $at + $headerLength + $safe, $major)) {
        return $safe;
    }
    if (frameBoundaryAt($body, $at + $headerLength + $raw, $major)) {
        return $raw;
    }
    return $safe;
}

/**
 * Whether `at` is a plausible end for a frame.
 *
 * The end of the body, the start of the padding, or another legal frame
 * identifier all qualify.
 *
 * @param body {bytes} the tag body
 * @param at {int} the offset to test
 * @param major {int} the ID3v2 major version
 * @return {bool} true when a frame could end here
 */
func frameBoundaryAt(body as bytes, at as int, major as int) {
    def size as int init len($body);
    if ($at < 0 or $at > $size) {
        return false;
    }
    if ($at == $size) {
        return true;
    }
    if ($body[$at] == 0) {
        return true;
    }
    def idLength as int init frameIdLength($major);
    if ($at + $idLength > $size) {
        return false;
    }
    return isFrameId(decodeLatin1(binary.slice($body, $at, $at + $idLength)));
}

/**
 * Whether a string is a legal ID3v2 frame identifier.
 *
 * The spec allows upper-case letters and digits, and nothing else.
 *
 * @param id {string} the identifier read out of a frame header
 * @return {bool} true when every character is `A`-`Z` or `0`-`9`
 */
func isFrameId(id as string) {
    if ($id == "") {
        return false;
    }
    def chars as list of string init strings.chars($id);
    for (def ch in $chars) {
        def code as int init convert.toCodepoint($ch);
        def isUpper as bool init $code >= 0x41 and $code <= 0x5a;
        def isDigit as bool init $code >= 0x30 and $code <= 0x39;
        if (not $isUpper and not $isDigit) {
            return false;
        }
    }
    return true;
}

/**
 * Take the per-frame extra fields off the front of a frame body.
 *
 * A grouped frame opens with a group byte, an encrypted one with a method
 * byte, a compressed ID3v2.4 one with a four-byte decompressed length. What
 * is left is the frame body proper, which is expanded when it is compressed
 * and small enough to be worth expanding.
 *
 * @param raw {bytes} the frame body as stored
 * @param major {int} the ID3v2 major version
 * @param flags {int} the frame's two flag bytes
 * @return {FramePayload} the body, and what is still wrapped around it
 */
func stripFrameExtras(raw as bytes, major as int, flags as int) {
    def format as int init $flags & 0xff;
    if ($major == 2 or $format == 0) {
        return FramePayload{data: $raw, compressed: false, encrypted: false};
    }
    def compressed as bool init false;
    def encrypted as bool init false;
    def declared as int init 0;
    def at as int init 0;
    def size as int init len($raw);

    if ($major == 3) {
        if (($format & V3_FRAME_COMPRESSED) != 0) {
            $compressed = true;
            if ($at + 4 > $size) {
                return FramePayload{data: $raw, compressed: true, encrypted: false};
            }
            $declared = beUint32($raw, $at);
            $at = $at + 4;
        }
        if (($format & V3_FRAME_ENCRYPTED) != 0) {
            $encrypted = true;
            $at = $at + 1;
        }
        if (($format & V3_FRAME_GROUPED) != 0) {
            $at = $at + 1;
        }
    } else {
        if (($format & V4_FRAME_GROUPED) != 0) {
            $at = $at + 1;
        }
        if (($format & V4_FRAME_ENCRYPTED) != 0) {
            $encrypted = true;
            $at = $at + 1;
        }
        if (($format & V4_FRAME_COMPRESSED) != 0) {
            $compressed = true;
        }
        if (($format & V4_FRAME_LENGTH) != 0) {
            if ($at + 4 > $size) {
                return FramePayload{data: $raw, compressed: $compressed, encrypted: $encrypted};
            }
            $declared = syncsafe32($raw, $at);
            $at = $at + 4;
        }
    }
    if ($at > $size) {
        $at = $size;
    }
    def body as bytes init binary.slice($raw, $at, $size);
    if ($encrypted or not $compressed) {
        return FramePayload{data: $body, compressed: $compressed, encrypted: $encrypted};
    }
    return FramePayload{data: inflateFrame($body, $declared), compressed: false, encrypted: false};
}

/**
 * Expand a zlib-compressed frame body.
 *
 * The frame has to state how long it expands to, and that length has to be
 * within {@link MAX_DECOMPRESSED}, before anything is expanded at all. A
 * compressed frame that states nothing is malformed - ID3v2.3 puts the
 * decompressed size in front of the body and ID3v2.4 requires the data
 * length indicator alongside compression - and expanding one anyway would
 * let a crafted kilobyte decide how many gigabytes to allocate. The check
 * is repeated on the result, because the stated length is the file's claim
 * and not a fact.
 *
 * A body that fails any of that comes back untouched rather than throwing:
 * an unreadable frame is not worth refusing the whole tag over.
 *
 * @param body {bytes} the compressed body
 * @param declared {int} the decompressed length the frame states, or `0`
 * @return {bytes} the expanded body, or `body` when it could not be expanded
 */
func inflateFrame(body as bytes, declared as int) {
    if ($declared <= 0 or $declared > MAX_DECOMPRESSED) {
        return $body;
    }
    try {
        def out as bytes init compress.unpack($body, "zlib");
        if (len($out) > MAX_DECOMPRESSED) {
            return $body;
        }
        return $out;
    } catch (e) {
        return $body;
    }
}

/**
 * Undo unsynchronisation: every `ff 00` pair becomes a single `ff`.
 *
 * One `binary.indexOf` per pair, so a buffer with none is returned without
 * a copy.
 *
 * @param data {bytes} the unsynchronised bytes
 * @return {bytes} the original bytes
 */
func deunsynchronise(data as bytes) {
    def needle as bytes;
    $needle[] = 0xff;
    $needle[] = 0x00;
    def size as int init len($data);
    if (binary.indexOf($data, $needle) < 0) {
        return $data;
    }
    def parts as list of bytes init [];
    def at as int init 0;
    while ($at < $size) {
        def hit as int init binary.indexOf($data, $needle, $at);
        if ($hit < 0) {
            $parts[] = binary.slice($data, $at, $size);
            break;
        }
        $parts[] = binary.slice($data, $at, $hit + 1);
        $at = $hit + 2;
    }
    return binary.join($parts);
}

/**
 * Apply unsynchronisation: insert a `00` after every `ff` that could be read
 * as the start of an MPEG sync word, and after a trailing `ff`.
 *
 * The deck never writes an unsynchronised tag; this exists to test
 * {@link deunsynchronise} against.
 *
 * @param data {bytes} the bytes to protect
 * @return {bytes} the unsynchronised bytes
 */
func unsynchronise(data as bytes) {
    def out as bytes;
    def size as int init len($data);
    for (def i as int init 0; $i < $size; $i = $i + 1) {
        def b as int init $data[$i];
        $out[] = $b;
        if ($b != 0xff) {
            continue;
        }
        if ($i + 1 >= $size) {
            $out[] = 0x00;
            continue;
        }
        def next as int init $data[$i + 1];
        if ($next == 0x00 or $next >= 0xe0) {
            $out[] = 0x00;
        }
    }
    return $out;
}

/**
 * Whether a tag carries a frame with this identifier.
 *
 * @param tag {Id3v2} the tag to look in
 * @param id {string} the frame identifier
 * @return {bool} true when at least one frame has that identifier
 */
export func hasFrame(tag as Id3v2, id as string) {
    for (def f in $tag.frames) {
        if ($f.id == $id) {
            return true;
        }
    }
    return false;
}

/**
 * The first frame with this identifier.
 *
 * @param tag {Id3v2} the tag to look in
 * @param id {string} the frame identifier
 * @return {Id3v2Frame} the frame, or one with an empty `id` when absent
 * @example
 *   def title as mp3.Id3v2Frame init mp3.frame($id3, "TIT2");
 *   io.printf("%s\n", mp3.frameText($title));
 */
export func frame(tag as Id3v2, id as string) {
    for (def f in $tag.frames) {
        if ($f.id == $id) {
            return $f;
        }
    }
    def missing as Id3v2Frame;
    return $missing;
}

/**
 * Every frame with this identifier, in the order stored.
 *
 * ID3v2 allows repeats for comments, pictures, user-defined text and URLs.
 *
 * @param tag {Id3v2} the tag to look in
 * @param id {string} the frame identifier
 * @return {list of Id3v2Frame} the matching frames, possibly none
 */
export func framesWithId(tag as Id3v2, id as string) {
    def found as list of Id3v2Frame init [];
    for (def f in $tag.frames) {
        if ($f.id == $id) {
            $found[] = $f;
        }
    }
    return $found;
}

/**
 * The text a frame carries.
 *
 * The first of {@link frameValues} for a text frame (`T...`), the URL of a
 * URL frame (`W...`, ISO-8859-1, no encoding byte), `""` for anything else.
 * For `TXXX` / `TXX` it is the value after the description. `WXXX` / `WXX`
 * currently come back `""`.
 *
 * @param f {Id3v2Frame} the frame to read
 * @return {string} the text, or `""` when the frame carries none
 * @example
 *   mp3.frameText(mp3.frame($id3, "TPE1"));   # "Maike Vandervaart"
 */
export func frameText(f as Id3v2Frame) {
    def values as list of string init frameValues($f);
    if (len($values) == 0) {
        return "";
    }
    return $values[0];
}

/**
 * Every value a text frame carries.
 *
 * ID3v2.4 lets one text frame hold several values, separated by a NUL in the
 * frame's encoding; earlier versions hold one. For `TXXX` the description is
 * skipped; read it with {@link frameDescription}. An encoding byte outside
 * 0-3 is read as ISO-8859-1.
 *
 * @param f {Id3v2Frame} the frame to read
 * @return {list of string} the values, in order, with the empties removed
 */
export func frameValues(f as Id3v2Frame) {
    if ($f.id == "") {
        return [];
    }
    if (isUrlFrame($f.id)) {
        return urlFrameValues($f);
    }
    if (not strings.startsWith($f.id, "T")) {
        return [];
    }
    if (len($f.data) < 1) {
        return [];
    }
    def enc as int init textEncodingOf($f.data[0]);
    def body as bytes init binary.slice($f.data, 1, len($f.data));
    if (isUserFrame($f.id)) {
        def description as TextField init readTerminated($body, 0, $enc);
        def rest as bytes init binary.slice($body, $description.next, len($body));
        return splitValues($rest, $enc);
    }
    return splitValues($body, $enc);
}

/**
 * The description of a user-defined frame.
 *
 * `TXXX` and `WXXX` (`TXX` and `WXX` on ID3v2.2) carry a description before
 * their value. The descriptions of `COMM` and `APIC` are on the `Comment` and
 * `Picture` values {@link tagFromId3v2} builds.
 *
 * @param f {Id3v2Frame} the frame to read
 * @return {string} the description, or `""` when the frame has none
 */
export func frameDescription(f as Id3v2Frame) {
    if (len($f.data) < 1 or not isUserFrame($f.id)) {
        return "";
    }
    def body as bytes init binary.slice($f.data, 1, len($f.data));
    def field as TextField init readTerminated($body, 0, textEncodingOf($f.data[0]));
    return $field.text;
}

/**
 * Whether an identifier names a URL frame with no encoding byte.
 *
 * @param id {string} the frame identifier
 * @return {bool} true for `W...` other than the user-defined `WXXX` / `WXX`
 */
func isUrlFrame(id as string) {
    if (not strings.startsWith($id, "W")) {
        return false;
    }
    return $id != "WXXX" and $id != "WXX";
}

/**
 * Whether an identifier names a frame that opens with a description.
 *
 * @param id {string} the frame identifier
 * @return {bool} true for the user-defined text and URL frames
 */
func isUserFrame(id as string) {
    return $id == "TXXX" or $id == "TXX" or $id == "WXXX" or $id == "WXX";
}

/**
 * The URL a plain URL frame carries.
 *
 * @param f {Id3v2Frame} the frame to read
 * @return {list of string} one URL, or none when the frame is empty
 */
func urlFrameValues(f as Id3v2Frame) {
    if (len($f.data) == 0) {
        return [];
    }
    def field as TextField init readTerminated($f.data, 0, TEXT_LATIN1);
    if ($field.text == "") {
        return [];
    }
    def one as list of string init [];
    $one[] = $field.text;
    return $one;
}

/**
 * Render frames to a complete ID3v2 tag.
 *
 * Writes a plain tag: no unsynchronisation, extended header, footer or
 * compression, and every frame's flags as zero. `padding` NUL bytes follow
 * the frames, so a later edit can grow the tag in place.
 *
 * @param frames {list of Id3v2Frame} the frames to write, in order
 * @param major {int} the ID3v2 major version to write: 2, 3 or 4
 * @param padding {int} how many NUL bytes to leave after the frames
 * @return {bytes} the whole tag, header included
 * @throws {Error} when `major` is not 2, 3 or 4, when `padding` is negative,
 *     when a frame id is not legal for `major`, or when a frame or the tag is
 *     too long for its size field
 * @example
 *   def raw as bytes init mp3.renderId3v2($frames, 4, 1024);
 */
export func renderId3v2(frames as list of Id3v2Frame, major as int, padding as int) {
    requireWritableMajor($major);
    if ($padding < 0) {
        fail("padding cannot be negative");
    }
    def bodies as list of bytes init [];
    def total as int init 0;
    for (def f in $frames) {
        def piece as bytes init renderFrame($f, $major);
        $bodies[] = $piece;
        $total = $total + len($piece);
    }
    if ($padding > 0) {
        $bodies[] = binary.make($padding, 0);
        $total = $total + $padding;
    }
    if ($total > SYNCSAFE_MAX) {
        fail("an ID3v2 tag cannot hold " + convert.toString($total) + " bytes");
    }
    def parts as list of bytes init [];
    $parts[] = latin1Bytes("ID3");
    $parts[] = binary.make(1, $major);
    $parts[] = binary.make(1, 0);
    $parts[] = binary.make(1, 0);
    $parts[] = syncsafe32Bytes($total);
    $parts[] = binary.join($bodies);
    return binary.join($parts);
}

/**
 * Fail unless this deck can write the ID3v2 major version.
 *
 * Every exported writer that takes a `major` calls this first, so a version
 * outside 2-4 is refused where it enters rather than written in the layout
 * of whichever version a later branch happens to fall through to.
 *
 * @param major {int} the ID3v2 major version
 * @throws {Error} when `major` is not 2, 3 or 4
 */
func requireWritableMajor(major as int) {
    if ($major < 2 or $major > 4) {
        fail("cannot write ID3v2." + convert.toString($major));
    }
}

/**
 * Render one frame, header and body.
 *
 * @param f {Id3v2Frame} the frame to write; its flags are not carried over,
 *     because this writer never compresses, encrypts or groups
 * @param major {int} the ID3v2 major version to write
 * @return {bytes} the frame as stored
 * @throws {Error} when the identifier is the wrong length for the version or
 *     the body is too long for its size field
 */
func renderFrame(f as Id3v2Frame, major as int) {
    def idLength as int init frameIdLength($major);
    if (len($f.id) != $idLength or not isFrameId($f.id)) {
        fail("\"" + $f.id + "\" is not an ID3v2." + convert.toString($major) + " frame id");
    }
    def size as int init len($f.data);
    def parts as list of bytes init [];
    $parts[] = latin1Bytes($f.id);
    if ($major == 2) {
        if ($size > 0xffffff) {
            fail("frame " + $f.id + " is too long for ID3v2.2");
        }
        $parts[] = binary.make(1, ($size >> 16) & 0xff);
        $parts[] = binary.make(1, ($size >> 8) & 0xff);
        $parts[] = binary.make(1, $size & 0xff);
        $parts[] = $f.data;
        return binary.join($parts);
    }
    if ($major == 3) {
        $parts[] = beUint32Bytes($size);
    } else {
        if ($size > SYNCSAFE_MAX) {
            fail("frame " + $f.id + " is too long for ID3v2.4");
        }
        $parts[] = syncsafe32Bytes($size);
    }
    $parts[] = binary.make(2, 0);
    $parts[] = $f.data;
    return binary.join($parts);
}
