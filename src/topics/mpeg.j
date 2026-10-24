# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the four-byte MPEG audio frame header.
# Spliced into mp3.j via include - not a standalone module.

/**
 * Which generation of the MPEG audio standard a frame was coded to.
 *
 * MPEG-2 halved every sampling rate of MPEG-1, and the unofficial but
 * universally implemented MPEG-2.5 halved them again.
 */
export def enum MpegVersion {
    Mpeg25,
    Mpeg2,
    Mpeg1
};

/** Which of the three MPEG audio layers a frame was coded to. MP3 is Layer III. */
export def enum Layer {
    LayerI,
    LayerII,
    LayerIII
};

/** How a frame carries its channels. */
export def enum ChannelMode {
    Stereo,
    JointStereo,
    DualChannel,
    Mono
};

/**
 * One decoded MPEG audio frame header.
 *
 * Four bytes at the top of every frame, found by an eleven-bit sync word.
 * Everything else about the frame - how long it is, how many PCM samples it
 * carries - follows from these fields and the tables below.
 *
 * @field offset {int} where the header starts in the buffer it was read from
 * @field version {MpegVersion} MPEG-1, MPEG-2 or MPEG-2.5
 * @field layer {Layer} Layer I, II or III
 * @field bitrate {int} bits per second; `0` for a free-format frame
 * @field sampleRate {int} samples per second
 * @field channelMode {ChannelMode} stereo, joint stereo, dual channel or mono
 * @field channels {int} 1 for mono, 2 for everything else
 * @field modeExtension {int} the joint-stereo mode extension bits, 0-3
 * @field padding {bool} whether the frame carries one extra slot
 * @field crc {bool} whether a 16-bit CRC follows the header
 * @field copyright {bool} the copyright bit
 * @field original {bool} the original-media bit
 * @field emphasis {int} the de-emphasis field, 0-3
 * @field frameSize {int} the whole frame in bytes, header included
 * @field samples {int} PCM samples per channel the frame decodes to
 */
export def struct FrameHeader {
    offset as int,
    version as MpegVersion,
    layer as Layer,
    bitrate as int,
    sampleRate as int,
    channelMode as ChannelMode,
    channels as int,
    modeExtension as int,
    padding as bool,
    crc as bool,
    copyright as bool,
    original as bool,
    emphasis as int,
    frameSize as int,
    samples as int
};

# Bitrates in kbit/s, indexed by the header's four-bit bitrate field. Index 0
# is "free format" (the stream states its own rate out of band) and index 15
# is invalid; both are stored as 0 and rejected by isFrameHeaderAt.
def const BITRATES_V1_L1 as list of int init [
    0,
    32,
    64,
    96,
    128,
    160,
    192,
    224,
    256,
    288,
    320,
    352,
    384,
    416,
    448,
    0
];
def const BITRATES_V1_L2 as list of int init [
    0,
    32,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    160,
    192,
    224,
    256,
    320,
    384,
    0
];
def const BITRATES_V1_L3 as list of int init [
    0,
    32,
    40,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    160,
    192,
    224,
    256,
    320,
    0
];
def const BITRATES_V2_L1 as list of int init [
    0,
    32,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    144,
    160,
    176,
    192,
    224,
    256,
    0
];
def const BITRATES_V2_L23 as list of int init [
    0,
    8,
    16,
    24,
    32,
    40,
    48,
    56,
    64,
    80,
    96,
    112,
    128,
    144,
    160,
    0
];

# Sampling rates in Hz, indexed by the header's two-bit field. Index 3 is
# reserved and stored as 0.
def const RATES_V1 as list of int init [44100, 48000, 32000, 0];
def const RATES_V2 as list of int init [22050, 24000, 16000, 0];
def const RATES_V25 as list of int init [11025, 12000, 8000, 0];

/**
 * Whether a valid frame header starts at `offset`.
 *
 * Checks the eleven-bit sync word and rejects every reserved encoding the
 * standard defines: version 01, layer 00, bitrate index 0 or 15, and
 * sampling-rate index 3. That is the whole of what a four-byte header can be
 * validated against on its own - a run of audio data can still spell one by
 * chance, which is why the scanners confirm a candidate by following it to
 * the next frame.
 *
 * @param data {bytes} the buffer to look in
 * @param offset {int} where to look
 * @return {bool} true when four readable bytes there form a legal header
 */
