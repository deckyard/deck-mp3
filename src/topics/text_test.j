# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the text topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

func testEncodingConstants() {
    testing.assertEqual(TEXT_LATIN1, 0);
    testing.assertEqual(TEXT_UTF16, 1);
    testing.assertEqual(TEXT_UTF16BE, 2);
    testing.assertEqual(TEXT_UTF8, 3);
}

func testTerminatorSize() {
    testing.assertEqual(terminatorSize(TEXT_LATIN1), 1);
    testing.assertEqual(terminatorSize(TEXT_UTF16), 2);
    testing.assertEqual(terminatorSize(TEXT_UTF16BE), 2);
    testing.assertEqual(terminatorSize(TEXT_UTF8), 1);
}

func testIsTextEncoding() {
    testing.assertTrue(isTextEncoding(0));
    testing.assertTrue(isTextEncoding(3));
    testing.assertFalse(isTextEncoding(-1));
    testing.assertFalse(isTextEncoding(4));
}

func testRoundTripThroughEveryEncoding() {
    def samples as list of string init ["", "ascii", "Grüße", "日本語", "mixed ü 日 x"];
    def encodings as list of int init [TEXT_UTF16, TEXT_UTF16BE, TEXT_UTF8];
    for (def s in $samples) {
        for (def e in $encodings) {
            testing.assertEqual(decodeText(encodeText($s, $e), $e), $s);
        }
    }
}

func testLatin1RoundTrip() {
    def samples as list of string init ["", "ascii", "Grüße", "café"];
    for (def s in $samples) {
        testing.assertEqual(decodeText(encodeText($s, TEXT_LATIN1), TEXT_LATIN1), $s);
    }
}

func testLatin1RefusesWhatItCannotSpell() {
    testing.assertThrows("latin1Japanese", ERROR_KIND);
}

func latin1Japanese() {
    encodeText("日本語", TEXT_LATIN1);
}

func testUnknownEncodingIsRejected() {
    testing.assertThrows("decodeUnknownEncoding", ERROR_KIND);
    testing.assertThrows("encodeUnknownEncoding", ERROR_KIND);
}

func decodeUnknownEncoding() {
    decodeText(binary.make(2, 65), 9);
}

func encodeUnknownEncoding() {
    encodeText("x", 9);
}

func testUtf16WritesABomAndUtf16beDoesNot() {
    def withBom as bytes init encodeText("A", TEXT_UTF16);
    testing.assertEqual(len($withBom), 4);
    testing.assertEqual($withBom[0], 0xff);
    testing.assertEqual($withBom[1], 0xfe);

    def bare as bytes init encodeText("A", TEXT_UTF16BE);
    testing.assertEqual(len($bare), 2);
    testing.assertEqual($bare[0], 0x00);
    testing.assertEqual($bare[1], 0x41);
}

func testABomOverridesTheAssumedByteOrder() {
    # big-endian bytes with a big-endian mark, read as if little-endian
    def beBytes as bytes init bytesOf([0xfe, 0xff, 0x00, 0x41]);
    testing.assertEqual(decodeUtf16($beBytes, false), "A");

    # little-endian bytes with a little-endian mark, read as if big-endian
    def leBytes as bytes init bytesOf([0xff, 0xfe, 0x41, 0x00]);
    testing.assertEqual(decodeUtf16($leBytes, true), "A");
}

func testSurrogatePairsSurviveUtf16() {
    # U+1F600, which needs a surrogate pair in UTF-16
    def emoji as string init convert.fromCodepoint(0x1f600);
    def encoded as bytes init encodeText($emoji, TEXT_UTF16BE);
    testing.assertEqual(len($encoded), 4);
    testing.assertEqual($encoded[0], 0xd8);
    testing.assertEqual($encoded[1], 0x3d);
    testing.assertEqual(decodeText($encoded, TEXT_UTF16BE), $emoji);
}

func testALoneSurrogateBecomesTheReplacementCharacter() {
    def lone as bytes init bytesOf([0xd8, 0x3d, 0x00, 0x41]);
    def decoded as string init decodeUtf16($lone, true);
    testing.assertEqual(len($decoded), 2);
    testing.assertEqual(convert.toCodepoint(strings.substring($decoded, 0, 1)), 0xfffd);
    testing.assertEqual(strings.substring($decoded, 1), "A");
}

func testATrailingOddByteBecomesTheReplacementCharacter() {
    def odd as bytes init bytesOf([0x00, 0x41, 0x00]);
    def decoded as string init decodeUtf16($odd, true);
    testing.assertEqual($decoded, "A" + convert.fromCodepoint(0xfffd));
}

func testBadUtf8FallsBackToLatin1RatherThanThrowing() {
    # 0xff is never a legal UTF-8 byte; ISO-8859-1 spells it y-diaeresis
    def broken as bytes init bytesOf([0xff]);
    testing.assertEqual(decodeText($broken, TEXT_UTF8), "ÿ");
}

func testIsLatin1() {
    testing.assertTrue(isLatin1(""));
    testing.assertTrue(isLatin1("Grüße"));
    testing.assertFalse(isLatin1("日本語"));
}

