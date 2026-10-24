# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the shared primitives every other topic builds on.
# Spliced into mp3.j via include - not a standalone module.

/** The `kind` every `Error` this deck raises carries. */
export def const ERROR_KIND as string init "mp3";

/** The largest value a 32-bit big-endian field can hold. */
def const UINT32_MAX as int init 4294967295;

/** The largest value a 28-bit synchsafe integer can hold. */
export def const SYNCSAFE_MAX as int init 268435455;

/**
 * Raise a deck error.
 *
 * Every deck error goes through here, so callers can catch them with one
 * `kind` test. The message names the frame, offset or field involved.
 *
 * @param message {string} what went wrong, in plain words
 * @throws {Error} always, with `kind` `"mp3"`
 */
func fail(message as string) {
    throw Error{kind: ERROR_KIND, message: $message, file: "", line: 0, col: 0};
}

/**
 * Check that `count` bytes can be read at `offset`.
 *
 * The byte readers call this first, so a short buffer raises a deck error
 * with the offset instead of the interpreter's out-of-range error.
 *
 * @param data {bytes} the buffer being read
 * @param offset {int} where the read starts
 * @param count {int} how many bytes it wants
 * @throws {Error} when the range is negative or runs past the end
 */
func needBytes(data as bytes, offset as int, count as int) {
    def size as int init len($data);
    if ($offset < 0 or $count < 0 or $offset + $count > $size) {
        def at as string init convert.toString($offset);
        def n as string init convert.toString($count);
        def total as string init convert.toString($size);
        fail("read of " + $n + " at " + $at + " runs past " + $total + " bytes");
    }
}

/**
 * Read a 16-bit big-endian unsigned integer.
 *
 * @param data {bytes} the buffer
 * @param offset {int} the first of the two bytes
 * @return {int} the value, 0-65535
 * @throws {Error} when the two bytes are not both inside the buffer
 */
func beUint16(data as bytes, offset as int) {
    needBytes($data, $offset, 2);
    return ($data[$offset] << 8) | $data[$offset + 1];
}

/**
 * Read a 24-bit big-endian unsigned integer.
 *
 * ID3v2.2 records every frame size this way.
 *
 * @param data {bytes} the buffer
 * @param offset {int} the first of the three bytes
 * @return {int} the value, 0-16777215
 * @throws {Error} when the three bytes are not all inside the buffer
 */
func beUint24(data as bytes, offset as int) {
    needBytes($data, $offset, 3);
    def hi as int init $data[$offset] << 16;
    return $hi | ($data[$offset + 1] << 8) | $data[$offset + 2];
}

/**
 * Read a 32-bit big-endian unsigned integer.
 *
 * @param data {bytes} the buffer
 * @param offset {int} the first of the four bytes
 * @return {int} the value, 0-4294967295
 * @throws {Error} when the four bytes are not all inside the buffer
 */
func beUint32(data as bytes, offset as int) {
    needBytes($data, $offset, 4);
    def hi as int init ($data[$offset] << 8) | $data[$offset + 1];
    def lo as int init ($data[$offset + 2] << 8) | $data[$offset + 3];
    return ($hi << 16) | $lo;
}

/**
 * Read a 28-bit synchsafe integer.
 *
 * Four bytes of seven bits each: the ID3v2 tag size and every ID3v2.4 frame
 * size. The high bit of each byte is masked off, not rejected, because real
 * files set it.
 *
 * @param data {bytes} the buffer
 * @param offset {int} the first of the four bytes
 * @return {int} the value, 0-268435455
 * @throws {Error} when the four bytes are not all inside the buffer
 */
func syncsafe32(data as bytes, offset as int) {
    needBytes($data, $offset, 4);
    def a as int init $data[$offset] & 0x7f;
    def b as int init $data[$offset + 1] & 0x7f;
    def c as int init $data[$offset + 2] & 0x7f;
    def d as int init $data[$offset + 3] & 0x7f;
    return ($a << 21) | ($b << 14) | ($c << 7) | $d;
}

/**
 * Render a 32-bit big-endian unsigned integer.
 *
 * @param value {int} the number to write
 * @return {bytes} exactly four bytes
 * @throws {Error} when `value` does not fit in 32 unsigned bits
 */
func beUint32Bytes(value as int) {
    if ($value < 0 or $value > UINT32_MAX) {
        fail(convert.toString($value) + " does not fit in a 32-bit field");
    }
    def out as bytes;
    $out[] = ($value >> 24) & 0xff;
    $out[] = ($value >> 16) & 0xff;
    $out[] = ($value >> 8) & 0xff;
    $out[] = $value & 0xff;
    return $out;
}

/**
 * Render a 28-bit synchsafe integer.
 *
 * The inverse of {@link syncsafe32}: four bytes of seven bits, high bit
 * clear.
 *
 * @param value {int} the number to write
 * @return {bytes} exactly four bytes
 * @throws {Error} when `value` does not fit in 28 bits
 */
func syncsafe32Bytes(value as int) {
    if ($value < 0 or $value > SYNCSAFE_MAX) {
        fail(convert.toString($value) + " does not fit in a synchsafe field");
    }
    def out as bytes;
    $out[] = ($value >> 21) & 0x7f;
    $out[] = ($value >> 14) & 0x7f;
    $out[] = ($value >> 7) & 0x7f;
    $out[] = $value & 0x7f;
    return $out;
}

/**
 * The largest number {@link leadingInt} will build.
 *
 * Track numbers, tempos and playlist durations come from free text, which
 * can hold thirty digits. `int64` overflow raises in Jennifer, so
 * {@link leadingInt} saturates here.
 */
def const LEADING_INT_MAX as int init 999999999;

/**
 * Parse a leading run of ASCII digits.
 *
 * Trims, then reads digits up to the first non-digit. Text with no leading
 * digit gives `0`. A value past {@link LEADING_INT_MAX} saturates there.
 *
 * @param s {string} the text to read
 * @return {int} the leading number, 0 to `LEADING_INT_MAX`
 */
func leadingInt(s as string) {
    def trimmed as string init strings.trim($s);
    def n as int init 0;
    def seen as bool init false;
    def chars as list of string init strings.chars($trimmed);
    for (def ch in $chars) {
        def code as int init convert.toCodepoint($ch);
        if ($code < 0x30 or $code > 0x39) {
            break;
        }
        $seen = true;
        if ($n > LEADING_INT_MAX) {
            continue;
        }
        $n = $n * 10 + ($code - 0x30);
    }
    if (not $seen) {
        return 0;
    }
    if ($n > LEADING_INT_MAX) {
        return LEADING_INT_MAX;
    }
    return $n;
}

/**
 * Whether `data` carries the ASCII text `want` at `offset`.
 *
 * Byte-exact; a read past the end is false, not an error.
 *
 * @param data {bytes} the buffer to look in
 * @param offset {int} where to look
 * @param want {string} the ASCII text to match
 * @return {bool} true when the bytes at `offset` spell `want`
 */
func magicAt(data as bytes, offset as int, want as string) {
    def n as int init len($want);
    if ($offset < 0 or $n == 0 or $offset + $n > len($data)) {
        return false;
    }
    def seen as bytes init binary.slice($data, $offset, $offset + $n);
    return decodeLatin1($seen) == $want;
}

/**
 * The ISO-8859-1 bytes of a string.
 *
 * @param s {string} the text to encode
 * @return {bytes} one byte per character
 * @throws {Error} when a character has no byte in ISO-8859-1
 */
func latin1Bytes(s as string) {
    return encoding.encode($s, "iso-8859-1");
}
