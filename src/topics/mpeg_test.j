# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the mpeg topic, and the MPEG fixtures every
# later overlay builds its test files from.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

# One MPEG-1 Layer III frame header: 44100 Hz, 128 kbit/s, stereo, no
# padding. 1152 samples per frame, so 144 * 128000 / 44100 = 417 bytes.
func frameHeaderBytes(byte2 as int, byte3 as int) {
    def head as bytes;
    $head[] = 0xff;
    $head[] = 0xfb;
    $head[] = $byte2;
    $head[] = $byte3;
    return $head;
}

# A whole 417-byte frame, silent: the header and 413 zero bytes.
func silentFrame() {
    def parts as list of bytes init [];
    $parts[] = frameHeaderBytes(0x90, 0x00);
    $parts[] = binary.make(413, 0);
    return binary.join($parts);
}

# `count` of those, back to back - the fixture audio stream.
func silentStream(count as int) {
    def parts as list of bytes init [];
    for (def i as int init 0; $i < $count; $i = $i + 1) {
        $parts[] = silentFrame();
    }
    return binary.join($parts);
}

# How long `count` fixture frames play, in milliseconds.
func silentStreamMs(count as int) {
    return durationFromSamples($count * 1152, 44100);
}

func testFixtureFrameIsTheSizeItsHeaderSays() {
    def h as FrameHeader init parseFrameHeader(silentFrame(), 0);
    testing.assertEqual($h.frameSize, 417);
    testing.assertEqual(len(silentFrame()), 417);
    testing.assertEqual(len(silentStream(3)), 1251);
}

func testParseFrameHeaderReadsEveryField() {
    def h as FrameHeader init parseFrameHeader(silentFrame(), 0);
    testing.assertEqual($h.offset, 0);
    testing.assertEqual(versionName($h.version), "MPEG-1");
    testing.assertEqual(layerName($h.layer), "Layer III");
    testing.assertEqual($h.bitrate, 128000);
    testing.assertEqual($h.sampleRate, 44100);
    testing.assertEqual(channelModeName($h.channelMode), "stereo");
    testing.assertEqual($h.channels, 2);
    testing.assertEqual($h.samples, 1152);
    testing.assertFalse($h.padding);
    testing.assertFalse($h.crc);
    testing.assertFalse($h.copyright);
    testing.assertFalse($h.original);
    testing.assertEqual($h.emphasis, 0);
    testing.assertEqual($h.modeExtension, 0);
}

func testPaddingAddsOneSlot() {
    def padded as bytes init frameHeaderBytes(0x92, 0x00);
    def h as FrameHeader init parseFrameHeader($padded, 0);
    testing.assertTrue($h.padding);
    testing.assertEqual($h.frameSize, 418);
}

func testProtectionBitIsInverted() {
    # bit 0 of byte 1 clear means a CRC follows
    def head as bytes;
    $head[] = 0xff;
    $head[] = 0xfa;
    $head[] = 0x90;
    $head[] = 0x00;
    testing.assertTrue(parseFrameHeader($head, 0).crc);
}

func testMonoHasOneChannel() {
    def mono as bytes init frameHeaderBytes(0x90, 0xc0);
    def h as FrameHeader init parseFrameHeader($mono, 0);
    testing.assertEqual($h.channels, 1);
    testing.assertEqual(channelModeName($h.channelMode), "mono");
    testing.assertEqual(sideInfoSize($h), 17);
}

func testEveryChannelModeName() {
    testing.assertEqual(channelModeName(channelModeOf(0)), "stereo");
    testing.assertEqual(channelModeName(channelModeOf(1)), "joint stereo");
    testing.assertEqual(channelModeName(channelModeOf(2)), "dual channel");
    testing.assertEqual(channelModeName(channelModeOf(3)), "mono");
}

