# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the m3u topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

func testNewPlaylist() {
    def pl as Playlist init newPlaylist();
    testing.assertEqual($pl.title, "");
    testing.assertTrue($pl.extended);
    testing.assertEqual(len($pl.entries), 0);
    testing.assertEqual(DURATION_UNKNOWN, -1);
}

func testPlaylistEntryAndAddEntry() {
    def entry as PlaylistEntry init playlistEntry("a.mp3", "A", 61);
    testing.assertEqual($entry.path, "a.mp3");
    testing.assertEqual($entry.title, "A");
    testing.assertEqual($entry.duration, 61);
    testing.assertEqual($entry.group, "");

    def pl as Playlist init newPlaylist();
    def grown as Playlist init addEntry($pl, $entry);
    testing.assertEqual(len($grown.entries), 1);
    # the argument is untouched
    testing.assertEqual(len($pl.entries), 0);
}

func testBuildAndParseRoundTrip() {
    def pl as Playlist init newPlaylist();
    $pl.title = "Evening";
    $pl = addEntry($pl, playlistEntry("one.mp3", "A - one", 61));
    $pl = addEntry($pl, playlistEntry("sub/two.mp3", "B - two", 125));

    def text as string init buildPlaylist($pl);
    def back as Playlist init parsePlaylist($text);
    testing.assertTrue($back.extended);
    testing.assertEqual($back.title, "Evening");
    testing.assertEqual(len($back.entries), 2);
    testing.assertEqual($back.entries[0].path, "one.mp3");
    testing.assertEqual($back.entries[0].title, "A - one");
    testing.assertEqual($back.entries[0].duration, 61);
    testing.assertEqual($back.entries[1].path, "sub/two.mp3");
    testing.assertEqual($back.entries[1].duration, 125);
    testing.assertEqual(playlistDuration($back), 186);
}

func testBuildWritesTheExpectedLines() {
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("one.mp3", "A", 61));
    def text as string init buildPlaylist($pl);
    def lines as list of string init strings.split($text, "\n");
    testing.assertEqual($lines[0], "#EXTM3U");
    testing.assertEqual($lines[1], "#EXTINF:61,A");
    testing.assertEqual($lines[2], "one.mp3");
    testing.assertEqual($lines[3], "");
}

func testAPlainPlaylistIsPathsAndNothingElse() {
    def pl as Playlist init newPlaylist();
    $pl.extended = false;
    $pl.title = "ignored";
    $pl = addEntry($pl, playlistEntry("one.mp3", "A", 61));
    $pl = addEntry($pl, playlistEntry("two.mp3", "B", 62));
    testing.assertEqual(buildPlaylist($pl), "one.mp3\ntwo.mp3\n");
}

func testAnEmptyPlaylistBuildsToNothing() {
    def plain as Playlist init newPlaylist();
    $plain.extended = false;
    testing.assertEqual(buildPlaylist($plain), "");
}

func testParseAPlainPlaylist() {
    def pl as Playlist init parsePlaylist("one.mp3\ntwo.mp3\n");
    testing.assertFalse($pl.extended);
    testing.assertEqual(len($pl.entries), 2);
    testing.assertEqual($pl.entries[0].duration, DURATION_UNKNOWN);
    testing.assertEqual($pl.entries[0].title, "");
}

func testParseIgnoresBlankLinesAndCarriageReturns() {
    def pl as Playlist init parsePlaylist("#EXTM3U\r\n\r\n#EXTINF:5,A\r\none.mp3\r\n\r\n");
    testing.assertEqual(len($pl.entries), 1);
    testing.assertEqual($pl.entries[0].path, "one.mp3");
    testing.assertEqual($pl.entries[0].title, "A");
    testing.assertEqual($pl.entries[0].duration, 5);
}

func testParseIgnoresCommentsItDoesNotKnow() {
    def pl as Playlist init parsePlaylist("#EXTM3U\n#EXTVLCOPT:x\n#EXTINF:5,A\none.mp3\n");
    testing.assertEqual(len($pl.entries), 1);
    testing.assertEqual($pl.entries[0].title, "A");
}

