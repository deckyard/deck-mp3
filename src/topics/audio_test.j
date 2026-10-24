# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - white-box tests for the audio topic.
# Spliced into mp3_test.j via include - run with:
#   jennifer test src/mp3_test.j

# A fixture frame whose bitrate index is `index` instead of 9, so a stream
# built from several of them reads as variable bitrate.
func frameAtIndex(index as int) {
    def header as FrameHeader init parseFrameHeader(frameHeaderBytes(($index << 4), 0x00), 0);
    def parts as list of bytes init [];
    $parts[] = frameHeaderBytes(($index << 4), 0x00);
    $parts[] = binary.make($header.frameSize - 4, 0);
    return binary.join($parts);
}

# A first frame carrying a Xing header with the frame count and stream size
# set, followed by `count - 1` ordinary frames.
func xingStream(kind as string, frames as int, streamBytes as int, count as int) {
    def head as list of bytes init [];
    $head[] = frameHeaderBytes(0x90, 0x00);
    # 32 bytes of side information for an MPEG-1 stereo frame
    $head[] = binary.make(32, 0);
    $head[] = latin1Bytes($kind);
    $head[] = beUint32Bytes(3);
    $head[] = beUint32Bytes($frames);
    $head[] = beUint32Bytes($streamBytes);
    def written as bytes init binary.join($head);
    def parts as list of bytes init [];
    $parts[] = $written;
    $parts[] = binary.make(417 - len($written), 0);
    for (def i as int init 1; $i < $count; $i = $i + 1) {
        $parts[] = silentFrame();
    }
    return binary.join($parts);
}

func testReadAudioOnAPlainCbrStream() {
    def data as bytes init silentStream(10);
    def info as AudioInfo init readAudio($data, 0, len($data));
    testing.assertTrue($info.present);
    testing.assertEqual($info.offset, 0);
    testing.assertEqual($info.length, 4170);
    testing.assertEqual($info.frames, 10);
    testing.assertEqual($info.sampleRate, 44100);
    testing.assertEqual($info.channels, 2);
    testing.assertFalse($info.vbr);
    testing.assertTrue($info.exact);
    testing.assertEqual($info.durationMs, silentStreamMs(10));
    # a constant-bitrate stream reports what its frames declare
    testing.assertEqual($info.bitrate, 128000);
}

func testReadAudioOnABufferWithNoFrames() {
    def info as AudioInfo init readAudio(binary.make(512, 0), 0, 512);
    testing.assertFalse($info.present);
    testing.assertEqual($info.frames, 0);
    testing.assertEqual($info.durationMs, 0);
    testing.assertEqual($info.vbrHeader.kind, "");
}

func testReadAudioFindsAStreamPastLeadingJunk() {
    def parts as list of bytes init [];
    $parts[] = binary.make(11, 0);
    $parts[] = silentStream(4);
    def data as bytes init binary.join($parts);
    def info as AudioInfo init readAudio($data, 0, len($data));
    testing.assertEqual($info.offset, 11);
    testing.assertEqual($info.frames, 4);
}

func testReadAudioHonoursTheRangeItIsGiven() {
    def data as bytes init silentStream(10);
    def info as AudioInfo init readAudio($data, 0, 417 * 4);
    testing.assertEqual($info.frames, 4);
    testing.assertEqual($info.length, 417 * 4);
}

func testWithoutScanningTheDurationIsAnEstimate() {
    def data as bytes init silentStream(10);
    def info as AudioInfo init readAudioWith($data, 0, len($data), false);
    testing.assertTrue($info.present);
    testing.assertEqual($info.frames, 0);
    testing.assertFalse($info.exact);
    # 4170 bytes at 128 kbit/s
    testing.assertEqual($info.durationMs, 261);
}

func testAVaryingBitrateIsDetectedByTheScan() {
    def parts as list of bytes init [];
    $parts[] = frameAtIndex(9);
    $parts[] = frameAtIndex(5);
    $parts[] = frameAtIndex(13);
    def data as bytes init binary.join($parts);
    def info as AudioInfo init readAudio($data, 0, len($data));
    testing.assertEqual($info.frames, 3);
    testing.assertTrue($info.vbr);
    testing.assertTrue($info.exact);
    # a varying stream reports the measured average instead
    testing.assertNotEqual($info.bitrate, 128000);
}

func testAXingHeaderMakesTheAnswerExactWithoutScanning() {
    def data as bytes init xingStream("Xing", 1000, 417000, 2);
    def info as AudioInfo init readAudioWith($data, 0, len($data), false);
    testing.assertEqual($info.vbrHeader.kind, "Xing");
    testing.assertEqual($info.vbrHeader.frames, 1000);
    testing.assertEqual($info.vbrHeader.streamBytes, 417000);
    testing.assertFalse($info.vbrHeader.hasToc);
    testing.assertEqual($info.frames, 1000);
    testing.assertTrue($info.vbr);
    testing.assertTrue($info.exact);
    testing.assertEqual($info.durationMs, durationFromSamples(1000 * 1152, 44100));
}