func testSideInfoSizeForEveryShape() {
    def stereo1 as FrameHeader init parseFrameHeader(silentFrame(), 0);
    testing.assertEqual(sideInfoSize($stereo1), 32);

    # MPEG-2 Layer III, 22050 Hz, stereo and mono
    def v2stereo as bytes init bytesOf([0xff, 0xf3, 0x90, 0x00]);
    testing.assertEqual(sideInfoSize(parseFrameHeader($v2stereo, 0)), 17);
    def v2mono as bytes init bytesOf([0xff, 0xf3, 0x90, 0xc0]);
    testing.assertEqual(sideInfoSize(parseFrameHeader($v2mono, 0)), 9);
}

func testMpeg2HalvesTheSampleRateAndTheLayer3FrameLength() {
    # 0xf3: MPEG-2, Layer III. 0x90: bitrate index 9, rate index 0 -> 22050 Hz
    def v2 as bytes init bytesOf([0xff, 0xf3, 0x90, 0x00]);
    def h as FrameHeader init parseFrameHeader($v2, 0);
    testing.assertEqual(versionName($h.version), "MPEG-2");
    testing.assertEqual($h.sampleRate, 22050);
    testing.assertEqual($h.samples, 576);
    # the MPEG-2 Layer II/III bitrate table: index 9 is 80 kbit/s
    testing.assertEqual($h.bitrate, 80000);
    testing.assertEqual($h.frameSize, 261);
}

func testMpeg25() {
    # 0xe3: MPEG-2.5, Layer III -> 11025 Hz at rate index 0
    def v25 as bytes init bytesOf([0xff, 0xe3, 0x90, 0x00]);
    def h as FrameHeader init parseFrameHeader($v25, 0);
    testing.assertEqual(versionName($h.version), "MPEG-2.5");
    testing.assertEqual($h.sampleRate, 11025);
    testing.assertEqual($h.samples, 576);
}

func testLayerOneCountsInFourByteSlots() {
    # 0xff: MPEG-1 Layer I. 0x90 -> bitrate index 9 = 288 kbit/s, 44100 Hz
    def l1 as bytes init bytesOf([0xff, 0xff, 0x90, 0x00]);
    def h as FrameHeader init parseFrameHeader($l1, 0);
    testing.assertEqual(layerName($h.layer), "Layer I");
    testing.assertEqual($h.samples, 384);
    testing.assertEqual($h.bitrate, 288000);
    # (12 * 288000 / 44100) * 4 = 78 * 4
    testing.assertEqual($h.frameSize, 312);

    def padded as bytes init bytesOf([0xff, 0xff, 0x92, 0x00]);
    testing.assertEqual(parseFrameHeader($padded, 0).frameSize, 316);
}

func testLayerTwo() {
    # 0xfd: MPEG-1 Layer II. 0x90 -> bitrate index 9 = 160 kbit/s
    def l2 as bytes init bytesOf([0xff, 0xfd, 0x90, 0x00]);
    def h as FrameHeader init parseFrameHeader($l2, 0);
    testing.assertEqual(layerName($h.layer), "Layer II");
    testing.assertEqual($h.samples, 1152);
    testing.assertEqual($h.bitrate, 160000);
    # 144 * 160000 / 44100
    testing.assertEqual($h.frameSize, 522);
}

func testTheSampleRateTablesForEveryGeneration() {
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg1, 0), 44100);
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg1, 1), 48000);
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg1, 2), 32000);
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg2, 0), 22050);
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg25, 0), 11025);
    testing.assertEqual(sampleRateOf(MpegVersion.Mpeg25, 2), 8000);
    testing.assertThrows("reservedSampleRate", ERROR_KIND);
}

func reservedSampleRate() {
    sampleRateOf(MpegVersion.Mpeg1, 3);
}

func testTheBitrateTablesAtBothEnds() {
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg1, Layer.LayerI, 1), 32);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg1, Layer.LayerI, 14), 448);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg1, Layer.LayerII, 14), 384);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg1, Layer.LayerIII, 14), 320);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg2, Layer.LayerI, 1), 32);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg2, Layer.LayerIII, 1), 8);
    testing.assertEqual(bitrateOf(MpegVersion.Mpeg25, Layer.LayerII, 14), 160);
    testing.assertThrows("freeFormatBitrate", ERROR_KIND);
    testing.assertThrows("invalidBitrate", ERROR_KIND);
}

