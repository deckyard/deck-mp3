# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the file topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

# A complete file: an ID3v2 tag, `frames` frames of silence, and an optional
# ID3v1 tag.
func wholeFile(tag as Tag, options as WriteOptions, frames as int) {
    return write(silentStream($frames), $tag, $options);
}

func testDefaultOptions() {
    def opts as WriteOptions init defaultOptions();
    testing.assertEqual($opts.major, DEFAULT_MAJOR);
    testing.assertEqual($opts.major, 4);
    testing.assertEqual($opts.padding, DEFAULT_PADDING);
    testing.assertEqual($opts.padding, 1024);
    testing.assertTrue($opts.id3v2);
    testing.assertFalse($opts.id3v1);
}

func testAudioRangeOnABareStream() {
    def data as bytes init silentStream(3);
    def range as AudioRange init audioRange($data);
    testing.assertEqual($range.start, 0);
    testing.assertEqual($range.end, len($data));
}

func testAudioRangeExcludesBothTags() {
    def opts as WriteOptions init defaultOptions();
    $opts.id3v1 = true;
    def data as bytes init wholeFile(fullTag(), $opts, 3);
    def range as AudioRange init audioRange($data);
    testing.assertEqual($range.start, id3v2Size($data));
    testing.assertEqual($range.end, len($data) - ID3V1_SIZE);
    testing.assertEqual($range.end - $range.start, 417 * 3);
}

func testAudioRangeOnAFileThatIsNothingButTags() {
    def data as bytes init renderId3v1(emptyId3v1());
    def range as AudioRange init audioRange($data);
    testing.assertEqual($range.start, 0);
    testing.assertEqual($range.end, 0);
}

func testAudioRangeOnAnEmptyBuffer() {
    def range as AudioRange init audioRange(binary.make(0));
    testing.assertEqual($range.start, 0);
    testing.assertEqual($range.end, 0);
}

func testStripLeavesTheAudioByteForByte() {
    def audio as bytes init silentStream(4);
    def opts as WriteOptions init defaultOptions();
    $opts.id3v1 = true;
    def data as bytes init write($audio, fullTag(), $opts);
    testing.assertEqual(strip($data), $audio);
    # stripping twice is the same as stripping once
    testing.assertEqual(strip(strip($data)), $audio);
}

