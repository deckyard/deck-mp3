#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * audio example - what the MPEG stream itself says.
 *
 * Frame header fields, and the duration: stated by a Xing or VBRI header,
 * counted frame by frame, or estimated from the bitrate.
 *
 *   jennifer run examples/audio.j
 */

use io;
use binary;
use convert;

import "../src/mp3.j" as mp3;

# Build a frame: `index` selects the bitrate out of the MPEG-1 Layer III
# table, so a stream of frames at different indices is a VBR stream.
func frameAt(index as int) {
    def head as bytes;
    $head[] = 0xff;
    $head[] = 0xfb;
    $head[] = ($index << 4);
    $head[] = 0x00;
    def first as mp3.FrameHeader init mp3.parseFrameHeader($head, 0);
    def parts as list of bytes init [];
    $parts[] = $head;
    $parts[] = binary.make($first.frameSize - 4, 0);
    return binary.join($parts);
}

func describeStream(label as string, data as bytes) {
    def info as mp3.AudioInfo init mp3.readAudio($data, 0, len($data));
    io.printf("%s\n", $label);
    io.printf(
        "  %s %s, %d Hz, %s\n",
        mp3.versionName($info.version),
        mp3.layerName($info.layer),
        $info.sampleRate,
        mp3.channelModeName($info.channelMode));
    def rate as string init convert.toString($info.bitrate // 1000) + " kbit/s";
    if ($info.vbr) {
        $rate = $rate + " average, variable";
    }
    io.printf("  %s\n", $rate);
    io.printf(
        "  %d frames, %s, exact: %t\n",
        $info.frames,
        mp3.formatDuration($info.durationMs),
        $info.exact);
    if ($info.vbrHeader.kind != "") {
        io.printf("  %s header states %d frames\n", $info.vbrHeader.kind, $info.vbrHeader.frames);
    }
    io.printf("\n");
}

# -- one frame, read field by field ------------------------------------------

def header as mp3.FrameHeader init mp3.parseFrameHeader(frameAt(9), 0);
io.printf("one frame: %d bytes, %d samples per channel\n", $header.frameSize, $header.samples);
io.printf("  bitrate %d, padding %t, crc %t\n\n", $header.bitrate, $header.padding, $header.crc);

# -- a constant-bitrate stream -----------------------------------------------

def cbrParts as list of bytes init [];
for (def i as int init 0; $i < 200; $i = $i + 1) {
    $cbrParts[] = frameAt(9);
}
describeStream("constant bitrate, 200 frames", binary.join($cbrParts));

# -- a variable-bitrate stream with no header to say how long it is ----------

def vbrParts as list of bytes init [];
for (def i as int init 0; $i < 200; $i = $i + 1) {
    $vbrParts[] = frameAt(5 + ($i % 8));
}
describeStream("variable bitrate, counted frame by frame", binary.join($vbrParts));

# -- the same bytes, without the frame walk ----------------------------------

def vbr as bytes init binary.join($vbrParts);
def estimate as mp3.AudioInfo init mp3.readAudioWith($vbr, 0, len($vbr), false);
def counted as mp3.AudioInfo init mp3.readAudio($vbr, 0, len($vbr));
io.printf(
    "without scanning: %s (exact: %t)\n",
    mp3.formatDuration($estimate.durationMs),
    $estimate.exact);
io.printf(
    "with scanning:    %s (exact: %t)\n",
    mp3.formatDuration($counted.durationMs),
    $counted.exact);
