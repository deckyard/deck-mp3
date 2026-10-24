# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the four ID3v2 text encodings, and the strings built on them.
# Spliced into mp3.j via include - not a standalone module.

/** ID3v2 text encoding 0: ISO-8859-1, one byte per character. */
export def const TEXT_LATIN1 as int init 0;

/** ID3v2 text encoding 1: UTF-16 with a byte-order mark. ID3v2.2 and up. */
export def const TEXT_UTF16 as int init 1;

/** ID3v2 text encoding 2: UTF-16BE with no byte-order mark. ID3v2.4 only. */
export def const TEXT_UTF16BE as int init 2;

/** ID3v2 text encoding 3: UTF-8. ID3v2.4 only. */
export def const TEXT_UTF8 as int init 3;

/** The code point substituted for a byte sequence that decodes to nothing. */
def const REPLACEMENT as int init 0xfffd;

/**
 * One string read out of a frame, and where the next one starts.
 *
 * Jennifer has no tuples, so the string readers return both in one struct.
 *
 * @field text {string} the decoded string, without its terminator
 * @field next {int} the offset after the terminator, or the end of the
 *     buffer when the string was not terminated
 */
def struct TextField {
    text as string,
    next as int
};

/**
 * How many bytes end a string in this encoding.
 *
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {int} 2 for the UTF-16 encodings, 1 for the others
 */
func terminatorSize(enc as int) {
    if ($enc == TEXT_UTF16 or $enc == TEXT_UTF16BE) {
        return 2;
    }
    return 1;
}

/**
 * Whether a number names one of the four ID3v2 text encodings.
 *
 * @param enc {int} the encoding byte
 * @return {bool} true for 0-3
 */
func isTextEncoding(enc as int) {
    return $enc >= TEXT_LATIN1 and $enc <= TEXT_UTF8;
}

/**
 * The text encoding a frame's encoding byte names.
 *
 * A byte outside 0-3 resolves to ISO-8859-1, which decodes any byte, so a
 * damaged encoding byte costs one frame its text instead of failing the
 * read. {@link decodeText} stays strict: a bad encoding passed by hand is a
 * caller's mistake.
 *
 * @param byte {int} the frame's first byte
 * @return {int} one of the four `TEXT_*` constants
 */
func textEncodingOf(byte as int) {
    if (isTextEncoding($byte)) {
        return $byte;
    }
    return TEXT_LATIN1;
}

/**
 * Decode a whole buffer as ID3v2 text.
 *
 * For bodies of frames the deck does not map. Lenient: invalid UTF-8 falls
 * back to ISO-8859-1, and UTF-16 without a BOM is read little-endian (UTF-16
 * with a BOM honours it); an unpaired surrogate or odd trailing byte becomes
 * U+FFFD.
 *
 * @param data {bytes} the bytes of the string, with no terminator
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {string} the decoded text
 * @throws {Error} when `enc` is not 0-3
 */
export func decodeText(data as bytes, enc as int) {
    if (not isTextEncoding($enc)) {
        fail("unknown ID3v2 text encoding " + convert.toString($enc));
    }
    if (len($data) == 0) {
        return "";
    }
    if ($enc == TEXT_UTF16) {
        return decodeUtf16($data, false);
    }
    if ($enc == TEXT_UTF16BE) {
        return decodeUtf16($data, true);
    }
    if ($enc == TEXT_UTF8) {
        try {
            return convert.stringFromBytes($data, "utf-8");
        } catch (e) {
            return decodeLatin1($data);
        }
    }
    return decodeLatin1($data);
}

/**
 * Decode a buffer as ISO-8859-1.
 *
 * Every one of the 256 bytes has a character, so this never fails.
 *
 * @param data {bytes} the bytes to decode
 * @return {string} the decoded text
 */
func decodeLatin1(data as bytes) {
    return encoding.decode($data, "iso-8859-1");
}

/**
 * Decode a buffer as UTF-16.
 *
 * A leading byte-order mark overrides `bigEndian`, which is only the default
 * for a buffer that carries none. Surrogate pairs combine; an unpaired
 * surrogate and a trailing odd byte each become U+FFFD rather than an error.
 *
 * @param data {bytes} the bytes to decode
 * @param bigEndian {bool} the byte order to assume with no BOM
 * @return {string} the decoded text
 */