func testParseKeepsEverythingAfterTheFirstComma() {
    def pl as Playlist init parsePlaylist("#EXTINF:7,Artist - Song, Live\none.mp3\n");
    testing.assertEqual($pl.entries[0].title, "Artist - Song, Live");
}

func testParseAcceptsAnExtinfWithAttributesBeforeItsComma() {
    def line as string init '#EXTINF:12 tvg-id="x" group-title="y",Channel';
    def pl as Playlist init parsePlaylist($line + "\none.mp3\n");
    testing.assertEqual($pl.entries[0].duration, 12);
    testing.assertEqual($pl.entries[0].title, "Channel");
}

func testANegativeOrUnreadableDurationIsUnknown() {
    testing.assertEqual(readDuration("-1"), DURATION_UNKNOWN);
    testing.assertEqual(readDuration(""), DURATION_UNKNOWN);
    testing.assertEqual(readDuration("abc"), DURATION_UNKNOWN);
    testing.assertEqual(readDuration("0"), 0);
    testing.assertEqual(readDuration("12"), 12);
    testing.assertEqual(readDuration("12.5"), 12);
}

func testGroupsCarryForwardAndAreWrittenOnceEach() {
    def pl as Playlist init newPlaylist();
    def first as PlaylistEntry init playlistEntry("one.mp3", "A", 1);
    $first.group = "Side A";
    def second as PlaylistEntry init playlistEntry("two.mp3", "B", 2);
    $second.group = "Side A";
    def third as PlaylistEntry init playlistEntry("three.mp3", "C", 3);
    $third.group = "Side B";
    $pl = addEntry($pl, $first);
    $pl = addEntry($pl, $second);
    $pl = addEntry($pl, $third);

    def text as string init buildPlaylist($pl);
    testing.assertEqual(len(strings.split($text, "#EXTGRP:Side A")), 2);
    def back as Playlist init parsePlaylist($text);
    testing.assertEqual($back.entries[0].group, "Side A");
    testing.assertEqual($back.entries[1].group, "Side A");
    testing.assertEqual($back.entries[2].group, "Side B");
}

func testAlbumAndArtistLinesAttachToTheNextEntryOnly() {
    def text as string init "#EXTM3U\n#EXTALB:Ich war müde leer nicht mehr da\n#EXTART:Vandervaart\n#EXTINF:5,A\none.mp3\ntwo.mp3\n";
    def pl as Playlist init parsePlaylist($text);
    testing.assertEqual($pl.entries[0].album, "Ich war müde leer nicht mehr da");
    testing.assertEqual($pl.entries[0].artist, "Vandervaart");
    testing.assertEqual($pl.entries[1].album, "");
    testing.assertEqual($pl.entries[1].artist, "");
}

func testAByteOrderMarkIsDropped() {
    def text as string init convert.fromCodepoint(0xfeff) + "#EXTM3U\none.mp3\n";
    def pl as Playlist init parsePlaylist($text);
    testing.assertTrue($pl.extended);
    testing.assertEqual(len($pl.entries), 1);
    testing.assertEqual(stripBom("plain"), "plain");
    testing.assertEqual(stripBom(""), "");
}

func testPlaylistDurationIgnoresTheUnknowns() {
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("a.mp3", "", 60));
    $pl = addEntry($pl, playlistEntry("b.mp3", "", DURATION_UNKNOWN));
    $pl = addEntry($pl, playlistEntry("c.mp3", "", 30));
    testing.assertEqual(playlistDuration($pl), 90);
    testing.assertEqual(playlistDuration(newPlaylist()), 0);
}

