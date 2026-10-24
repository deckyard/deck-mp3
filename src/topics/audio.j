# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - what the MPEG frame stream itself says: duration, bitrate, VBR.
# Spliced into mp3.j via include - not a standalone module.

/** The frame count an encoder-written VBR header states, when it states one. */
def const VBR_FLAG_FRAMES as int init 1;

/** The stream size in bytes a Xing header states, when it states one. */
def const VBR_FLAG_BYTES as int init 2;

/** The 100-byte seek table a Xing header carries, when it carries one. */
def const VBR_FLAG_TOC as int init 4;

/** The encoder quality a Xing header states, when it states one. */
def const VBR_FLAG_QUALITY as int init 8;

/**
 * The encoder-written header that opens a variable-bitrate stream.
 *
 * Encoders write the frame count into a first frame that decodes to
 * silence: `Xing` for variable bitrate, `Info` for the same structure in a
 * constant-bitrate file, or Fraunhofer's `VBRI`.
 *
 * @field kind {string} `"Xing"`, `"Info"`, `"VBRI"`, or `""` when the stream
 *     carries no such header
 * @field frames {int} how many frames the stream holds, or `0` when unstated
 * @field streamBytes {int} how many bytes of audio, or `0` when unstated
 * @field quality {int} the encoder quality 0-100, or `-1` when unstated
 * @field hasToc {bool} whether a seek table follows
 */
export def struct VbrHeader {
    kind as string,
    frames as int,
    streamBytes as int,
    quality as int,
    hasToc as bool
};

/**
 * Everything the audio stream itself says about a file.
 *
 * `exact` is the field to read before trusting `durationMs`: it is true when
 * the frame count came from a VBR header or from counting every frame, and
 * false when it was estimated by dividing the stream size by the first
 * frame's bitrate.
 *
 * @field present {bool} whether any MPEG audio frame was found at all
 * @field offset {int} where the first frame starts in the file
 * @field length {int} how many bytes of audio follow it
 * @field version {MpegVersion} the generation the first frame was coded to
 * @field layer {Layer} the layer the first frame was coded to
 * @field channelMode {ChannelMode} the first frame's channel mode
 * @field channels {int} 1 or 2
 * @field sampleRate {int} samples per second
 * @field bitrate {int} bits per second: declared for CBR, measured average for VBR
 * @field vbr {bool} whether a `Xing` or `VBRI` header is present or the frame
 *     walk saw the bitrate change
 * @field vbrHeader {VbrHeader} the encoder-written header, if any
 * @field frames {int} how many frames the stream holds, or `0` when unknown
 * @field durationMs {int} how long the stream plays, in milliseconds
 * @field exact {bool} whether `frames` and `durationMs` were measured
 */
export def struct AudioInfo {
    present as bool,
    offset as int,
    length as int,
    version as MpegVersion,
    layer as Layer,
    channelMode as ChannelMode,
    channels as int,
    sampleRate as int,
    bitrate as int,
    vbr as bool,
    vbrHeader as VbrHeader,
    frames as int,
    durationMs as int,
    exact as bool
};

/**
 * What counting the frames of a stream found.
 *
 * @field frames {int} how many frames were walked
 * @field samples {int} how many PCM samples per channel they decode to
 * @field bytes {int} how many bytes the walked frames occupy
 * @field vbr {bool} whether the bitrate field changed between frames
 */
def struct FrameScan {
    frames as int,
    samples as int,
    bytes as int,
    vbr as bool
};

/**
 * Analyse the MPEG audio between two offsets.
 *
 * Walks every frame when no VBR header states the frame count, which is the
 * only way to an exact duration for a VBR file without one. Use
 * {@link readAudioWith} to skip the walk. `end` is clamped to `len(data)`.
 *
 * @param data {bytes} the whole file
 * @param start {int} where the audio may begin, past any ID3v2 tag
 * @param end {int} one past the last audio byte, before any ID3v1 tag
 * @return {AudioInfo} what the stream says; `present` is false when no frame
 *     was found
 * @example
 *   def info as mp3.AudioInfo init mp3.readAudio($data, 0, len($data));
 *   io.printf("%d kbit/s %s\n", $info.bitrate // 1000,
 *       mp3.channelModeName($info.channelMode));
 */