func decodeUtf16(data as bytes, bigEndian as bool) {
    def size as int init len($data);
    def i as int init 0;
    def big as bool init $bigEndian;
    if ($size >= 2) {
        def first as int init $data[0];
        def second as int init $data[1];
        if ($first == 0xff and $second == 0xfe) {
            $big = false;
            $i = 2;
        } elseif ($first == 0xfe and $second == 0xff) {
            $big = true;
            $i = 2;
        }
    }
    def parts as list of string init [];
    while ($i + 1 < $size) {
        def unit as int init utf16Unit($data, $i, $big);
        $i = $i + 2;
        if ($unit >= 0xd800 and $unit <= 0xdbff and $i + 1 < $size) {
            def low as int init utf16Unit($data, $i, $big);
            if ($low >= 0xdc00 and $low <= 0xdfff) {
                $i = $i + 2;
                def high as int init ($unit - 0xd800) << 10;
                $parts[] = convert.fromCodepoint(0x10000 + $high + ($low - 0xdc00));
                continue;
            }
        }
        if ($unit >= 0xd800 and $unit <= 0xdfff) {
            $parts[] = convert.fromCodepoint(REPLACEMENT);
            continue;
        }
        $parts[] = convert.fromCodepoint($unit);
    }
    if ($i < $size) {
        $parts[] = convert.fromCodepoint(REPLACEMENT);
    }
    return strings.join($parts, "");
}

/**
 * Read one UTF-16 code unit.
 *
 * @param data {bytes} the buffer
 * @param offset {int} the first of the two bytes
 * @param bigEndian {bool} the byte order
 * @return {int} the code unit, 0-65535
 */
func utf16Unit(data as bytes, offset as int, bigEndian as bool) {
    if ($bigEndian) {
        return ($data[$offset] << 8) | $data[$offset + 1];
    }
    return ($data[$offset + 1] << 8) | $data[$offset];
}

/**
 * Encode a string as ID3v2 text.
 *
 * For bodies of frames the deck does not map. `TEXT_UTF16` writes a
 * little-endian BOM (`ff fe`) first; `TEXT_UTF16BE` writes none. No
 * terminator is appended.
 *
 * @param s {string} the text to encode
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {bytes} the encoded text
 * @throws {Error} when `enc` is not 0-3, or when `s` has a character
 *     ISO-8859-1 cannot spell and `enc` is `TEXT_LATIN1`
 */
export func encodeText(s as string, enc as int) {
    if (not isTextEncoding($enc)) {
        fail("unknown ID3v2 text encoding " + convert.toString($enc));
    }
    if ($enc == TEXT_UTF8) {
        return convert.bytesFromString($s, "utf-8");
    }
    if ($enc == TEXT_UTF16) {
        return encodeUtf16($s, false, true);
    }
    if ($enc == TEXT_UTF16BE) {
        return encodeUtf16($s, true, false);
    }
    if (not isLatin1($s)) {
        fail("text cannot be written as ISO-8859-1: " + $s);
    }
    return encoding.encode($s, "iso-8859-1");
}

/**
 * Encode a string as UTF-16.
 *
 * @param s {string} the text to encode
 * @param bigEndian {bool} the byte order to write
 * @param withBom {bool} whether to lead with a byte-order mark
 * @return {bytes} the encoded text
 */
func encodeUtf16(s as string, bigEndian as bool, withBom as bool) {
    def out as bytes;
    if ($withBom) {
        if ($bigEndian) {
            $out[] = 0xfe;
            $out[] = 0xff;
        } else {
            $out[] = 0xff;
            $out[] = 0xfe;
        }
    }
    def chars as list of string init strings.chars($s);
    for (def ch in $chars) {
        def code as int init convert.toCodepoint($ch);
        if ($code < 0x10000) {
            $out = pushUtf16Unit($out, $code, $bigEndian);
            continue;
        }
        def rest as int init $code - 0x10000;
        $out = pushUtf16Unit($out, 0xd800 | ($rest >> 10), $bigEndian);
        $out = pushUtf16Unit($out, 0xdc00 | ($rest & 0x3ff), $bigEndian);
    }
    return $out;
}

/**
 * Append one UTF-16 code unit to a buffer.
 *
 * @param out {bytes} the accumulator, returned grown
 * @param unit {int} the code unit, 0-65535
 * @param bigEndian {bool} the byte order
 * @return {bytes} `out` with the two bytes appended
 */
func pushUtf16Unit(out as bytes, unit as int, bigEndian as bool) {
    def grown as bytes init $out;
    if ($bigEndian) {
        $grown[] = ($unit >> 8) & 0xff;
        $grown[] = $unit & 0xff;
    } else {
        $grown[] = $unit & 0xff;
        $grown[] = ($unit >> 8) & 0xff;
    }
    return $grown;
}

/**
 * Whether every character of `s` has a byte in ISO-8859-1.
 *
 * Asks the codec, which runs in Go; a per-rune loop would allocate a string
 * per character.
 *
 * @param s {string} the text to test
 * @return {bool} true when no code point is above U+00FF
 */
func isLatin1(s as string) {
    try {
        encoding.encode($s, "iso-8859-1");
        return true;
    } catch (e) {
        return false;
    }
}

/**
 * Whether every character is printable ASCII, `0x20` to `0x7e`.
 *
 * Meant for short identifiers such as a media type: it walks the bytes.
 *
 * @param s {string} the text to test
 * @return {bool} true when it is
 */
func isPrintableAscii(s as string) {
    def raw as bytes init convert.bytesFromString($s, "utf-8");
    for (def i as int init 0; $i < len($raw); $i = $i + 1) {
        if ($raw[$i] < 0x20 or $raw[$i] > 0x7e) {
            return false;
        }
    }
    return true;
}

