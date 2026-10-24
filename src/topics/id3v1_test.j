# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the id3v1 topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

# A file whose last 128 bytes are `block`, with `lead` bytes of audio first.
func fileWithTrailer(lead as int, block as bytes) {
    def parts as list of bytes init [];
    $parts[] = silentStream($lead);
    $parts[] = $block;
    return binary.join($parts);
}

func testTagSize() {
    testing.assertEqual(ID3V1_SIZE, 128);
}

func testRenderId3v1IsAlwaysOneBlock() {
    def tag as Id3v1 init emptyId3v1();
    testing.assertEqual(len(renderId3v1($tag)), ID3V1_SIZE);
    $tag.title = strings.repeat("x", 100);
    $tag.track = 7;
    testing.assertEqual(len(renderId3v1($tag)), ID3V1_SIZE);
}

func testRenderId3v1OpensWithTag() {
    def block as bytes init renderId3v1(emptyId3v1());
    testing.assertTrue(magicAt($block, 0, "TAG"));
    testing.assertEqual($block[127], GENRE_NONE);
}

func testReadId3v1OnAFileWithoutOne() {
    def tag as Id3v1 init readId3v1(silentStream(2));
    testing.assertFalse($tag.present);
    testing.assertEqual($tag.title, "");
    testing.assertEqual($tag.genre, GENRE_NONE);
    testing.assertEqual($tag.track, 0);
}

func testReadId3v1OnABufferShorterThanATag() {
    testing.assertFalse(readId3v1(binary.make(10, 0)).present);
    testing.assertFalse(readId3v1(binary.make(0)).present);
}

func testId3v1RoundTrip() {
    def written as Id3v1 init emptyId3v1();
    $written.title = "Ich war müde leer nicht mehr da";
    $written.artist = "Maike Vandervaart";
    $written.album = "Ich war müde leer nicht mehr da";
    $written.year = "2025";
    $written.comment = "a comment";
    $written.track = 1;
    $written.genre = 26;

    def data as bytes init fileWithTrailer(2, renderId3v1($written));
    def read as Id3v1 init readId3v1($data);
    testing.assertTrue($read.present);
    # title and album are 31 characters; ID3v1 keeps the first 30 bytes of each
    testing.assertEqual($read.title, "Ich war müde leer nicht mehr d");
    testing.assertEqual($read.artist, "Maike Vandervaart");
    testing.assertEqual($read.album, "Ich war müde leer nicht mehr d");
    testing.assertEqual($read.year, "2025");
    testing.assertEqual($read.comment, "a comment");
    testing.assertEqual($read.track, 1);
    testing.assertEqual($read.genre, 26);
    testing.assertTrue($read.version11);
}

func testATrackNumberMakesItVersion11() {
    def tag as Id3v1 init emptyId3v1();
    $tag.comment = "0123456789012345678901234567";
    $tag.track = 12;
    def block as bytes init renderId3v1($tag);
    # byte 125 of the tag is the separator, 126 the track
    testing.assertEqual($block[125], 0);
    testing.assertEqual($block[126], 12);

    def read as Id3v1 init readId3v1(fileWithTrailer(1, $block));
    testing.assertTrue($read.version11);
    testing.assertEqual($read.track, 12);
    testing.assertEqual($read.comment, "0123456789012345678901234567");
}

func testNoTrackNumberLeavesTheWholeCommentField() {
    def tag as Id3v1 init emptyId3v1();
    $tag.comment = "012345678901234567890123456789";
    $tag.track = 0;
    def read as Id3v1 init readId3v1(fileWithTrailer(1, renderId3v1($tag)));
    testing.assertFalse($read.version11);
    testing.assertEqual($read.track, 0);
    testing.assertEqual($read.comment, "012345678901234567890123456789");
}

func testFieldsAreTruncatedToTheirWidth() {
    def tag as Id3v1 init emptyId3v1();
    $tag.title = strings.repeat("a", 40);
    $tag.year = "20250";
    def read as Id3v1 init readId3v1(fileWithTrailer(1, renderId3v1($tag)));
    testing.assertEqual(len($read.title), 30);
    testing.assertEqual($read.year, "2025");
}

func testTextOutsideLatin1IsTransliterated() {
    def tag as Id3v1 init emptyId3v1();
    $tag.title = "日本語";
    $tag.artist = "Grüße";
    def read as Id3v1 init readId3v1(fileWithTrailer(1, renderId3v1($tag)));
    testing.assertEqual($read.title, "???");
    # ISO-8859-1 spells these, so they survive untouched
    testing.assertEqual($read.artist, "Grüße");
}

func testAGenreOutsideTheTableBecomesNoGenre() {
    def tag as Id3v1 init emptyId3v1();
    $tag.genre = 250;
    testing.assertEqual(renderId3v1($tag)[127], GENRE_NONE);
    $tag.genre = -1;
    testing.assertEqual(renderId3v1($tag)[127], GENRE_NONE);
    $tag.genre = 191;
    testing.assertEqual(renderId3v1($tag)[127], 191);
}

func testATrackNumberOutsideAByteIsDropped() {
    def tag as Id3v1 init emptyId3v1();
    $tag.comment = "comment";
    $tag.track = 300;
    def read as Id3v1 init readId3v1(fileWithTrailer(1, renderId3v1($tag)));
    testing.assertEqual($read.track, 0);
    testing.assertEqual($read.comment, "comment");
}

func testId3v1Offset() {
    def data as bytes init fileWithTrailer(1, renderId3v1(emptyId3v1()));
    testing.assertEqual(id3v1Offset($data), len($data) - ID3V1_SIZE);
    testing.assertEqual(id3v1Offset(silentStream(1)), -1);
    testing.assertEqual(id3v1Offset(binary.make(4, 0)), -1);
}

func testFixedBytesPadsWithNuls() {
    def field as bytes init fixedBytes("ab", 5);
    testing.assertEqual(len($field), 5);
    testing.assertEqual($field[2], 0);
    testing.assertEqual($field[4], 0);
    testing.assertEqual(len(fixedBytes("abcdef", 3)), 3);
    testing.assertEqual(len(fixedBytes("", 0)), 0);
}

func testToLatin1LossyDropsNulsAndSubstitutesTheRest() {
    testing.assertEqual(toLatin1Lossy("a" + convert.fromCodepoint(0) + "b"), "ab");
    testing.assertEqual(toLatin1Lossy("日a"), "?a");
    testing.assertEqual(toLatin1Lossy("ü"), "ü");
}

func testGenreByte() {
    testing.assertEqual(genreByte(0), 0);
    testing.assertEqual(genreByte(191), 191);
    testing.assertEqual(genreByte(192), GENRE_NONE);
    testing.assertEqual(genreByte(-3), GENRE_NONE);
}