export func readAudio(data as bytes, start as int, end as int) {
    return readAudioWith($data, $start, $end, true);
}

/**
 * Analyse the MPEG audio, choosing whether to count every frame.
 *
 * With `scan` false and no VBR header, `durationMs` is the stream size
 * divided by the first frame's bitrate and `exact` comes back false. An
 * encoder-written VBR header is read either way, and makes the answer exact
 * without any scanning.
 *
 * @param data {bytes} the whole file
 * @param start {int} where the audio may begin, past any ID3v2 tag
 * @param end {int} one past the last audio byte, before any ID3v1 tag
 * @param scan {bool} whether to walk the frame chain when no VBR header says
 *     how long the stream is
 * @return {AudioInfo} what the stream says
 */
export func readAudioWith(data as bytes, start as int, end as int, scan as bool) {
    def info as AudioInfo;
    $info.vbrHeader = emptyVbrHeader();
    def stop as int init $end;
    if ($stop > len($data)) {
        $stop = len($data);
    }
    def first as int init findFrameHeader($data, $start, $stop);
    if ($first < 0) {
        return $info;
    }
    def header as FrameHeader init parseFrameHeader($data, $first);
    def vbrHeader as VbrHeader init readVbrHeader($data, $header);

    $info.present = true;
    $info.offset = $first;
    $info.length = $stop - $first;
    $info.version = $header.version;
    $info.layer = $header.layer;
    $info.channelMode = $header.channelMode;
    $info.channels = $header.channels;
    $info.sampleRate = $header.sampleRate;
    $info.bitrate = $header.bitrate;
    $info.vbrHeader = $vbrHeader;
    $info.vbr = $vbrHeader.kind == "Xing" or $vbrHeader.kind == "VBRI";

    if ($vbrHeader.frames > 0) {
        return finishFromVbrHeader($info, $header, $vbrHeader);
    }
    if ($scan) {
        return finishFromScan($info, $data, $header, $stop);
    }
    $info.durationMs = durationFromBitrate($info.length, $header.bitrate);
    return $info;
}

/**
 * Fill in the duration from an encoder-written frame count.
 *
 * A constant-bitrate stream keeps the bitrate its frames declare; only a
 * variable-bitrate one gets an average, because dividing a CBR stream's size
 * by its duration lands a few hundred bits under the declared rate.
 *
 * @param info {AudioInfo} the partly filled result
 * @param header {FrameHeader} the first frame's header
 * @param vbrHeader {VbrHeader} the encoder-written header
 * @return {AudioInfo} a fresh value with the counted fields set
 */
func finishFromVbrHeader(info as AudioInfo, header as FrameHeader, vbrHeader as VbrHeader) {
    def out as AudioInfo init $info;
    def streamBytes as int init $vbrHeader.streamBytes;
    if ($streamBytes <= 0 or $streamBytes > $out.length) {
        $streamBytes = $out.length;
    }
    $out.frames = $vbrHeader.frames;
    $out.durationMs = durationFromSamples($vbrHeader.frames * $header.samples, $header.sampleRate);
    if ($out.vbr) {
        $out.bitrate = averageBitrate($streamBytes, $out.durationMs, $header.bitrate);
    }
    $out.exact = true;
    return $out;
}

/**
 * Fill in the duration by walking every frame of the stream.
 *
 * @param info {AudioInfo} the partly filled result
 * @param data {bytes} the whole file
 * @param header {FrameHeader} the first frame's header
 * @param stop {int} one past the last audio byte
 * @return {AudioInfo} a fresh value with the counted fields set
 */
func finishFromScan(info as AudioInfo, data as bytes, header as FrameHeader, stop as int) {
    def out as AudioInfo init $info;
    def scan as FrameScan init countFrames($data, $header, $stop);
    if ($scan.frames == 0) {
        $out.durationMs = durationFromBitrate($out.length, $header.bitrate);
        return $out;
    }
    $out.frames = $scan.frames;
    $out.vbr = $out.vbr or $scan.vbr;
    $out.durationMs = durationFromSamples($scan.samples, $header.sampleRate);
    if ($out.vbr) {
        $out.bitrate = averageBitrate($scan.bytes, $out.durationMs, $header.bitrate);
    }
    $out.exact = true;
    return $out;
}

