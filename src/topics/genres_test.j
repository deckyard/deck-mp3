# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the genres topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

func testGenreTableIsComplete() {
    testing.assertEqual(GENRE_COUNT, 192);
    testing.assertEqual(len(GENRES), GENRE_COUNT);
    testing.assertEqual(GENRE_NONE, 255);
}

func testGenreTableHasNoBlanksOrDuplicates() {
    def seen as map of string to int init {};
    for (def name in GENRES) {
        testing.assertNotEqual($name, "");
        testing.assertFalse(maps.has($seen, $name));
        $seen[$name] = 1;
    }
    testing.assertEqual(len($seen), GENRE_COUNT);
}

func testGenreNameAtEveryBoundary() {
    # the original ID3v1 list
    testing.assertEqual(genreName(0), "Blues");
    testing.assertEqual(genreName(17), "Rock");
    testing.assertEqual(genreName(79), "Hard Rock");
    # the Winamp 1.x extensions
    testing.assertEqual(genreName(80), "Folk");
    testing.assertEqual(genreName(125), "Dance Hall");
    # the Winamp 5.0 extensions
    testing.assertEqual(genreName(126), "Goa");
    testing.assertEqual(genreName(147), "Synthpop");
    # the Winamp 5.6 extensions
    testing.assertEqual(genreName(148), "Abstract");
    testing.assertEqual(genreName(191), "Psybient");
}

func testGenreNameOutsideTheTable() {
    testing.assertEqual(genreName(-1), "");
    testing.assertEqual(genreName(192), "");
    testing.assertEqual(genreName(GENRE_NONE), "");
}

func testGenreNumberIgnoresCaseAndSpace() {
    testing.assertEqual(genreNumber("Rock"), 17);
    testing.assertEqual(genreNumber("rock"), 17);
    testing.assertEqual(genreNumber("  ROCK "), 17);
    testing.assertEqual(genreNumber("Drum & Bass"), 127);
}

func testGenreNumberRejectsWhatIsNotThere() {
    testing.assertEqual(genreNumber("Chiptune"), -1);
    testing.assertEqual(genreNumber(""), -1);
    testing.assertEqual(genreNumber("   "), -1);
}

func testGenreNumberInvertsGenreName() {
    for (def i as int init 0; $i < GENRE_COUNT; $i = $i + 1) {
        testing.assertEqual(genreNumber(genreName($i)), $i);
    }
}

func testResolveGenreReadsEveryTconSpelling() {
    testing.assertEqual(resolveGenre("Rock"), "Rock");
    testing.assertEqual(resolveGenre("17"), "Rock");
    testing.assertEqual(resolveGenre("(17)"), "Rock");
    testing.assertEqual(resolveGenre("(17)Hard Rock"), "Hard Rock");
    testing.assertEqual(resolveGenre(" (17) "), "Rock");
}

func testResolveGenreKnowsTheTwoEscapes() {
    testing.assertEqual(resolveGenre("(RX)"), "Remix");
    testing.assertEqual(resolveGenre("(CR)"), "Cover");
    testing.assertEqual(resolveGenre("(RX)Club Mix"), "Club Mix");
}

func testResolveGenreLeavesWhatItCannotResolve() {
    testing.assertEqual(resolveGenre("Chiptune"), "Chiptune");
    testing.assertEqual(resolveGenre("(999)"), "(999)");
    testing.assertEqual(resolveGenre("999"), "999");
    testing.assertEqual(resolveGenre(""), "");
    testing.assertEqual(resolveGenre("   "), "");
    testing.assertEqual(resolveGenre("(unclosed"), "(unclosed");
}

func testResolveGenrePrefersATextualGenreOverANumericOne() {
    # a name that happens to be in the table wins over a reading as digits
    testing.assertEqual(resolveGenre("Goa"), "Goa");
}

func testIsAllDigits() {
    testing.assertTrue(isAllDigits("0"));
    testing.assertTrue(isAllDigits("1976"));
    testing.assertFalse(isAllDigits(""));
    testing.assertFalse(isAllDigits("19a"));
    testing.assertFalse(isAllDigits(" 19"));
}

func testRefinementName() {
    testing.assertEqual(refinementName("17"), "Rock");
    testing.assertEqual(refinementName("RX"), "Remix");
    testing.assertEqual(refinementName("CR"), "Cover");
    testing.assertEqual(refinementName("abc"), "");
    testing.assertEqual(refinementName("999"), "");
}
