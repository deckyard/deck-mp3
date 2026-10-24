# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the core topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

func bytesOf(values as list of int) {
    def out as bytes;
    for (def v in $values) {
        $out[] = $v;
    }
    return $out;
}

func testFailCarriesTheDeckKind() {
    testing.assertEqual(ERROR_KIND, "mp3");
    testing.assertThrows("failOnce", ERROR_KIND);
}

func failOnce() {
    fail("deliberate");
}

func testNeedBytesAcceptsExactFits() {
    def b as bytes init bytesOf([1, 2, 3, 4]);
    needBytes($b, 0, 4);
    needBytes($b, 4, 0);
    needBytes($b, 2, 2);
    testing.assertEqual(len($b), 4);
}

func testNeedBytesRejectsOverruns() {
    testing.assertThrows("needPastEnd", ERROR_KIND);
    testing.assertThrows("needNegativeOffset", ERROR_KIND);
    testing.assertThrows("needNegativeCount", ERROR_KIND);
}

func needPastEnd() {
    needBytes(bytesOf([1, 2]), 1, 2);
}

func needNegativeOffset() {
    needBytes(bytesOf([1, 2]), -1, 1);
}

func needNegativeCount() {
    needBytes(bytesOf([1, 2]), 0, -1);
}

func testBigEndianReaders() {
    def b as bytes init bytesOf([0xde, 0xad, 0xbe, 0xef]);
    testing.assertEqual(beUint16($b, 0), 0xdead);
    testing.assertEqual(beUint16($b, 2), 0xbeef);
    testing.assertEqual(beUint24($b, 0), 0xdeadbe);
    testing.assertEqual(beUint32($b, 0), 0xdeadbeef);
}

func testBigEndianReadersAtTheTop() {
    def b as bytes init bytesOf([0xff, 0xff, 0xff, 0xff]);
    testing.assertEqual(beUint32($b, 0), 4294967295);
    testing.assertEqual(beUint24($b, 1), 16777215);
}

func testSyncsafeIgnoresTheHighBit() {
    # 0x7f 0x7f 0x7f 0x7f is the largest value the field can hold
    def full as bytes init bytesOf([0x7f, 0x7f, 0x7f, 0x7f]);
    testing.assertEqual(syncsafe32($full, 0), SYNCSAFE_MAX);
    testing.assertEqual(SYNCSAFE_MAX, 268435455);

    # the high bit of each byte is ignored, not rejected
    def sloppy as bytes init bytesOf([0xff, 0xff, 0xff, 0xff]);
    testing.assertEqual(syncsafe32($sloppy, 0), SYNCSAFE_MAX);

    def small as bytes init bytesOf([0x00, 0x00, 0x02, 0x01]);
    testing.assertEqual(syncsafe32($small, 0), 257);
}

func testSyncsafeRoundTrip() {
    def values as list of int init [0, 1, 127, 128, 257, 1024, 268435455];
    for (def v in $values) {
        testing.assertEqual(syncsafe32(syncsafe32Bytes($v), 0), $v);
    }
}

func testSyncsafeBytesAreSevenBitClean() {
    def b as bytes init syncsafe32Bytes(SYNCSAFE_MAX);
    testing.assertEqual(len($b), 4);
    for (def i as int init 0; $i < 4; $i = $i + 1) {
        testing.assertEqual($b[$i] & 0x80, 0);
    }
}

func testSyncsafeBytesRejectOverflow() {
    testing.assertThrows("syncsafeTooBig", ERROR_KIND);
    testing.assertThrows("syncsafeNegative", ERROR_KIND);
}

func syncsafeTooBig() {
    syncsafe32Bytes(SYNCSAFE_MAX + 1);
}

func syncsafeNegative() {
    syncsafe32Bytes(-1);
}

func testBeUint32RoundTrip() {
    def values as list of int init [0, 1, 255, 65536, 4294967295];
    for (def v in $values) {
        testing.assertEqual(beUint32(beUint32Bytes($v), 0), $v);
    }
}

func testBeUint32BytesRejectOverflow() {
    testing.assertThrows("beTooBig", ERROR_KIND);
    testing.assertThrows("beNegative", ERROR_KIND);
}

func beTooBig() {
    beUint32Bytes(4294967296);
}

func beNegative() {
    beUint32Bytes(-1);
}

func testLeadingInt() {
    testing.assertEqual(leadingInt("12"), 12);
    testing.assertEqual(leadingInt("  7  "), 7);
    testing.assertEqual(leadingInt("12/34"), 12);
    testing.assertEqual(leadingInt("0"), 0);
    testing.assertEqual(leadingInt(""), 0);
    testing.assertEqual(leadingInt("abc"), 0);
    testing.assertEqual(leadingInt("-5"), 0);
    testing.assertEqual(leadingInt("2003-05-01"), 2003);
}

func testMagicAt() {
    def b as bytes init convert.bytesFromString("xxID3yy", "utf-8");
    testing.assertTrue(magicAt($b, 2, "ID3"));
    testing.assertFalse(magicAt($b, 1, "ID3"));
    testing.assertFalse(magicAt($b, 5, "ID3"));
    testing.assertFalse(magicAt($b, -1, "ID3"));
    testing.assertFalse(magicAt($b, 0, ""));
}

func testLatin1Bytes() {
    def b as bytes init latin1Bytes("TAG");
    testing.assertEqual(len($b), 3);
    testing.assertEqual($b[0], 0x54);
    # one byte per character, even above ASCII
    testing.assertEqual(len(latin1Bytes("ä")), 1);
    testing.assertEqual(latin1Bytes("ä")[0], 0xe4);
}

func testLeadingIntSaturatesRatherThanOverflowing() {
    # multiplying past int64 raises in Jennifer, and a free-text field can
    # spell any number of digits
    testing.assertEqual(leadingInt("999999999"), LEADING_INT_MAX);
    testing.assertEqual(leadingInt("99999999999999999999"), LEADING_INT_MAX);
    testing.assertEqual(leadingInt(strings.repeat("9", 400)), LEADING_INT_MAX);
    testing.assertEqual(leadingInt("1000000000"), LEADING_INT_MAX);
    # and the digits after the saturation point are still consumed, so a
    # trailing non-digit does not change the answer
    testing.assertEqual(leadingInt("99999999999999999999x"), LEADING_INT_MAX);
}

func testVersionIsASemverString() {
    # version.j is generated by tools/inject-version.sh, so the value moves
    # with the git tags; the shape is what can be asserted
    testing.assertNotEqual(VERSION, "");
    def parts as list of string init strings.split(VERSION, ".");
    testing.assertTrue(len($parts) >= 3);
    testing.assertEqual(leadingInt($parts[0]), convert.toInt($parts[0]));
    testing.assertTrue(leadingInt($parts[1]) >= 0);
}