/**
 * Walk the frame chain from the first frame to the end of the audio.
 *
 * Table-driven: the frame size is a lookup in a 256-entry table keyed by the
 * header's third byte (see {@link frameSizeByByte}), and one comparison of a
 * shape word rejects anything that is not a frame of the stream's shape. A
 * legal frame of a different shape rebuilds the table instead of being
 * mis-sized. A bitrate index that differs from the first frame's sets `vbr`.
 *
 * @param data {bytes} the whole file
 * @param first {FrameHeader} the first frame's header
 * @param stop {int} one past the last audio byte
 * @return {FrameScan} the counts; `frames` is 0 when the chain broke at once
 */
func countFrames(data as bytes, first as FrameHeader, stop as int) {
    def rateBits as int init $data[$first.offset + 2] & 0x0c;
    def sizes as list of int init frameSizeByByte($first, $rateBits);
    def shape as int init frameShapeAt($data, $first.offset);
    def samplesEach as int init $first.samples;
    def firstIndex as int init $data[$first.offset + 2] & 0xf0;

    def frames as int init 0;
    def samples as int init 0;
    def vbr as bool init false;
    def at as int init $first.offset;

    # This is the one loop in the deck that runs millions of times on a real
    # library, and `jennifer profile` charges it per statement, so it is
    # written flat and short rather than factored. The shape word carries the
    # sync bits as well as the version, layer and sampling rate, so one
    # comparison rejects everything that is not a frame of the stream's own
    # shape; `sizes` is keyed by the whole third byte, so the bitrate index,
    # the sampling-rate check and the padding slot are one lookup.
    while ($at + 4 <= $stop) {
        def b2 as int init $data[$at + 2];
        def shapeHere as int init (($data[$at + 1] & 0xfe) << 8) | ($b2 & 0x0c);
        if ($shapeHere != $shape or $data[$at] != 0xff) {
            if (not isFrameHeaderAt($data, $at)) {
                break;
            }
            def changed as FrameHeader init parseFrameHeader($data, $at);
            $sizes = frameSizeByByte($changed, $b2 & 0x0c);
            $shape = frameShapeAt($data, $at);
            $samplesEach = $changed.samples;
        }
        def size as int init $sizes[$b2];
        if ($size == 0) {
            break;
        }
        if (($b2 & 0xf0) != $firstIndex) {
            $vbr = true;
        }
        $frames = $frames + 1;
        $samples = $samples + $samplesEach;
        $at = $at + $size;
    }
    return FrameScan{frames: $frames, samples: $samples, bytes: $at - $first.offset, vbr: $vbr};
}

/**
 * The header bits that must hold constant for a frame-size table to apply.
 *
 * The three sync bits of the second byte, the version, the layer and the
 * sampling rate, in one integer. The sync bits ride along so that the one
 * comparison the frame walk makes per frame rejects a byte that is not a
 * header as well as a frame of a different shape. The protection bit is left
 * out: it is allowed to vary frame to frame and does not change the size.
 *
 * @param data {bytes} the buffer
 * @param offset {int} where the header starts
 * @return {int} the packed shape, or `-1` when four bytes cannot be read
 */
func frameShapeAt(data as bytes, offset as int) {
    if ($offset < 0 or $offset + 4 > len($data)) {
        return -1;
    }
    return (($data[$offset + 1] & 0xfe) << 8) | ($data[$offset + 2] & 0x0c);
}

/**
 * Unpadded frame sizes for every bitrate index, for one stream shape.
 *
 * Index 0 and 15 are the free-format and invalid encodings and come back as
 * `0`, which the scanner treats as the end of the chain.
 *
 * @param header {FrameHeader} a frame of the shape to tabulate
 * @return {list of int} sixteen frame sizes in bytes
 */