func testEntryFromTrack() {
    def data as bytes init write(silentStream(100), fullTag(), defaultOptions());
    def track as Track init parse($data);
    def entry as PlaylistEntry init entryFromTrack($track);
    testing.assertEqual($entry.title, "Maike Vandervaart - Ich war müde leer nicht mehr da");
    testing.assertEqual($entry.album, "Ich war müde leer nicht mehr da");
    testing.assertEqual($entry.artist, "Maike Vandervaart");
    testing.assertEqual($entry.duration, (silentStreamMs(100) + 500) // 1000);
}

func testEntryFromATrackWithNoAudioHasAnUnknownDuration() {
    # a file that is nothing but a tag: no stream, so no duration to round
    def track as Track init parse(write(binary.make(0), fullTag(), defaultOptions()));
    testing.assertFalse($track.audio.present);
    $track.path = "/music/tag-only.mp3";
    def entry as PlaylistEntry init entryFromTrack($track);
    testing.assertEqual($entry.path, "/music/tag-only.mp3");
    testing.assertEqual($entry.duration, DURATION_UNKNOWN);
    testing.assertEqual($entry.title, "Maike Vandervaart - Ich war müde leer nicht mehr da");
}

func testEntryTitleFallsBackThroughWhatItHas() {
    def onlyTitle as Tag init emptyTag();
    $onlyTitle.title = "Just a title";
    def a as Track init parse(write(silentStream(1), $onlyTitle, defaultOptions()));
    testing.assertEqual(entryTitle($a), "Just a title");

    def onlyArtist as Tag init emptyTag();
    $onlyArtist.artist = "Just an artist";
    def b as Track init parse(write(silentStream(1), $onlyArtist, defaultOptions()));
    testing.assertEqual(entryTitle($b), "Just an artist");

    def bare as Track init parse(silentStream(1));
    testing.assertEqual(entryTitle($bare), "");
    $bare.path = "/music/track.mp3";
    testing.assertEqual(entryTitle($bare), "track.mp3");
}

func testResolvePlaylistJoinsRelativePathsOnly() {
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("sub/one.mp3", "", 1));
    $pl = addEntry($pl, playlistEntry("/absolute/two.mp3", "", 2));
    $pl = addEntry($pl, playlistEntry("https://example.invalid/s.mp3", "", 3));

    def resolved as Playlist init resolvePlaylist($pl, "/music");
    testing.assertEqual($resolved.entries[0].path, "/music/sub/one.mp3");
    testing.assertEqual($resolved.entries[1].path, "/absolute/two.mp3");
    testing.assertEqual($resolved.entries[2].path, "https://example.invalid/s.mp3");
    # the argument is untouched
    testing.assertEqual($pl.entries[0].path, "sub/one.mp3");
}

func testResolvePlaylistDoesNotConfineTraversal() {
    # documented behaviour: it resolves, it does not sandbox
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("../outside.mp3", "", 1));
    testing.assertEqual(resolvePlaylist($pl, "/music/set").entries[0].path, "/music/outside.mp3");
}

func testIsUrl() {
    testing.assertTrue(isUrl("http://example.invalid/"));
    testing.assertTrue(isUrl("HTTPS://example.invalid/"));
    testing.assertTrue(isUrl("file:///music/one.mp3"));
    testing.assertFalse(isUrl("one.mp3"));
    testing.assertFalse(isUrl("/music/one.mp3"));
}

func testAddEntriesAppendsABatch() {
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("one.mp3", "A", 1));

    def batch as list of PlaylistEntry init [];
    $batch[] = playlistEntry("two.mp3", "B", 2);
    $batch[] = playlistEntry("three.mp3", "C", 3);
    def grown as Playlist init addEntries($pl, $batch);

    testing.assertEqual(len($grown.entries), 3);
    testing.assertEqual($grown.entries[0].path, "one.mp3");
    testing.assertEqual($grown.entries[2].path, "three.mp3");
    testing.assertEqual($grown.title, $pl.title);
    testing.assertEqual($grown.extended, $pl.extended);
    # neither argument changed
    testing.assertEqual(len($pl.entries), 1);
    testing.assertEqual(len($batch), 2);
    # an empty batch is a copy
    testing.assertEqual(len(addEntries($pl, []).entries), 1);
}