func isFrameHeaderAt(data as bytes, offset as int) {
    if ($offset < 0 or $offset + 4 > len($data)) {
        return false;
    }
    if ($data[$offset] != 0xff) {
        return false;
    }
    def b1 as int init $data[$offset + 1];
    if (($b1 & 0xe0) != 0xe0) {
        return false;
    }
    if (($b1 & 0x18) == 0x08) {
        return false;
    }
    if (($b1 & 0x06) == 0x00) {
        return false;
    }
    def b2 as int init $data[$offset + 2];
    def bitrateIndex as int init ($b2 & 0xf0) >> 4;
    if ($bitrateIndex == 0 or $bitrateIndex == 15) {
        return false;
    }
    return (($b2 & 0x0c) >> 2) != 3;
}

/**
 * Decode the frame header at `offset`.
 *
 * @param data {bytes} the buffer to read
 * @param offset {int} where the header starts
 * @return {FrameHeader} the decoded header, with `frameSize` filled in
 * @throws {Error} when there is no legal header at `offset`
 * @example
 *   def h as mp3.FrameHeader init mp3.parseFrameHeader($data, $start);
 *   io.printf("%d kbit/s, %d Hz\n", $h.bitrate // 1000, $h.sampleRate);
 */
export func parseFrameHeader(data as bytes, offset as int) {
    if (not isFrameHeaderAt($data, $offset)) {
        fail("no MPEG audio frame header at offset " + convert.toString($offset));
    }
    def b1 as int init $data[$offset + 1];
    def b2 as int init $data[$offset + 2];
    def b3 as int init $data[$offset + 3];

    def version as MpegVersion init versionOf(($b1 & 0x18) >> 3);
    def layer as Layer init layerOf(($b1 & 0x06) >> 1);
    def rate as int init sampleRateOf($version, ($b2 & 0x0c) >> 2);
    def kbps as int init bitrateOf($version, $layer, ($b2 & 0xf0) >> 4);
    def mode as ChannelMode init channelModeOf(($b3 & 0xc0) >> 6);
    def pad as bool init ($b2 & 0x02) != 0;
    def samples as int init samplesPerFrame($version, $layer);

    def header as FrameHeader init FrameHeader{
        offset: $offset,
        version: $version,
        layer: $layer,
        bitrate: $kbps * 1000,
        sampleRate: $rate,
        channelMode: $mode,
        channels: channelsOf($mode),
        modeExtension: ($b3 & 0x30) >> 4,
        padding: $pad,
        crc: ($b1 & 0x01) == 0,
        copyright: ($b3 & 0x08) != 0,
        original: ($b3 & 0x04) != 0,
        emphasis: $b3 & 0x03,
        frameSize: 0,
        samples: $samples
    };
    $header.frameSize = frameSizeOf($header);
    return $header;
}

/**
 * The MPEG generation a version field names.
 *
 * @param bits {int} the two-bit version field
 * @return {MpegVersion} the generation
 * @throws {Error} on the reserved encoding 01
 */
func versionOf(bits as int) {
    if ($bits == 0) {
        return MpegVersion.Mpeg25;
    }
    if ($bits == 2) {
        return MpegVersion.Mpeg2;
    }
    if ($bits == 3) {
        return MpegVersion.Mpeg1;
    }
    fail("reserved MPEG version field");
    return MpegVersion.Mpeg1;
}

/**
 * The layer a layer field names.
 *
 * @param bits {int} the two-bit layer field
 * @return {Layer} the layer
 * @throws {Error} on the reserved encoding 00
 */
func layerOf(bits as int) {
    if ($bits == 1) {
        return Layer.LayerIII;
    }
    if ($bits == 2) {
        return Layer.LayerII;
    }
    if ($bits == 3) {
        return Layer.LayerI;
    }
    fail("reserved MPEG layer field");
    return Layer.LayerIII;
}