func freeFormatBitrate() {
    bitrateOf(MpegVersion.Mpeg1, Layer.LayerIII, 0);
}

func invalidBitrate() {
    bitrateOf(MpegVersion.Mpeg1, Layer.LayerIII, 15);
}

func testVersionAndLayerFieldsRejectTheReservedEncodings() {
    testing.assertThrows("reservedVersion", ERROR_KIND);
    testing.assertThrows("reservedLayer", ERROR_KIND);
}

func reservedVersion() {
    versionOf(1);
}

func reservedLayer() {
    layerOf(0);
}

func testIsFrameHeaderAtRejectsEveryIllegalShape() {
    # no sync
    testing.assertFalse(isFrameHeaderAt(bytesOf([0x00, 0xfb, 0x90, 0x00]), 0));
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0x1b, 0x90, 0x00]), 0));
    # reserved version 01
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xeb, 0x90, 0x00]), 0));
    # reserved layer 00
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xf9, 0x90, 0x00]), 0));
    # free-format and invalid bitrate indices
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xfb, 0x00, 0x00]), 0));
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xfb, 0xf0, 0x00]), 0));
    # reserved sampling-rate index 3
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xfb, 0x9c, 0x00]), 0));
    # too short, and a negative offset
    testing.assertFalse(isFrameHeaderAt(bytesOf([0xff, 0xfb, 0x90]), 0));
    testing.assertFalse(isFrameHeaderAt(silentFrame(), -1));
}

func testParseFrameHeaderRefusesWhatIsNotOne() {
    testing.assertThrows("parseGarbage", ERROR_KIND);
}

func parseGarbage() {
    parseFrameHeader(binary.make(8, 0), 0);
}

func testFindFrameHeaderSkipsLeadingJunk() {
    def parts as list of bytes init [];
    $parts[] = binary.make(7, 0x00);
    $parts[] = silentStream(3);
    def data as bytes init binary.join($parts);
    testing.assertEqual(findFrameHeader($data, 0, len($data)), 7);
}

func testFindFrameHeaderIgnoresAnFfThatLeadsNowhere() {
    # an isolated ff e0 pair inside junk is not a frame: nothing follows it
    def parts as list of bytes init [];
    $parts[] = bytesOf([0xff, 0xfb, 0x90, 0x00]);
    $parts[] = binary.make(3, 0x00);
    $parts[] = silentStream(2);
    def data as bytes init binary.join($parts);
    # the decoy claims 417 bytes but only 7 follow, so the real stream wins
    testing.assertEqual(findFrameHeader($data, 0, len($data)), 7);
}

func testFindFrameHeaderReturnsMinusOneWhenThereIsNone() {
    testing.assertEqual(findFrameHeader(binary.make(64, 0), 0, 64), -1);
    testing.assertEqual(findFrameHeader(silentStream(2), 0, 0), -1);
}

func testChainHoldsFollowsTheFrames() {
    def data as bytes init silentStream(3);
    testing.assertTrue(chainHolds($data, 0, 2));
    testing.assertTrue(chainHolds($data, 417, 2));
    # the last frame runs to the end of the buffer, which still counts
    testing.assertTrue(chainHolds($data, 834, 2));
    testing.assertFalse(chainHolds(binary.make(417, 0), 0, 1));
}

func testChannelModeIsUsableAsADeclaredType() {
    def mode as ChannelMode init ChannelMode.JointStereo;
    testing.assertEqual(channelModeName($mode), "joint stereo");
    # the zero value is the first variant
    def zero as ChannelMode;
    testing.assertEqual(channelModeName($zero), "stereo");

    def version as MpegVersion;
    testing.assertEqual(versionName($version), "MPEG-2.5");
    def layer as Layer;
    testing.assertEqual(layerName($layer), "Layer I");
}