func frameSizeTable(header as FrameHeader) {
    def sizes as list of int init [];
    def shaped as FrameHeader init $header;
    $shaped.padding = false;
    for (def index as int init 0; $index < 16; $index = $index + 1) {
        if ($index == 0 or $index == 15) {
            $sizes[] = 0;
            continue;
        }
        $shaped.bitrate = bitrateOf($header.version, $header.layer, $index) * 1000;
        $sizes[] = frameSizeOf($shaped);
    }
    return $sizes;
}

/**
 * Frame sizes keyed by the whole third header byte.
 *
 * The third byte carries the bitrate index, the sampling-rate index and the
 * padding bit, which between them are everything the size depends on. A
 * 256-entry table built once per stream therefore turns the per-frame work
 * into a single lookup - no shift, no second table, no branch on the padding
 * bit.
 *
 * An entry is `0` wherever the stream cannot legally go: a free-format or
 * invalid bitrate index, or a sampling rate other than the one the table was
 * built for. The frame walk reads a `0` as the end of the chain, so a stream
 * that changes rate stops the walk and is re-tabulated rather than
 * mis-sized.
 *
 * @param header {FrameHeader} a frame of the shape to tabulate
 * @param rateBits {int} the sampling-rate bits of that frame's third byte
 * @return {list of int} 256 frame sizes in bytes
 */
func frameSizeByByte(header as FrameHeader, rateBits as int) {
    def base as list of int init frameSizeTable($header);
    def slot as int init slotSizeOf($header);
    def sizes as list of int init [];
    for (def b as int init 0; $b < 256; $b = $b + 1) {
        if (($b & 0x0c) != $rateBits) {
            $sizes[] = 0;
            continue;
        }
        def size as int init $base[($b & 0xf0) >> 4];
        if ($size != 0 and ($b & 0x02) != 0) {
            $size = $size + $slot;
        }
        $sizes[] = $size;
    }
    return $sizes;
}

/**
 * How many bytes the padding bit adds to a frame.
 *
 * @param header {FrameHeader} the frame header
 * @return {int} 4 on Layer I, 1 on Layer II and III
 */
func slotSizeOf(header as FrameHeader) {
    match ($header.layer) {
        when LayerI { return 4; }
        else { return 1; }
    }
}

/**
 * Read the encoder-written VBR header out of the first frame, if there is one.
 *
 * `Xing` and `Info` follow the frame's side information; Fraunhofer's `VBRI`
 * is at a fixed 32 bytes after the four-byte header.
 *
 * @param data {bytes} the whole file
 * @param header {FrameHeader} the first frame's header
 * @return {VbrHeader} the header, or an empty one with `kind` `""`
 */
func readVbrHeader(data as bytes, header as FrameHeader) {
    def xingAt as int init $header.offset + 4 + sideInfoSize($header);
    if (magicAt($data, $xingAt, "Xing")) {
        return readXing($data, $xingAt, "Xing");
    }
    if (magicAt($data, $xingAt, "Info")) {
        return readXing($data, $xingAt, "Info");
    }
    def vbriAt as int init $header.offset + 4 + 32;
    if (magicAt($data, $vbriAt, "VBRI")) {
        return readVbri($data, $vbriAt);
    }
    return emptyVbrHeader();
}

/**
 * A VBR header that states nothing.
 *
 * @return {VbrHeader} `kind` `""`, no counts, quality `-1`
 */
func emptyVbrHeader() {
    return VbrHeader{kind: "", frames: 0, streamBytes: 0, quality: -1, hasToc: false};
}

/**
 * Read a Xing or Info header.
 *
 * Four flag bits say which of the four optional fields follow, in a fixed
 * order. A truncated header stops the read rather than throwing: what was
 * present is kept.
 *
 * @param data {bytes} the whole file
 * @param offset {int} where the four-character identifier starts
 * @param kind {string} `"Xing"` or `"Info"`
 * @return {VbrHeader} what the header stated
 */