/**
 * The channel mode a mode field names.
 *
 * @param bits {int} the two-bit channel-mode field
 * @return {ChannelMode} the mode
 */
func channelModeOf(bits as int) {
    if ($bits == 0) {
        return ChannelMode.Stereo;
    }
    if ($bits == 1) {
        return ChannelMode.JointStereo;
    }
    if ($bits == 2) {
        return ChannelMode.DualChannel;
    }
    return ChannelMode.Mono;
}

/**
 * How many channels a mode carries.
 *
 * @param mode {ChannelMode} the frame's channel mode
 * @return {int} 1 for mono, 2 for the three stereo modes
 */
func channelsOf(mode as ChannelMode) {
    match ($mode) {
        when Mono { return 1; }
        else { return 2; }
    }
}

/**
 * The sampling rate an index names, for this MPEG generation.
 *
 * @param version {MpegVersion} the MPEG generation
 * @param index {int} the two-bit sampling-rate field
 * @return {int} samples per second
 * @throws {Error} on the reserved index 3
 */
func sampleRateOf(version as MpegVersion, index as int) {
    def table as list of int init RATES_V1;
    match ($version) {
        when Mpeg1 { $table = RATES_V1; }
        when Mpeg2 { $table = RATES_V2; }
        when Mpeg25 { $table = RATES_V25; }
    }
    def rate as int init $table[$index];
    if ($rate == 0) {
        fail("reserved MPEG sampling-rate field");
    }
    return $rate;
}

/**
 * The bitrate an index names, for this generation and layer.
 *
 * @param version {MpegVersion} the MPEG generation
 * @param layer {Layer} the layer
 * @param index {int} the four-bit bitrate field
 * @return {int} kilobits per second
 * @throws {Error} on the free-format index 0 or the invalid index 15
 */
func bitrateOf(version as MpegVersion, layer as Layer, index as int) {
    def table as list of int init BITRATES_V1_L3;
    def isV1 as bool init false;
    match ($version) {
        when Mpeg1 { $isV1 = true; }
        else {
        }
    }
    if ($isV1) {
        match ($layer) {
            when LayerI { $table = BITRATES_V1_L1; }
            when LayerII { $table = BITRATES_V1_L2; }
            when LayerIII { $table = BITRATES_V1_L3; }
        }
    } else {
        match ($layer) {
            when LayerI { $table = BITRATES_V2_L1; }
            else { $table = BITRATES_V2_L23; }
        }
    }
    def kbps as int init $table[$index];
    if ($kbps == 0) {
        fail("free-format or invalid MPEG bitrate field");
    }
    return $kbps;
}

/**
 * How many PCM samples per channel one frame decodes to.
 *
 * Fixed per layer, except that MPEG-2 and MPEG-2.5 halve Layer III.
 *
 * @param version {MpegVersion} the MPEG generation
 * @param layer {Layer} the layer
 * @return {int} 384, 576 or 1152
 */
func samplesPerFrame(version as MpegVersion, layer as Layer) {
    match ($layer) {
        when LayerI { return 384; }
        when LayerII { return 1152; }
        when LayerIII { return layer3Samples($version); }
    }
}

/**
 * How many samples a Layer III frame carries in this generation.
 *
 * @param version {MpegVersion} the MPEG generation
 * @return {int} 1152 on MPEG-1, 576 on MPEG-2 and MPEG-2.5
 */
func layer3Samples(version as MpegVersion) {
    match ($version) {
        when Mpeg1 { return 1152; }
        else { return 576; }
    }
}

/**
 * How long a frame is on disk, in bytes.
 *
 * Layer I counts in four-byte slots and divides before it multiplies, so it
 * cannot share the Layer II / III expression.
 *
 * @param header {FrameHeader} a header with everything but `frameSize` set
 * @return {int} the whole frame in bytes, header included
 */