func testWriteRoundTripsThroughParse() {
    def opts as WriteOptions init defaultOptions();
    $opts.id3v1 = true;
    def data as bytes init wholeFile(fullTag(), $opts, 5);
    def track as Track init parse($data);

    testing.assertEqual($track.path, "");
    testing.assertTrue($track.id3v2.present);
    testing.assertEqual($track.id3v2.major, 4);
    testing.assertTrue($track.id3v1.present);
    testing.assertEqual($track.tag.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($track.tag.artist, "Maike Vandervaart");
    testing.assertEqual($track.tag.track, 1);
    testing.assertTrue($track.audio.present);
    testing.assertEqual($track.audio.frames, 5);
    testing.assertEqual($track.audio.durationMs, silentStreamMs(5));
}

func testWritingWithoutAnId3v2TagLeavesNoneBehind() {
    def opts as WriteOptions init defaultOptions();
    $opts.id3v2 = false;
    $opts.id3v1 = true;
    def data as bytes init wholeFile(fullTag(), $opts, 2);
    testing.assertEqual(id3v2Size($data), 0);
    def track as Track init parse($data);
    testing.assertFalse($track.id3v2.present);
    testing.assertTrue($track.id3v1.present);
    # the ID3v1 tag alone still fills the unified view, title cut to its 30 bytes
    testing.assertEqual($track.tag.title, "Ich war müde leer nicht mehr d");
}

func testWritingNeitherTagGivesBackTheBareStream() {
    def opts as WriteOptions init defaultOptions();
    $opts.id3v2 = false;
    $opts.id3v1 = false;
    testing.assertEqual(wholeFile(fullTag(), $opts, 2), silentStream(2));
}

func testAnId3v1OnlyFileIsReadThroughTheUnifiedView() {
    def parts as list of bytes init [];
    $parts[] = silentStream(2);
    $parts[] = renderId3v1(id3v1FromTag(fullTag()));
    def track as Track init parse(binary.join($parts));
    testing.assertFalse($track.id3v2.present);
    # ID3v1 holds 30 bytes of title; the 31-character title loses its last letter
    testing.assertEqual($track.tag.title, "Ich war müde leer nicht mehr d");
    testing.assertEqual($track.tag.genre, "Ambient");
    testing.assertEqual($track.audio.frames, 2);
}

func testTheId3v2TagWinsOverTheId3v1TagItBacks() {
    def v2tag as Tag init emptyTag();
    $v2tag.title = "from v2";
    def opts as WriteOptions init defaultOptions();
    def data as bytes init write(silentStream(1), $v2tag, $opts);

    def v1 as Id3v1 init emptyId3v1();
    $v1.title = "from v1";
    $v1.artist = "only in v1";
    def parts as list of bytes init [];
    $parts[] = $data;
    $parts[] = renderId3v1($v1);

    def track as Track init parse(binary.join($parts));
    testing.assertEqual($track.tag.title, "from v2");
    testing.assertEqual($track.tag.artist, "only in v1");
}

func testOptionsForPreservesWhatTheFileHad() {
    def written as WriteOptions init defaultOptions();
    $written.major = 3;
    $written.id3v1 = true;
    def track as Track init parse(wholeFile(fullTag(), $written, 2));

    def kept as WriteOptions init optionsFor($track);
    testing.assertEqual($kept.major, 3);
    testing.assertTrue($kept.id3v1);

    def bare as Track init parse(silentStream(2));
    testing.assertEqual(optionsFor($bare).major, DEFAULT_MAJOR);
    testing.assertFalse(optionsFor($bare).id3v1);
}

func testParseWithoutScanningSkipsTheFrameWalk() {
    def data as bytes init wholeFile(fullTag(), defaultOptions(), 5);
    def track as Track init parseWith($data, false);
    testing.assertTrue($track.audio.present);
    testing.assertFalse($track.audio.exact);
    testing.assertEqual($track.audio.frames, 0);
}

func testWithTagLeavesTheOriginalAlone() {
    def track as Track init parse(wholeFile(fullTag(), defaultOptions(), 2));
    def changed as Tag init $track.tag;
    $changed.title = "something else";
    def updated as Track init withTag($track, $changed);
    testing.assertEqual($updated.tag.title, "something else");
    testing.assertEqual($track.tag.title, "Ich war müde leer nicht mehr da");
}

func testWriteRejectsOptionsItCannotSatisfy() {
    testing.assertThrows("writeBadVersion", ERROR_KIND);
    testing.assertThrows("writeNegativePadding", ERROR_KIND);
}

func writeBadVersion() {
    def opts as WriteOptions init defaultOptions();
    $opts.major = 7;
    write(silentStream(1), emptyTag(), $opts);
}

func writeNegativePadding() {
    def opts as WriteOptions init defaultOptions();
    $opts.padding = -1;
    write(silentStream(1), emptyTag(), $opts);
}

func testHeaderAndTrailerBytesFollowTheOptions() {
    def off as WriteOptions init defaultOptions();
    $off.id3v2 = false;
    testing.assertEqual(len(headerBytes(fullTag(), $off)), 0);
    testing.assertEqual(len(trailerBytes(fullTag(), $off)), 0);

    def on as WriteOptions init defaultOptions();
    $on.id3v1 = true;
    testing.assertTrue(len(headerBytes(fullTag(), $on)) > ID3V2_HEADER_SIZE);
    testing.assertEqual(len(trailerBytes(fullTag(), $on)), ID3V1_SIZE);
}

func testDescribe() {
    def track as Track init parse(wholeFile(fullTag(), defaultOptions(), 100));
    def line as string init describe($track);
    testing.assertContains($line, "Maike Vandervaart - Ich war müde leer nicht mehr da");
    testing.assertContains($line, "128 kbit/s");
    testing.assertContains($line, "44100 Hz");
    testing.assertContains($line, "stereo");
    testing.assertContains($line, "0:02");
}

func testDescribeWithNoAudioAndNoNames() {
    def empty as Track init parse(binary.make(32, 0));
    testing.assertEqual(describe($empty), "no audio");
}

func testDescribeWithOnlyOneOfArtistAndTitle() {
    def onlyTitle as Tag init emptyTag();
    $onlyTitle.title = "Untitled";
    def track as Track init parse(write(silentStream(2), $onlyTitle, defaultOptions()));
    testing.assertContains(describe($track), "Untitled");

    def onlyArtist as Tag init emptyTag();
    $onlyArtist.artist = "Anon";
    def other as Track init parse(write(silentStream(2), $onlyArtist, defaultOptions()));
    testing.assertContains(describe($other), "Anon");
}

func testOpenAndSaveThroughTheFilesystem() {
    def dir as string init fs.makeTempDir();
    def source as string init path.join($dir, "song.mp3");
    def opts as WriteOptions init defaultOptions();
    $opts.id3v1 = true;
    fs.writeBytes($source, wholeFile(fullTag(), $opts, 4));

    def track as Track init open($source);
    testing.assertEqual($track.path, $source);
    testing.assertEqual($track.tag.title, "Ich war müde leer nicht mehr da");
    testing.assertEqual($track.audio.frames, 4);

    def changed as Tag init $track.tag;
    $changed.title = "Ich war müde leer nicht mehr da (Instrumental)";
    $changed.genre = "Trance";
    def target as string init path.join($dir, "renamed.mp3");
    save(withTag($track, $changed), $target);

    def back as Track init open($target);
    testing.assertEqual($back.tag.title, "Ich war müde leer nicht mehr da (Instrumental)");
    testing.assertEqual($back.tag.genre, "Trance");
    # the options were preserved, so the ID3v1 tag came along
    testing.assertTrue($back.id3v1.present);
    testing.assertEqual($back.id3v2.major, 4);
    # and the audio is byte-identical
    testing.assertEqual(strip(fs.readBytes($target)), silentStream(4));
    fs.removeAll($dir);
}

func testTempPathIsBesideTheTargetAndUnguessable() {
    def a as string init tempPath("/music/song.mp3");
    def b as string init tempPath("/music/song.mp3");
    testing.assertTrue(strings.startsWith($a, "/music/song.mp3."));
    testing.assertTrue(strings.endsWith($a, TEMP_SUFFIX));
    testing.assertEqual(path.dir($a), "/music");
    testing.assertNotEqual($a, $b);
}

func testSaveOverTheSourceFile() {
    def dir as string init fs.makeTempDir();
    def file as string init path.join($dir, "song.mp3");
    fs.writeBytes($file, wholeFile(fullTag(), defaultOptions(), 3));

    def track as Track init open($file);
    def changed as Tag init $track.tag;
    $changed.artist = "Someone Else";
    save(withTag($track, $changed), $file);

    testing.assertEqual(open($file).tag.artist, "Someone Else");
    testing.assertEqual(strip(fs.readBytes($file)), silentStream(3));
    # the temporary file the atomic write used is gone, whatever it was called
    testing.assertEqual(len(fs.list($dir)), 1);
    fs.removeAll($dir);
}

func testSaveRefusesATrackWithNoSourceFile() {
    testing.assertThrows("saveABufferTrack", ERROR_KIND);
}

func saveABufferTrack() {
    save(parse(silentStream(1)), "/nonexistent/path.mp3");
}

func testRemoveQuietlySwallowsWhatItCannotRemove() {
    removeQuietly("/nonexistent/directory/file.mp3");
    def dir as string init fs.makeTempDir();
    def file as string init path.join($dir, "x");
    fs.writeString($file, "x");
    removeQuietly($file);
    testing.assertFalse(fs.exists($file));
    fs.removeAll($dir);
}

func testWriteFileLeavesNoTemporaryBehindWhenItFails() {
    def dir as string init fs.makeTempDir();
    def source as string init path.join($dir, "song.mp3");
    fs.writeBytes($source, wholeFile(fullTag(), defaultOptions(), 2));

    def bad as WriteOptions init defaultOptions();
    $bad.major = 9;
    def target as string init path.join($dir, "out.mp3");
    try {
        writeFile($source, $target, fullTag(), $bad);
        testing.assertTrue(false);
    } catch (e) {
        testing.assertEqual($e.kind, ERROR_KIND);
    }
    # nothing is left beside the source but the source
    testing.assertEqual(len(fs.list($dir)), 1);
    fs.removeAll($dir);
}