func readXing(data as bytes, offset as int, kind as string) {
    def out as VbrHeader init emptyVbrHeader();
    $out.kind = $kind;
    if ($offset + 8 > len($data)) {
        return $out;
    }
    def flags as int init beUint32($data, $offset + 4);
    def at as int init $offset + 8;
    def size as int init len($data);
    if (($flags & VBR_FLAG_FRAMES) != 0) {
        if ($at + 4 > $size) {
            return $out;
        }
        $out.frames = beUint32($data, $at);
        $at = $at + 4;
    }
    if (($flags & VBR_FLAG_BYTES) != 0) {
        if ($at + 4 > $size) {
            return $out;
        }
        $out.streamBytes = beUint32($data, $at);
        $at = $at + 4;
    }
    if (($flags & VBR_FLAG_TOC) != 0) {
        if ($at + 100 > $size) {
            return $out;
        }
        $out.hasToc = true;
        $at = $at + 100;
    }
    if (($flags & VBR_FLAG_QUALITY) != 0) {
        if ($at + 4 > $size) {
            return $out;
        }
        $out.quality = beUint32($data, $at);
    }
    return $out;
}

/**
 * Read a Fraunhofer VBRI header.
 *
 * Fixed layout, no flags: version, delay and quality as 16-bit fields, then
 * the stream size and frame count as 32-bit ones.
 *
 * @param data {bytes} the whole file
 * @param offset {int} where the four-character identifier starts
 * @return {VbrHeader} what the header stated
 */
func readVbri(data as bytes, offset as int) {
    def out as VbrHeader init emptyVbrHeader();
    $out.kind = "VBRI";
    if ($offset + 26 > len($data)) {
        return $out;
    }
    $out.quality = beUint16($data, $offset + 8);
    $out.streamBytes = beUint32($data, $offset + 10);
    $out.frames = beUint32($data, $offset + 14);
    $out.hasToc = beUint16($data, $offset + 18) > 0;
    return $out;
}

/**
 * How long a count of PCM samples plays, in milliseconds.
 *
 * @param samples {int} total samples per channel
 * @param sampleRate {int} samples per second
 * @return {int} milliseconds, rounded to nearest
 */
func durationFromSamples(samples as int, sampleRate as int) {
    if ($sampleRate <= 0 or $samples <= 0) {
        return 0;
    }
    return ($samples * 1000 + $sampleRate // 2) // $sampleRate;
}

/**
 * How long a constant-bitrate stream of this size plays, in milliseconds.
 *
 * @param streamBytes {int} how many bytes of audio
 * @param bitrate {int} bits per second
 * @return {int} milliseconds, rounded to nearest
 */
func durationFromBitrate(streamBytes as int, bitrate as int) {
    if ($bitrate <= 0 or $streamBytes <= 0) {
        return 0;
    }
    return ($streamBytes * 8000 + $bitrate // 2) // $bitrate;
}

/**
 * The average bitrate of a stream of known size and duration.
 *
 * @param streamBytes {int} how many bytes of audio
 * @param durationMs {int} how long it plays
 * @param fallback {int} the bitrate to report when the duration is unknown
 * @return {int} bits per second
 */
func averageBitrate(streamBytes as int, durationMs as int, fallback as int) {
    if ($durationMs <= 0 or $streamBytes <= 0) {
        return $fallback;
    }
    return ($streamBytes * 8000) // $durationMs;
}

/**
 * A duration in milliseconds as `h:mm:ss` or `m:ss`.
 *
 * The hour field appears from one hour. Seconds are truncated; a negative
 * duration gives `"0:00"`.
 *
 * @param durationMs {int} the duration
 * @return {string} the formatted duration; `"0:00"` for nothing
 * @example
 *   mp3.formatDuration(214000);    # "3:34"
 *   mp3.formatDuration(3754000);   # "1:02:34"
 */
export func formatDuration(durationMs as int) {
    def total as int init $durationMs // 1000;
    if ($total < 0) {
        $total = 0;
    }
    def seconds as int init $total % 60;
    def minutes as int init ($total // 60) % 60;
    def hours as int init $total // 3600;
    def tail as string init io.sprintf("%d|pad=2|fill=0", $seconds);
    if ($hours == 0) {
        return convert.toString($minutes) + ":" + $tail;
    }
    def mid as string init io.sprintf("%d|pad=2|fill=0", $minutes);
    return convert.toString($hours) + ":" + $mid + ":" + $tail;
}
