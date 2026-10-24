# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the tag topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

# A tag with every scalar field set, for the round-trip tests.
func fullTag() {
    def tag as Tag init emptyTag();
    $tag.title = "Ich war müde leer nicht mehr da";
    $tag.artist = "Maike Vandervaart";
    $tag.album = "Ich war müde leer nicht mehr da";
    $tag.albumArtist = "Vandervaart";
    $tag.composer = "Maike Vandervaart";
    $tag.genre = "Ambient";
    $tag.year = "2025";
    $tag.date = "2025";
    $tag.track = 1;
    $tag.trackTotal = 3;
    $tag.disc = 1;
    $tag.discTotal = 2;
    $tag.bpm = 120;
    $tag.publisher = "Example Records";
    $tag.encodedBy = "deck-mp3";
    $tag.copyright = "2025";
    return $tag;
}

# Render a tag to ID3v2 and read it straight back.
func roundTrip(tag as Tag, major as int) {
    def raw as bytes init renderId3v2(framesFromTag($tag, $major), $major, 0);
    return tagFromId3v2(readId3v2($raw));
}

func testEmptyTagIsEmpty() {
    def tag as Tag init emptyTag();
    testing.assertEqual($tag.title, "");
    testing.assertEqual($tag.track, 0);
    testing.assertEqual(len($tag.comments), 0);
    testing.assertEqual(len($tag.pictures), 0);
    testing.assertEqual(len($tag.extra), 0);
}

func testPictureTypeTable() {
    testing.assertEqual(len(PICTURE_TYPES), 21);
    testing.assertEqual(PICTURE_FRONT_COVER, 3);
    testing.assertEqual(pictureTypeName(0), "Other");
    testing.assertEqual(pictureTypeName(PICTURE_FRONT_COVER), "Cover (front)");
    testing.assertEqual(pictureTypeName(17), "A bright coloured fish");
    testing.assertEqual(pictureTypeName(20), "Publisher logotype");
    testing.assertEqual(pictureTypeName(21), "");
    testing.assertEqual(pictureTypeName(-1), "");
}

func testCanonicalFrameIdMapsId3v22Forward() {
    testing.assertEqual(canonicalFrameId("TT2"), "TIT2");
    testing.assertEqual(canonicalFrameId("PIC"), "APIC");
    testing.assertEqual(canonicalFrameId("TIT2"), "TIT2");
    testing.assertEqual(canonicalFrameId("ZZZZ"), "ZZZZ");
}

func testTheTwoFrameIdTablesAreExactInverses() {
    def shortIds as list of string init maps.keys(V22_TO_V23);
    testing.assertEqual(len($shortIds), len(maps.keys(V23_TO_V22)));
    for (def short in $shortIds) {
        def long as string init V22_TO_V23[$short];
        testing.assertEqual(len($short), 3);
        testing.assertEqual(len($long), 4);
        testing.assertTrue(maps.has(V23_TO_V22, $long));
        testing.assertEqual(V23_TO_V22[$long], $short);
    }
}

func testVersionFrameId() {
    testing.assertEqual(versionFrameId("TIT2", 4), "TIT2");
    testing.assertEqual(versionFrameId("TIT2", 3), "TIT2");
    testing.assertEqual(versionFrameId("TIT2", 2), "TT2");
    testing.assertThrows("versionFrameIdUnmappable", ERROR_KIND);
}

func versionFrameIdUnmappable() {
    versionFrameId("TDRC", 2);
}