func testPickEncodingTakesTheNarrowestThatFits() {
    testing.assertEqual(pickEncoding("plain", 4), TEXT_LATIN1);
    testing.assertEqual(pickEncoding("Grüße", 3), TEXT_LATIN1);
    testing.assertEqual(pickEncoding("日本語", 4), TEXT_UTF8);
    # ID3v2.2 and ID3v2.3 have no UTF-8, so they fall to UTF-16
    testing.assertEqual(pickEncoding("日本語", 3), TEXT_UTF16);
    testing.assertEqual(pickEncoding("日本語", 2), TEXT_UTF16);
}

func testPickEncodingAllTakesTheWidestNeeded() {
    def latin as list of string init ["a", "ü"];
    testing.assertEqual(pickEncodingAll($latin, 4), TEXT_LATIN1);
    def wide as list of string init ["a", "日"];
    testing.assertEqual(pickEncodingAll($wide, 4), TEXT_UTF8);
    def none as list of string init [];
    testing.assertEqual(pickEncodingAll($none, 4), TEXT_LATIN1);
}

func testReadTerminatedStopsAtTheTerminator() {
    def data as bytes init bytesOf([0x61, 0x62, 0x00, 0x63]);
    def field as TextField init readTerminated($data, 0, TEXT_LATIN1);
    testing.assertEqual($field.text, "ab");
    testing.assertEqual($field.next, 3);

    def rest as TextField init readTerminated($data, $field.next, TEXT_LATIN1);
    testing.assertEqual($rest.text, "c");
    testing.assertEqual($rest.next, 4);
}

func testReadTerminatedRunsToTheEndWhenUnterminated() {
    def data as bytes init bytesOf([0x61, 0x62]);
    def field as TextField init readTerminated($data, 0, TEXT_LATIN1);
    testing.assertEqual($field.text, "ab");
    testing.assertEqual($field.next, 2);
}

func testReadTerminatedNeedsTwoNulsForUtf16() {
    # the high byte of "A" is a NUL and must not end the string
    def data as bytes init bytesOf([0x00, 0x41, 0x00, 0x42, 0x00, 0x00, 0x00, 0x43]);
    def field as TextField init readTerminated($data, 0, TEXT_UTF16BE);
    testing.assertEqual($field.text, "AB");
    testing.assertEqual($field.next, 6);
}

func testReadTerminatedRejectsAnOffsetOutsideTheFrame() {
    testing.assertThrows("readTerminatedPastEnd", ERROR_KIND);
}

func readTerminatedPastEnd() {
    readTerminated(binary.make(2, 65), 3, TEXT_LATIN1);
}

func testSplitValuesDropsTheEmpties() {
    def data as bytes init bytesOf([0x61, 0x00, 0x62, 0x00]);
    def values as list of string init splitValues($data, TEXT_LATIN1);
    testing.assertEqual(len($values), 2);
    testing.assertEqual($values[0], "a");
    testing.assertEqual($values[1], "b");
}

func testSplitValuesOnAnEmptyBuffer() {
    testing.assertEqual(len(splitValues(binary.make(0), TEXT_LATIN1)), 0);
}

func testTerminatorIndex() {
    def data as bytes init bytesOf([0x41, 0x00, 0x42]);
    testing.assertEqual(terminatorIndex($data, 0, 1), 1);
    testing.assertEqual(terminatorIndex($data, 2, 1), -1);
    def wide as bytes init bytesOf([0x00, 0x41, 0x00, 0x00]);
    testing.assertEqual(terminatorIndex($wide, 0, 2), 2);
}

func testTrimField() {
    testing.assertEqual(trimField("title" + convert.fromCodepoint(0) + "junk"), "title");
    testing.assertEqual(trimField("  padded  "), "padded");
    testing.assertEqual(trimField(""), "");
}

func testWithoutNuls() {
    def nul as string init convert.fromCodepoint(0);
    testing.assertEqual(withoutNuls("plain"), "plain");
    testing.assertEqual(withoutNuls("a" + $nul + "b"), "ab");
    testing.assertEqual(withoutNuls($nul), "");
    testing.assertEqual(withoutNuls(""), "");
}

func testTextEncodingOfFallsBackToLatin1() {
    testing.assertEqual(textEncodingOf(TEXT_LATIN1), TEXT_LATIN1);
    testing.assertEqual(textEncodingOf(TEXT_UTF8), TEXT_UTF8);
    # one flipped bit in a file is enough to produce a byte that names nothing
    testing.assertEqual(textEncodingOf(137), TEXT_LATIN1);
    testing.assertEqual(textEncodingOf(255), TEXT_LATIN1);
    testing.assertEqual(textEncodingOf(-1), TEXT_LATIN1);
}

func testIsPrintableAscii() {
    testing.assertTrue(isPrintableAscii("image/png"));
    testing.assertTrue(isPrintableAscii(" ~"));
    testing.assertTrue(isPrintableAscii(""));
    testing.assertFalse(isPrintableAscii("café"));
    testing.assertFalse(isPrintableAscii("a\0b"));
    testing.assertFalse(isPrintableAscii("a\nb"));
    testing.assertFalse(isPrintableAscii("\u007f"));
}