func frameSizeOf(header as FrameHeader) {
    def pad as int init 0;
    if ($header.padding) {
        $pad = 1;
    }
    def isLayer1 as bool init false;
    match ($header.layer) {
        when LayerI { $isLayer1 = true; }
        else {
        }
    }
    if ($isLayer1) {
        def slots as int init (12 * $header.bitrate) // $header.sampleRate;
        return ($slots + $pad) * 4;
    }
    def bytesPerFrame as int init ($header.samples // 8) * $header.bitrate;
    return $bytesPerFrame // $header.sampleRate + $pad;
}

/**
 * How many bytes of side information follow the header.
 *
 * The Xing and Info headers sit immediately after it, so this is where a
 * reader looks for them.
 *
 * @param header {FrameHeader} the frame header
 * @return {int} 9, 17 or 32 bytes
 */
func sideInfoSize(header as FrameHeader) {
    def isV1 as bool init false;
    match ($header.version) {
        when Mpeg1 { $isV1 = true; }
        else {
        }
    }
    if ($isV1) {
        if ($header.channels == 1) {
            return 17;
        }
        return 32;
    }
    if ($header.channels == 1) {
        return 9;
    }
    return 17;
}

/**
 * Find the next byte that could start a frame header.
 *
 * Scans for the sync byte with `binary.indexOf`, which runs the search in Go,
 * and validates each hit. A candidate is only accepted when the frame it
 * claims is followed by another legal header, which rejects the `ff ex` byte
 * pairs that turn up inside audio data and inside artwork.
 *
 * @param data {bytes} the buffer to search
 * @param from {int} where to start looking
 * @param limit {int} one past the last offset a header may start at
 * @return {int} the offset of the header, or `-1` when there is none
 */
func findFrameHeader(data as bytes, from as int, limit as int) {
    def needle as bytes init binary.make(1, 0xff);
    def size as int init len($data);
    def stop as int init $limit;
    if ($stop > $size) {
        $stop = $size;
    }
    def at as int init $from;
    if ($at < 0) {
        $at = 0;
    }
    while ($at < $stop) {
        def hit as int init binary.indexOf($data, $needle, $at);
        if ($hit < 0 or $hit >= $stop) {
            return -1;
        }
        if (isFrameHeaderAt($data, $hit) and chainHolds($data, $hit, 2)) {
            return $hit;
        }
        $at = $hit + 1;
    }
    return -1;
}

/**
 * Whether `count` further frames follow the one at `offset`.
 *
 * A frame that runs off the end of the buffer counts as holding: the last
 * frame of a truncated file is still a frame.
 *
 * @param data {bytes} the buffer
 * @param offset {int} where the first frame starts
 * @param count {int} how many following frames to confirm
 * @return {bool} true when the chain holds for `count` frames
 */
func chainHolds(data as bytes, offset as int, count as int) {
    def at as int init $offset;
    def size as int init len($data);
    for (def i as int init 0; $i < $count; $i = $i + 1) {
        if (not isFrameHeaderAt($data, $at)) {
            return false;
        }
        def header as FrameHeader init parseFrameHeader($data, $at);
        $at = $at + $header.frameSize;
        if ($at >= $size) {
            return true;
        }
    }
    return true;
}

/**
 * The name of an MPEG generation.
 *
 * @param version {MpegVersion} the generation
 * @return {string} `"MPEG-1"`, `"MPEG-2"` or `"MPEG-2.5"`
 */
export func versionName(version as MpegVersion) {
    match ($version) {
        when Mpeg1 { return "MPEG-1"; }
        when Mpeg2 { return "MPEG-2"; }
        when Mpeg25 { return "MPEG-2.5"; }
    }
}

/**
 * The name of an MPEG audio layer.
 *
 * @param layer {Layer} the layer
 * @return {string} `"Layer I"`, `"Layer II"` or `"Layer III"`
 */
export func layerName(layer as Layer) {
    match ($layer) {
        when LayerI { return "Layer I"; }
        when LayerII { return "Layer II"; }
        when LayerIII { return "Layer III"; }
    }
}

/**
 * The name of a channel mode.
 *
 * @param mode {ChannelMode} the mode
 * @return {string} `"stereo"`, `"joint stereo"`, `"dual channel"` or `"mono"`
 */
export func channelModeName(mode as ChannelMode) {
    match ($mode) {
        when Stereo { return "stereo"; }
        when JointStereo { return "joint stereo"; }
        when DualChannel { return "dual channel"; }
        when Mono { return "mono"; }
    }
}