func testEveryScalarFieldSurvivesAnId3v24RoundTrip() {
    def back as Tag init roundTrip(fullTag(), 4);
    testing.assertEqual($back.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($back.artist, "Maike Vandervaart");
    testing.assertEqual($back.album, "Ich war müde leer nicht mehr da");
    testing.assertEqual($back.albumArtist, "Vandervaart");
    testing.assertEqual($back.composer, "Maike Vandervaart");
    testing.assertEqual($back.genre, "Ambient");
    testing.assertEqual($back.track, 1);
    testing.assertEqual($back.trackTotal, 3);
    testing.assertEqual($back.disc, 1);
    testing.assertEqual($back.discTotal, 2);
    testing.assertEqual($back.bpm, 120);
    testing.assertEqual($back.publisher, "Example Records");
    testing.assertEqual($back.encodedBy, "deck-mp3");
    testing.assertEqual($back.copyright, "2025");
    # ID3v2.4 keeps the full timestamp and derives the year from it
    testing.assertEqual($back.date, "2025");
    testing.assertEqual($back.year, "2025");
}

func testId3v23KeepsTheYearAndDropsTheRestOfTheDate() {
    def back as Tag init roundTrip(fullTag(), 3);
    testing.assertEqual($back.year, "2025");
    testing.assertEqual($back.date, "2025");
    testing.assertEqual($back.title, "Ich war müde leer nicht mehr da");
}

func testId3v22RoundTrip() {
    def tag as Tag init fullTag();
    # ID3v2.2 has no frame for a full timestamp, so the year carries it
    def back as Tag init roundTrip($tag, 2);
    testing.assertEqual($back.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($back.artist, "Maike Vandervaart");
    testing.assertEqual($back.track, 1);
    testing.assertEqual($back.trackTotal, 3);
    testing.assertEqual($back.year, "2025");
}

func testOnlyTheFieldsThatAreSetProduceFrames() {
    def tag as Tag init emptyTag();
    testing.assertEqual(len(framesFromTag($tag, 4)), 0);
    $tag.title = "x";
    testing.assertEqual(len(framesFromTag($tag, 4)), 1);
}

func testFramesFromTagRejectsAVersionThatDoesNotExist() {
    testing.assertThrows("framesForVersionFive", ERROR_KIND);
}

func framesForVersionFive() {
    framesFromTag(emptyTag(), 5);
}

func testATrackWithNoTotalIsWrittenBare() {
    testing.assertEqual(pairText(4, 6), "4/6");
    testing.assertEqual(pairText(4, 0), "4");
    testing.assertEqual(pairText(0, 6), "");
    testing.assertEqual(pairText(-1, 6), "");
    testing.assertEqual(numberText(120), "120");
    testing.assertEqual(numberText(0), "");
}

func testSplitPair() {
    testing.assertEqual(splitPair("4/6").first, 4);
    testing.assertEqual(splitPair("4/6").second, 6);
    testing.assertEqual(splitPair("4").first, 4);
    testing.assertEqual(splitPair("4").second, 0);
    testing.assertEqual(splitPair("").first, 0);
    testing.assertEqual(splitPair("/6").first, 0);
    testing.assertEqual(splitPair("/6").second, 6);
}

func testYearOf() {
    testing.assertEqual(yearOf("2025"), "2025");
    testing.assertEqual(yearOf("2025"), "2025");
    testing.assertEqual(yearOf("19"), "");
    testing.assertEqual(yearOf("abcd-01"), "");
}

func testCommentsRoundTrip() {
    def tag as Tag init emptyTag();
    def comments as list of Comment init [];
    $comments[] = Comment{language: "eng", description: "", text: "plain"};
    $comments[] = Comment{language: "deu", description: "iTunNORM", text: "0000"};
    $tag.comments = $comments;

    def back as Tag init roundTrip($tag, 4);
    testing.assertEqual(len($back.comments), 2);
    testing.assertEqual($back.comments[0].language, "eng");
    testing.assertEqual($back.comments[0].description, "");
    testing.assertEqual($back.comments[0].text, "plain");
    testing.assertEqual($back.comments[1].language, "deu");
    testing.assertEqual($back.comments[1].description, "iTunNORM");
    testing.assertEqual(commentText($back), "plain");
}

func testCommentTextPrefersTheUndescribedComment() {
    def tag as Tag init emptyTag();
    def comments as list of Comment init [];
    $comments[] = Comment{language: "eng", description: "iTunNORM", text: "0000"};
    $comments[] = Comment{language: "eng", description: "", text: "the one"};
    $tag.comments = $comments;
    testing.assertEqual(commentText($tag), "the one");

    def onlyKeyed as Tag init emptyTag();
    def keyed as list of Comment init [];
    $keyed[] = Comment{language: "eng", description: "k", text: "fallback"};
    $onlyKeyed.comments = $keyed;
    testing.assertEqual(commentText($onlyKeyed), "fallback");
    testing.assertEqual(commentText(emptyTag()), "");
}

func testAnUnusableLanguageCodeBecomesEng() {
    testing.assertEqual(languageCode("eng"), "eng");
    testing.assertEqual(languageCode("ENG"), "eng");
    testing.assertEqual(languageCode(""), "eng");
    testing.assertEqual(languageCode("en"), "eng");
    testing.assertEqual(languageCode("日本語"), "eng");
}

func testLyricsRoundTrip() {
    def tag as Tag init emptyTag();
    $tag.lyrics = "line one\nline two";
    testing.assertEqual(roundTrip($tag, 4).lyrics, "line one\nline two");
}

func testPicturesRoundTripOnId3v23() {
    def tag as Tag init emptyTag();
    def pictures as list of Picture init [];
    $pictures[] = Picture{
        mimeType: "image/png",
        kind: PICTURE_FRONT_COVER,
        description: "front",
        data: binary.make(16, 0x89)
    };
    $pictures[] = Picture{
        mimeType: "image/jpeg",
        kind: 4,
        description: "",
        data: binary.make(8, 0xff)
    };
    $tag.pictures = $pictures;

    def back as Tag init roundTrip($tag, 3);
    testing.assertEqual(len($back.pictures), 2);
    testing.assertEqual($back.pictures[0].mimeType, "image/png");
    testing.assertEqual($back.pictures[0].kind, PICTURE_FRONT_COVER);
    testing.assertEqual($back.pictures[0].description, "front");
    testing.assertEqual(len($back.pictures[0].data), 16);
    testing.assertEqual($back.pictures[1].kind, 4);
    testing.assertEqual(len($back.pictures[1].data), 8);
}

func testPicturesRoundTripThroughId3v22ThreeLetterFormats() {
    def tag as Tag init emptyTag();
    def pictures as list of Picture init [];
    $pictures[] = Picture{
        mimeType: "image/png",
        kind: PICTURE_FRONT_COVER,
        description: "",
        data: binary.make(4, 1)
    };
    $tag.pictures = $pictures;
    def back as Tag init roundTrip($tag, 2);
    testing.assertEqual(len($back.pictures), 1);
    testing.assertEqual($back.pictures[0].mimeType, "image/png");
    testing.assertEqual($back.pictures[0].kind, PICTURE_FRONT_COVER);
}

func testMediaTypeAndImageFormatMapBothWays() {
    testing.assertEqual(mediaTypeOf("JPG"), "image/jpeg");
    testing.assertEqual(mediaTypeOf("jpeg"), "image/jpeg");
    testing.assertEqual(mediaTypeOf("PNG"), "image/png");
    testing.assertEqual(mediaTypeOf("GIF"), "image/gif");
    testing.assertEqual(mediaTypeOf(""), "");
    testing.assertEqual(imageFormatOf("image/png"), "PNG");
    testing.assertEqual(imageFormatOf("image/gif"), "GIF");
    testing.assertEqual(imageFormatOf("image/jpeg"), "JPG");
    testing.assertEqual(imageFormatOf("application/octet-stream"), "JPG");
    testing.assertEqual(mediaTypeOrDefault(""), "image/jpeg");
    testing.assertEqual(mediaTypeOrDefault(" image/png "), "image/png");
}

func testAPictureTypeOutsideTheTableIsWrittenAsOther() {
    testing.assertEqual(pictureKind(3), 3);
    testing.assertEqual(pictureKind(99), 0);
    testing.assertEqual(pictureKind(-1), 0);
}

func testCoverArtPrefersTheFrontCover() {
    def tag as Tag init emptyTag();
    def pictures as list of Picture init [];
    $pictures[] = Picture{
        mimeType: "image/jpeg",
        kind: 4,
        description: "back",
        data: binary.make(2, 1)
    };
    $pictures[] = Picture{
        mimeType: "image/png",
        kind: PICTURE_FRONT_COVER,
        description: "front",
        data: binary.make(3, 2)
    };
    $tag.pictures = $pictures;
    testing.assertEqual(coverArt($tag).description, "front");

    def noFront as Tag init emptyTag();
    def others as list of Picture init [];
    $others[] = Picture{
        mimeType: "image/jpeg",
        kind: 4,
        description: "back",
        data: binary.make(2, 1)
    };
    $noFront.pictures = $others;
    testing.assertEqual(coverArt($noFront).description, "back");
    testing.assertEqual(len(coverArt(emptyTag()).data), 0);
}

func testUserDefinedTextRoundTrips() {
    def tag as Tag init emptyTag();
    def extra as map of string to string init {};
    $extra["replaygain_track_gain"] = "-6.50 dB";
    $extra["MusicBrainz Album Id"] = "abc-123";
    $tag.extra = $extra;

    def back as Tag init roundTrip($tag, 4);
    testing.assertEqual(len($back.extra), 2);
    testing.assertEqual($back.extra["replaygain_track_gain"], "-6.50 dB");
    testing.assertEqual($back.extra["MusicBrainz Album Id"], "abc-123");
}

func testTheFirstOfADuplicatedFrameWins() {
    def frames as list of Id3v2Frame init [];
    $frames[] = Id3v2Frame{id: "TIT2", flags: 0, data: textBody(TEXT_LATIN1, "first")};
    $frames[] = Id3v2Frame{id: "TIT2", flags: 0, data: textBody(TEXT_LATIN1, "second")};
    def tag as Tag init tagFromId3v2(readId3v2(renderId3v2($frames, 4, 0)));
    testing.assertEqual($tag.title, "first");
}

func testANumericGenreFrameIsResolved() {
    def frames as list of Id3v2Frame init [];
    $frames[] = Id3v2Frame{id: "TCON", flags: 0, data: textBody(TEXT_LATIN1, "(17)")};
    testing.assertEqual(tagFromId3v2(readId3v2(renderId3v2($frames, 4, 0))).genre, "Rock");
}

func testTagFromAnAbsentId3v2IsEmpty() {
    def absent as Id3v2;
    testing.assertEqual(tagFromId3v2($absent).title, "");
}

func testTagFromId3v1() {
    def v1 as Id3v1 init emptyId3v1();
    $v1.present = true;
    $v1.title = "Ich war müde leer nicht mehr da";
    $v1.artist = "Vandervaart";
    $v1.album = "Ich war müde leer nicht mehr da";
    $v1.year = "2025";
    $v1.comment = "hello";
    $v1.track = 1;
    $v1.genre = 26;

    def tag as Tag init tagFromId3v1($v1);
    testing.assertEqual($tag.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($tag.artist, "Vandervaart");
    testing.assertEqual($tag.year, "2025");
    testing.assertEqual($tag.date, "2025");
    testing.assertEqual($tag.track, 1);
    testing.assertEqual($tag.genre, "Ambient");
    testing.assertEqual(commentText($tag), "hello");

    def absent as Id3v1 init emptyId3v1();
    testing.assertEqual(tagFromId3v1($absent).title, "");
}

func testId3v1FromTag() {
    def v1 as Id3v1 init id3v1FromTag(fullTag());
    testing.assertTrue($v1.present);
    testing.assertEqual($v1.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($v1.year, "2025");
    testing.assertEqual($v1.track, 1);
    testing.assertTrue($v1.version11);
    testing.assertEqual($v1.genre, 26);
}

func testId3v1FromTagWithAGenreTheTableDoesNotKnow() {
    def tag as Tag init emptyTag();
    $tag.genre = "Chiptune";
    testing.assertEqual(id3v1FromTag($tag).genre, GENRE_NONE);
}

func testId3v1FromTagDropsATrackNumberOverAByte() {
    def tag as Tag init emptyTag();
    $tag.track = 500;
    def v1 as Id3v1 init id3v1FromTag($tag);
    testing.assertEqual($v1.track, 0);
    testing.assertFalse($v1.version11);
}

func testMergeTagsFillsGapsWithoutOverwriting() {
    def primary as Tag init emptyTag();
    $primary.title = "from v2";
    $primary.track = 3;

    def fallback as Tag init emptyTag();
    $fallback.title = "from v1";
    $fallback.artist = "from v1";
    $fallback.track = 9;
    $fallback.trackTotal = 12;
    $fallback.disc = 1;
    $fallback.discTotal = 2;
    $fallback.bpm = 90;
    $fallback.genre = "Rock";
    $fallback.year = "2025";
    $fallback.date = "2025";
    $fallback.album = "a";
    $fallback.albumArtist = "b";
    $fallback.composer = "c";
    $fallback.publisher = "d";
    $fallback.encodedBy = "e";
    $fallback.copyright = "f";
    $fallback.lyrics = "g";
    def comments as list of Comment init [];
    $comments[] = Comment{language: "eng", description: "", text: "from v1"};
    $fallback.comments = $comments;
    def pictures as list of Picture init [];
    $pictures[] = Picture{mimeType: "image/png", kind: 3, description: "", data: binary.make(2, 1)};
    $fallback.pictures = $pictures;

    def merged as Tag init mergeTags($primary, $fallback);
    testing.assertEqual($merged.title, "from v2");
    testing.assertEqual($merged.track, 3);
    testing.assertEqual($merged.artist, "from v1");
    testing.assertEqual($merged.trackTotal, 12);
    testing.assertEqual($merged.disc, 1);
    testing.assertEqual($merged.discTotal, 2);
    testing.assertEqual($merged.bpm, 90);
    testing.assertEqual($merged.genre, "Rock");
    testing.assertEqual($merged.album, "a");
    testing.assertEqual($merged.lyrics, "g");
    testing.assertEqual(len($merged.comments), 1);
    testing.assertEqual(len($merged.pictures), 1);
    # neither argument changed
    testing.assertEqual($primary.artist, "");
    testing.assertEqual($fallback.title, "from v1");
}

func testFirstSet() {
    testing.assertEqual(firstSet("a", "b"), "a");
    testing.assertEqual(firstSet("", "b"), "b");
    testing.assertEqual(firstSet("", ""), "");
}

func testDateFrameIdAndText() {
    testing.assertEqual(dateFrameId(4), "TDRC");
    testing.assertEqual(dateFrameId(3), "TYER");
    testing.assertEqual(dateFrameId(2), "TYER");
    def tag as Tag init fullTag();
    testing.assertEqual(dateText($tag, 4), "2025");
    testing.assertEqual(dateText($tag, 3), "2025");
    def noDate as Tag init emptyTag();
    $noDate.year = "2001";
    testing.assertEqual(dateText($noDate, 4), "2001");
}

func testCommentOfOnATruncatedFrame() {
    def short as Id3v2Frame init Id3v2Frame{id: "COMM", flags: 0, data: binary.make(2, 0)};
    testing.assertEqual(commentOf($short).text, "");
}

func testPictureOfOnATruncatedFrame() {
    def short as Id3v2Frame init Id3v2Frame{id: "APIC", flags: 0, data: binary.make(1, 0)};
    testing.assertEqual(len(pictureOf($short, 3).data), 0);
    def shortV22 as Id3v2Frame init Id3v2Frame{id: "PIC", flags: 0, data: binary.make(3, 0)};
    testing.assertEqual(len(pictureOf($shortV22, 2).data), 0);
}

func testTextWideEnoughToNeedUtf8SurvivesId3v24() {
    def tag as Tag init emptyTag();
    $tag.title = "日本語のタイトル";
    $tag.artist = "Grüße";
    def back as Tag init roundTrip($tag, 4);
    testing.assertEqual($back.title, "日本語のタイトル");
    testing.assertEqual($back.artist, "Grüße");
}

func testTextWideEnoughToNeedUtf16SurvivesId3v23() {
    def tag as Tag init emptyTag();
    $tag.title = "日本語のタイトル";
    testing.assertEqual(roundTrip($tag, 3).title, "日本語のタイトル");
}

func testTextFrameBuildsTheVersionsOwnSpelling() {
    def v4 as Id3v2Frame init textFrame("TIT2", "Ich war müde leer nicht mehr da", 4);
    testing.assertEqual($v4.id, "TIT2");
    testing.assertEqual($v4.data[0], TEXT_LATIN1);
    testing.assertEqual(frameText($v4), "Ich war müde leer nicht mehr da");

    def v2 as Id3v2Frame init textFrame("TIT2", "Ich war müde leer nicht mehr da", 2);
    testing.assertEqual($v2.id, "TT2");

    def wide as Id3v2Frame init textFrame("TIT2", "日本語", 4);
    testing.assertEqual($wide.data[0], TEXT_UTF8);
    testing.assertEqual(frameText($wide), "日本語");
}

func testANulInAValueCannotSplitTheFrameItIsWrittenTo() {
    def nul as string init convert.fromCodepoint(0);
    def tag as Tag init emptyTag();
    $tag.title = "before" + $nul + "after";
    $tag.artist = "a" + $nul + "b";

    # an unstripped NUL would read back as two values on ID3v2.4
    def back as Tag init roundTrip($tag, 4);
    testing.assertEqual($back.title, "beforeafter");
    testing.assertEqual($back.artist, "ab");
}

func testANulInADescriptionCannotSwallowItsValue() {
    def nul as string init convert.fromCodepoint(0);
    def tag as Tag init emptyTag();
    def extra as map of string to string init {};
    $extra["key" + $nul + "more"] = "value";
    $tag.extra = $extra;

    def comments as list of Comment init [];
    $comments[] = Comment{language: "eng", description: "d" + $nul + "e", text: "the text"};
    $tag.comments = $comments;

    def pictures as list of Picture init [];
    $pictures[] = Picture{
        mimeType: "image/png",
        kind: 3,
        description: "p" + $nul + "q",
        data: binary.make(4, 1)
    };
    $tag.pictures = $pictures;

    def back as Tag init roundTrip($tag, 4);
    testing.assertEqual($back.extra["keymore"], "value");
    testing.assertEqual($back.comments[0].description, "de");
    testing.assertEqual($back.comments[0].text, "the text");
    testing.assertEqual($back.pictures[0].description, "pq");
    testing.assertEqual(len($back.pictures[0].data), 4);
}

func testTextFrameRejectsAVersionThatDoesNotExist() {
    testing.assertThrows("textFrameForVersionOne", ERROR_KIND);
    testing.assertThrows("textFrameForVersionFive", ERROR_KIND);
}

func textFrameForVersionOne() {
    textFrame("TIT2", "x", 1);
}

func textFrameForVersionFive() {
    textFrame("TIT2", "x", 5);
}

func testAMediaTypeOutsidePrintableAsciiIsWrittenAsTheDefault() {
    testing.assertEqual(mediaTypeOrDefault("image/péng"), "image/jpeg");
    testing.assertEqual(mediaTypeOrDefault("图像/png"), "image/jpeg");
    testing.assertEqual(mediaTypeOrDefault("image/\0png"), "image/jpeg");
    testing.assertEqual(mediaTypeOrDefault("image/\tpng"), "image/jpeg");
    testing.assertEqual(mediaTypeOrDefault("image/webp"), "image/webp");
}

func testABadMediaTypeCannotBreakThePictureItIsWrittenTo() {
    for (def mime in ["image/\0png", "图像/png"]) {
        def tag as Tag init emptyTag();
        def pictures as list of Picture init [];
        $pictures[] = Picture{
            mimeType: $mime,
            kind: PICTURE_FRONT_COVER,
            description: "front",
            data: binary.make(16, 0x89)
        };
        $tag.pictures = $pictures;
        for (def major in [3, 4]) {
            def back as Tag init roundTrip($tag, $major);
            testing.assertEqual(len($back.pictures), 1);
            testing.assertEqual($back.pictures[0].mimeType, "image/jpeg");
            testing.assertEqual($back.pictures[0].kind, PICTURE_FRONT_COVER);
            testing.assertEqual($back.pictures[0].description, "front");
            testing.assertEqual($back.pictures[0].data, binary.make(16, 0x89));
        }
    }
}
