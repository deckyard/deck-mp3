# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the 128-byte ID3v1 tag in the last block of the file.
# Spliced into mp3.j via include - not a standalone module.

/** How long an ID3v1 tag is: `TAG` and 125 bytes of fixed-width fields. */
export def const ID3V1_SIZE as int init 128;

/** The byte a truncated ISO-8859-1 field is padded with. */
def const PAD_BYTE as int init 0;

/**
 * An ID3v1 or ID3v1.1 tag.
 *
 * Fixed-width ISO-8859-1 fields padded with NULs: 30 bytes each for title,
 * artist, album and comment, 4 for the year, 1 for the genre. ID3v1.1 uses
 * the last two comment bytes for a track number.
 *
 * @field present {bool} whether the file carried a tag at all
 * @field title {string} up to 30 characters
 * @field artist {string} up to 30 characters
 * @field album {string} up to 30 characters
 * @field year {string} four characters, conventionally `YYYY`
 * @field comment {string} up to 30 characters, or 28 on ID3v1.1
 * @field track {int} the ID3v1.1 track number, or `0`
 * @field genre {int} the genre byte as stored, `GENRE_NONE` when absent
 * @field version11 {bool} whether the tag uses the ID3v1.1 track field
 */
export def struct Id3v1 {
    present as bool,
    title as string,
    artist as string,
    album as string,
    year as string,
    comment as string,
    track as int,
    genre as int,
    version11 as bool
};

/**
 * Where the ID3v1 tag starts, if the file has one.
 *
 * @param data {bytes} the whole file
 * @return {int} the offset of the `TAG` identifier, or `-1` when absent
 */
func id3v1Offset(data as bytes) {
    def at as int init len($data) - ID3V1_SIZE;
    if ($at < 0 or not magicAt($data, $at, "TAG")) {
        return -1;
    }
    return $at;
}

/**
 * Read the ID3v1 tag from the end of a file.
 *
 * Without a tag, returns `present` false, empty fields and `genre`
 * `GENRE_NONE`. Fields are read up to the first NUL and trimmed.
 *
 * @param data {bytes} the whole file
 * @return {Id3v1} the tag, or an absent one
 * @example
 *   def v1 as mp3.Id3v1 init mp3.readId3v1($data);
 *   if ($v1.present) {
 *       io.printf("%s / %s\n", $v1.artist, mp3.genreName($v1.genre));
 *   }
 */
export func readId3v1(data as bytes) {
    def tag as Id3v1 init emptyId3v1();
    def at as int init id3v1Offset($data);
    if ($at < 0) {
        return $tag;
    }
    $tag.present = true;
    $tag.title = fixedField($data, $at + 3, 30);
    $tag.artist = fixedField($data, $at + 33, 30);
    $tag.album = fixedField($data, $at + 63, 30);
    $tag.year = fixedField($data, $at + 93, 4);
    $tag.genre = $data[$at + 127];

    # ID3v1.1 took the last two comment bytes for a track number: a NUL in the
    # second-to-last and anything but a NUL in the last one is the marker.
    def separator as int init $data[$at + 125];
    def trackByte as int init $data[$at + 126];
    if ($separator == 0 and $trackByte != 0) {
        $tag.version11 = true;
        $tag.track = $trackByte;
        $tag.comment = fixedField($data, $at + 97, 28);
    } else {
        $tag.comment = fixedField($data, $at + 97, 30);
    }
    return $tag;
}

/**
 * An ID3v1 tag with nothing in it.
 *
 * @return {Id3v1} every string empty, `genre` `GENRE_NONE`, `present` false
 */
func emptyId3v1() {
    return Id3v1{
        present: false,
        title: "",
        artist: "",
        album: "",
        year: "",
        comment: "",
        track: 0,
        genre: GENRE_NONE,
        version11: false
    };
}

/**
 * Read one fixed-width ISO-8859-1 field.
 *
 * @param data {bytes} the whole file
 * @param offset {int} where the field starts
 * @param width {int} how many bytes it occupies
 * @return {string} the text, NUL-terminated and trimmed
 */
func fixedField(data as bytes, offset as int, width as int) {
    needBytes($data, $offset, $width);
    def raw as bytes init binary.slice($data, $offset, $offset + $width);
    return trimField(decodeLatin1($raw));
}

/**
 * Render an ID3v1 tag to its 128 bytes.
 *
 * Writes ID3v1.1 with a 28-byte comment when `track` is 1-255, otherwise
 * the 30-byte comment and no track. Text is truncated to the field width,
 * characters above U+00FF become `?` and NULs are removed. A genre outside
 * 0-191 is written as `GENRE_NONE`.
 *
 * @param tag {Id3v1} the tag to write; `present` is ignored
 * @return {bytes} exactly 128 bytes, starting with `TAG`
 * @example
 *   def v1 as mp3.Id3v1;
 *   $v1.title = "Ich war müde leer nicht mehr da";
 *   def block as bytes init mp3.renderId3v1($v1);   # 128 bytes
 */
export func renderId3v1(tag as Id3v1) {
    def parts as list of bytes init [];
    $parts[] = latin1Bytes("TAG");
    $parts[] = fixedBytes($tag.title, 30);
    $parts[] = fixedBytes($tag.artist, 30);
    $parts[] = fixedBytes($tag.album, 30);
    $parts[] = fixedBytes($tag.year, 4);
    if ($tag.track > 0 and $tag.track < 256) {
        $parts[] = fixedBytes($tag.comment, 28);
        $parts[] = binary.make(1, PAD_BYTE);
        $parts[] = binary.make(1, $tag.track);
    } else {
        $parts[] = fixedBytes($tag.comment, 30);
    }
    $parts[] = binary.make(1, genreByte($tag.genre));
    return binary.join($parts);
}

/**
 * The genre byte to write for a genre number.
 *
 * @param genre {int} the genre number
 * @return {int} the number itself when it is assigned, else `GENRE_NONE`
 */
func genreByte(genre as int) {
    if ($genre < 0 or $genre >= GENRE_COUNT) {
        return GENRE_NONE;
    }
    return $genre;
}

/**
 * Render a string into a fixed-width NUL-padded ISO-8859-1 field.
 *
 * @param s {string} the text to write
 * @param width {int} how many bytes the field occupies
 * @return {bytes} exactly `width` bytes
 */
func fixedBytes(s as string, width as int) {
    def flat as string init toLatin1Lossy($s);
    if (len($flat) > $width) {
        $flat = strings.substring($flat, 0, $width);
    }
    def encoded as bytes init latin1Bytes($flat);
    def padding as int init $width - len($encoded);
    if ($padding <= 0) {
        return $encoded;
    }
    def parts as list of bytes init [];
    $parts[] = $encoded;
    $parts[] = binary.make($padding, PAD_BYTE);
    return binary.join($parts);
}

/**
 * Replace every character ISO-8859-1 cannot spell with `?`.
 *
 * Also drops the NUL, which would end the field early.
 *
 * @param s {string} the text to flatten
 * @return {string} text every byte of which fits in ISO-8859-1
 */
func toLatin1Lossy(s as string) {
    def chars as list of string init strings.chars($s);
    def out as list of string init [];
    for (def ch in $chars) {
        def code as int init convert.toCodepoint($ch);
        if ($code == 0) {
            continue;
        }
        if ($code > 0xff) {
            $out[] = "?";
            continue;
        }
        $out[] = $ch;
    }
    return strings.join($out, "");
}