func testAnInfoHeaderMarksAConstantBitrateStream() {
    def data as bytes init xingStream("Info", 10, 4170, 2);
    def info as AudioInfo init readAudio($data, 0, len($data));
    testing.assertEqual($info.vbrHeader.kind, "Info");
    testing.assertFalse($info.vbr);
    testing.assertEqual($info.bitrate, 128000);
    testing.assertEqual($info.frames, 10);
}

func testAVbriHeaderIsReadAtItsFixedOffset() {
    def head as list of bytes init [];
    $head[] = frameHeaderBytes(0x90, 0x00);
    $head[] = binary.make(32, 0);
    $head[] = latin1Bytes("VBRI");
    $head[] = binary.make(2, 0);
    $head[] = binary.make(2, 0);
    $head[] = bytesOf([0x00, 0x4b]);
    $head[] = beUint32Bytes(4170);
    $head[] = beUint32Bytes(10);
    $head[] = bytesOf([0x00, 0x02]);
    def written as bytes init binary.join($head);
    def parts as list of bytes init [];
    $parts[] = $written;
    $parts[] = binary.make(417 - len($written), 0);
    def data as bytes init binary.join($parts);

    def info as AudioInfo init readAudioWith($data, 0, len($data), false);
    testing.assertEqual($info.vbrHeader.kind, "VBRI");
    testing.assertEqual($info.vbrHeader.frames, 10);
    testing.assertEqual($info.vbrHeader.streamBytes, 4170);
    testing.assertEqual($info.vbrHeader.quality, 75);
    testing.assertTrue($info.vbrHeader.hasToc);
    testing.assertTrue($info.vbr);
}

func testATruncatedXingHeaderKeepsWhatItRead() {
    def head as list of bytes init [];
    $head[] = frameHeaderBytes(0x90, 0x00);
    $head[] = binary.make(32, 0);
    $head[] = latin1Bytes("Xing");
    $head[] = beUint32Bytes(3);
    $head[] = beUint32Bytes(99);
    def data as bytes init binary.join($head);
    def found as VbrHeader init readVbrHeader($data, parseFrameHeader($data, 0));
    testing.assertEqual($found.kind, "Xing");
    testing.assertEqual($found.frames, 99);
    testing.assertEqual($found.streamBytes, 0);
}

func testXingFlagsSelectWhichFieldsFollow() {
    def head as list of bytes init [];
    $head[] = frameHeaderBytes(0x90, 0x00);
    $head[] = binary.make(32, 0);
    $head[] = latin1Bytes("Xing");
    # every flag: frames, bytes, table of contents, quality
    $head[] = beUint32Bytes(15);
    $head[] = beUint32Bytes(7);
    $head[] = beUint32Bytes(2919);
    $head[] = binary.make(100, 0);
    $head[] = beUint32Bytes(78);
    def data as bytes init binary.join($head);
    def found as VbrHeader init readVbrHeader($data, parseFrameHeader($data, 0));
    testing.assertEqual($found.frames, 7);
    testing.assertEqual($found.streamBytes, 2919);
    testing.assertTrue($found.hasToc);
    testing.assertEqual($found.quality, 78);
}

func testEmptyVbrHeader() {
    def empty as VbrHeader init emptyVbrHeader();
    testing.assertEqual($empty.kind, "");
    testing.assertEqual($empty.frames, 0);
    testing.assertEqual($empty.quality, -1);
    testing.assertFalse($empty.hasToc);
}

func testTheFrameSizeTableMatchesTheHeaderParser() {
    def header as FrameHeader init parseFrameHeader(silentFrame(), 0);
    def table as list of int init frameSizeTable($header);
    testing.assertEqual(len($table), 16);
    testing.assertEqual($table[0], 0);
    testing.assertEqual($table[15], 0);
    for (def index as int init 1; $index < 15; $index = $index + 1) {
        def sized as FrameHeader init parseFrameHeader(frameHeaderBytes(($index << 4), 0), 0);
        testing.assertEqual($table[$index], $sized.frameSize);
    }
}

func testSlotSizeOf() {
    testing.assertEqual(slotSizeOf(parseFrameHeader(silentFrame(), 0)), 1);
    def l1 as bytes init bytesOf([0xff, 0xff, 0x90, 0x00]);
    testing.assertEqual(slotSizeOf(parseFrameHeader($l1, 0)), 4);
}