func testAssigningTheEntryFieldIsTheSameAsAppending() {
    # the linear way to build a long playlist, and it must agree with addEntry
    def built as Playlist init newPlaylist();
    def entries as list of PlaylistEntry init [];
    def oneByOne as Playlist init newPlaylist();
    for (def i as int init 0; $i < 5; $i = $i + 1) {
        def e as PlaylistEntry init playlistEntry(convert.toString($i) + ".mp3", "x", $i);
        $entries[] = $e;
        $oneByOne = addEntry($oneByOne, $e);
    }
    $built.entries = $entries;
    testing.assertEqual(buildPlaylist($built), buildPlaylist($oneByOne));
}

func testSaveAndOpenAPlaylistAsUtf8() {
    def dir as string init fs.makeTempDir();
    def file as string init path.join($dir, "set.m3u8");
    def pl as Playlist init newPlaylist();
    $pl.title = "日本語";
    $pl = addEntry($pl, playlistEntry("日本.mp3", "曲", 61));
    savePlaylist($pl, $file);

    def back as Playlist init openPlaylist($file);
    testing.assertEqual($back.title, "日本語");
    testing.assertEqual($back.entries[0].path, "日本.mp3");
    testing.assertEqual($back.entries[0].title, "曲");
    fs.removeAll($dir);
}

func testAnM3uThatFitsLatin1IsWrittenAsLatin1() {
    def dir as string init fs.makeTempDir();
    def file as string init path.join($dir, "set.m3u");
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("Grüße.mp3", "Grüße", 1));
    savePlaylist($pl, $file);

    # u-umlaut is one byte in ISO-8859-1 and two in UTF-8
    def raw as bytes init fs.readBytes($file);
    testing.assertTrue(binary.contains($raw, bytesOf([0xfc])));
    # and it still reads back, through the ISO-8859-1 fallback
    def back as Playlist init openPlaylist($file);
    testing.assertEqual($back.entries[0].title, "Grüße");
    fs.removeAll($dir);
}

func testAnM3uThatDoesNotFitLatin1FallsBackToUtf8() {
    def dir as string init fs.makeTempDir();
    def file as string init path.join($dir, "set.m3u");
    def pl as Playlist init newPlaylist();
    $pl = addEntry($pl, playlistEntry("one.mp3", "日本語", 1));
    savePlaylist($pl, $file);
    testing.assertEqual(openPlaylist($file).entries[0].title, "日本語");
    fs.removeAll($dir);
}

func testAPlaylistBuiltFromTracksOnDisk() {
    def dir as string init fs.makeTempDir();
    def pl as Playlist init newPlaylist();
    $pl.title = "Generated";
    for (def i as int init 1; $i < 4; $i = $i + 1) {
        def name as string init "track" + convert.toString($i) + ".mp3";
        def tag as Tag init emptyTag();
        $tag.title = "Track " + convert.toString($i);
        $tag.artist = "Tester";
        $tag.track = $i;
        fs.writeBytes(path.join($dir, $name), write(silentStream(20), $tag, defaultOptions()));
        $pl = addEntry($pl, entryFromTrack(open(path.join($dir, $name))));
    }
    def file as string init path.join($dir, "set.m3u8");
    savePlaylist($pl, $file);

    def back as Playlist init openPlaylist($file);
    testing.assertEqual($back.title, "Generated");
    testing.assertEqual(len($back.entries), 3);
    testing.assertEqual($back.entries[0].title, "Tester - Track 1");
    testing.assertEqual($back.entries[2].title, "Tester - Track 3");
    testing.assertEqual(playlistDuration($back), 3);
    fs.removeAll($dir);
}

func testAnAbsurdlyLongDurationDoesNotOverflow() {
    def pl as Playlist init parsePlaylist("#EXTINF:99999999999999999999,x\none.mp3\n");
    testing.assertEqual($pl.entries[0].duration, LEADING_INT_MAX);
    testing.assertEqual(playlistDuration($pl), LEADING_INT_MAX);
}