/**
 * Drop every NUL from a string.
 *
 * A NUL ends a string inside a frame, so one inside a value would re-parse
 * as a different frame. The writers strip them so a written tag reads back
 * the same.
 *
 * @param s {string} the text about to be written
 * @return {string} the text with no NUL in it
 */
func withoutNuls(s as string) {
    def nul as string init convert.fromCodepoint(0);
    if (not strings.contains($s, $nul)) {
        return $s;
    }
    return strings.replace($s, $nul, "");
}

/**
 * The narrowest encoding that can spell `s` in this ID3v2 version.
 *
 * ISO-8859-1 when it fits, because every reader handles it; otherwise UTF-8
 * on ID3v2.4 and UTF-16 with a BOM on earlier versions, which lack UTF-8.
 *
 * @param s {string} the text about to be written
 * @param major {int} the ID3v2 major version, 2-4
 * @return {int} one of the four `TEXT_*` constants
 */
func pickEncoding(s as string, major as int) {
    if (isLatin1($s)) {
        return TEXT_LATIN1;
    }
    if ($major >= 4) {
        return TEXT_UTF8;
    }
    return TEXT_UTF16;
}

/**
 * The narrowest encoding that can spell every string in a list.
 *
 * @param values {list of string} the strings about to be written
 * @param major {int} the ID3v2 major version, 2-4
 * @return {int} one of the four `TEXT_*` constants
 */
func pickEncodingAll(values as list of string, major as int) {
    def chosen as int init TEXT_LATIN1;
    for (def v in $values) {
        def wanted as int init pickEncoding($v, $major);
        if ($wanted > $chosen) {
            $chosen = $wanted;
        }
    }
    return $chosen;
}

/**
 * Read one NUL-terminated string out of a frame.
 *
 * An unterminated string runs to the end of the buffer, which is how the
 * last field of a frame is normally stored.
 *
 * @param data {bytes} the frame body
 * @param offset {int} where the string starts
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {TextField} the decoded string and the offset past its terminator
 * @throws {Error} when `offset` is outside the buffer
 */
func readTerminated(data as bytes, offset as int, enc as int) {
    def size as int init len($data);
    if ($offset < 0 or $offset > $size) {
        fail("string offset " + convert.toString($offset) + " is outside the frame");
    }
    def width as int init terminatorSize($enc);
    def end as int init terminatorIndex($data, $offset, $width);
    if ($end < 0) {
        def whole as bytes init binary.slice($data, $offset, $size);
        return TextField{text: decodeText($whole, $enc), next: $size};
    }
    def body as bytes init binary.slice($data, $offset, $end);
    return TextField{text: decodeText($body, $enc), next: $end + $width};
}

/**
 * The offset of the terminator at or after `offset`.
 *
 * A two-byte terminator only counts on an even offset from the start of the
 * string, so a NUL byte inside a UTF-16 character cannot end it.
 *
 * @param data {bytes} the frame body
 * @param offset {int} where the string starts
 * @param width {int} 1 or 2, the terminator size
 * @return {int} the terminator offset, or `-1` when there is none
 */
func terminatorIndex(data as bytes, offset as int, width as int) {
    def size as int init len($data);
    if ($width == 1) {
        def i as int init $offset;
        while ($i < $size) {
            if ($data[$i] == 0) {
                return $i;
            }
            $i = $i + 1;
        }
        return -1;
    }
    def j as int init $offset;
    while ($j + 1 < $size) {
        if ($data[$j] == 0 and $data[$j + 1] == 0) {
            return $j;
        }
        $j = $j + 2;
    }
    return -1;
}

/**
 * Split a text frame body into its values.
 *
 * ID3v2.4 allows several values in one text frame, separated by a terminator
 * in the frame's encoding. Earlier versions allow one, so a trailing NUL is
 * padding rather than a separator: either way, empty values are dropped.
 *
 * @param data {bytes} the frame body after its encoding byte
 * @param enc {int} one of the four `TEXT_*` constants
 * @return {list of string} the values, in order, with the empties removed
 */
func splitValues(data as bytes, enc as int) {
    def values as list of string init [];
    def at as int init 0;
    def size as int init len($data);
    while ($at < $size) {
        def field as TextField init readTerminated($data, $at, $enc);
        if ($field.text != "") {
            $values[] = $field.text;
        }
        if ($field.next <= $at) {
            break;
        }
        $at = $field.next;
    }
    return $values;
}

/**
 * Strip the NUL and space padding an ID3v1 fixed-width field carries.
 *
 * @param s {string} the raw field text
 * @return {string} the text up to the first NUL, trimmed
 */
func trimField(s as string) {
    def cut as int init strings.indexOf($s, convert.fromCodepoint(0));
    def head as string init $s;
    if ($cut >= 0) {
        $head = strings.substring($s, 0, $cut);
    }
    return strings.trim($head);
}