func testCountFramesStopsAtTheFirstBreak() {
    def parts as list of bytes init [];
    $parts[] = silentStream(2);
    $parts[] = binary.make(64, 0x00);
    def data as bytes init binary.join($parts);
    def header as FrameHeader init parseFrameHeader($data, 0);
    def scan as FrameScan init countFrames($data, $header, len($data));
    testing.assertEqual($scan.frames, 2);
    testing.assertEqual($scan.bytes, 834);
    testing.assertFalse($scan.vbr);
}

func testCountFramesRebuildsItsTableWhenTheStreamShapeChanges() {
    # an MPEG-1 frame followed by an MPEG-2 one: a different sampling rate,
    # so the size table built from the first frame does not apply
    def v2 as bytes init bytesOf([0xff, 0xf3, 0x90, 0x00]);
    def v2header as FrameHeader init parseFrameHeader($v2, 0);
    def parts as list of bytes init [];
    $parts[] = silentFrame();
    $parts[] = $v2;
    $parts[] = binary.make($v2header.frameSize - 4, 0);
    $parts[] = silentFrame();
    def data as bytes init binary.join($parts);

    def scan as FrameScan init countFrames($data, parseFrameHeader($data, 0), len($data));
    testing.assertEqual($scan.frames, 3);
    testing.assertEqual($scan.bytes, 417 + $v2header.frameSize + 417);
}

func testFrameShapeCarriesTheSyncBits() {
    def data as bytes init silentFrame();
    testing.assertEqual(frameShapeAt($data, 0), frameShapeAt(silentStream(2), 417));
    testing.assertEqual(frameShapeAt($data, len($data) - 1), -1);
    testing.assertEqual(frameShapeAt($data, -1), -1);

    # a byte that is not a header does not share the shape, which is what lets
    # the walk reject it with the one comparison it makes per frame
    testing.assertNotEqual(frameShapeAt(binary.make(4, 0), 0), frameShapeAt($data, 0));
    # the protection bit is excluded: it may vary and does not change the size
    def crc as bytes init bytesOf([0xff, 0xfa, 0x90, 0x00]);
    testing.assertEqual(frameShapeAt($crc, 0), frameShapeAt($data, 0));
    # a different sampling rate does not
    def other as bytes init bytesOf([0xff, 0xfb, 0x94, 0x00]);
    testing.assertNotEqual(frameShapeAt($other, 0), frameShapeAt($data, 0));
}

func testFrameSizeByByteMatchesTheHeaderParser() {
    def header as FrameHeader init parseFrameHeader(silentFrame(), 0);
    def sizes as list of int init frameSizeByByte($header, 0x00);
    testing.assertEqual(len($sizes), 256);

    for (def index as int init 1; $index < 15; $index = $index + 1) {
        def plain as int init $index << 4;
        def padded as int init ($index << 4) | 0x02;
        def sized as FrameHeader init parseFrameHeader(frameHeaderBytes($plain, 0), 0);
        def padSized as FrameHeader init parseFrameHeader(frameHeaderBytes($padded, 0), 0);
        testing.assertEqual($sizes[$plain], $sized.frameSize);
        testing.assertEqual($sizes[$padded], $padSized.frameSize);
        # the private bit does not change the size
        testing.assertEqual($sizes[$plain | 0x01], $sized.frameSize);
    }
    # free format, the invalid index, and any other sampling rate are all zero
    testing.assertEqual($sizes[0x00], 0);
    testing.assertEqual($sizes[0xf0], 0);
    testing.assertEqual($sizes[0x94], 0);
}

func testDurationFromSamplesAndBitrate() {
    testing.assertEqual(durationFromSamples(44100, 44100), 1000);
    testing.assertEqual(durationFromSamples(0, 44100), 0);
    testing.assertEqual(durationFromSamples(1000, 0), 0);
    testing.assertEqual(durationFromBitrate(16000, 128000), 1000);
    testing.assertEqual(durationFromBitrate(0, 128000), 0);
    testing.assertEqual(durationFromBitrate(1000, 0), 0);
}

func testAverageBitrate() {
    testing.assertEqual(averageBitrate(16000, 1000, 1), 128000);
    testing.assertEqual(averageBitrate(16000, 0, 42), 42);
    testing.assertEqual(averageBitrate(0, 1000, 42), 42);
}

func testFormatDuration() {
    testing.assertEqual(formatDuration(0), "0:00");
    testing.assertEqual(formatDuration(-5), "0:00");
    testing.assertEqual(formatDuration(1000), "0:01");
    testing.assertEqual(formatDuration(61000), "1:01");
    testing.assertEqual(formatDuration(214000), "3:34");
    testing.assertEqual(formatDuration(3600000), "1:00:00");
    testing.assertEqual(formatDuration(3754000), "1:02:34");
}
