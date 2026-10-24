<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The audio stream

Between the tags is a sequence of MPEG audio frames, each opening with a
four-byte header. `readAudio(data, start, end)` describes the stream between
two offsets; `parse` and `open` call it for you and put the result in
`track.audio`.

```jennifer
def info as mp3.AudioInfo init mp3.readAudio($data, 0, len($data));

$info.present;                            # whether any frame was found
mp3.versionName($info.version);           # "MPEG-1"
mp3.layerName($info.layer);               # "Layer III"
$info.sampleRate;                         # 44100
mp3.channelModeName($info.channelMode);   # "stereo"
```

Version, layer, channel mode, channel count and sampling rate come from the
first frame. `end` is clamped to the buffer length.

## One frame

```jennifer
def h as mp3.FrameHeader init mp3.parseFrameHeader($data, $offset);
$h.frameSize;    # bytes, header included
$h.samples;      # PCM samples per channel
$h.channels;     # mono is 1, stereo 2
$h.bitrate;      # bits per second
```

`parseFrameHeader` throws when there is no legal header at `offset`: no sync
word, version `01`, layer `00`, bitrate index 0 (free format) or 15, or
sampling-rate index 3. Bit layout and tables:
[the MPEG frame header](../reference/mpeg.md).

## Finding the first frame

The audio need not start right after the ID3v2 tag, and some files have no
tag. The scanner searches for the sync byte and accepts a candidate only
when the frame after it also starts with a legal header, which rejects `ff ex`
byte pairs inside audio data or embedded artwork. A frame that runs past the
end of the buffer still counts, so a truncated file is found.

```jennifer
$info.offset;   # where the first frame starts
$info.length;   # bytes from there to end
```

## Duration

`durationMs` comes from one of three sources, in order:

1. a Xing, Info or VBRI header that states a frame count: exact;
2. otherwise, with scanning on (the default), a walk over every frame:
   exact;
3. otherwise, the stream length divided by the first frame's bitrate: an
   estimate.

`exact` is true for the first two. Use it before trusting `durationMs` on a
variable-bitrate file.

```jennifer
$info.frames;       # frame count; 0 when not known
$info.durationMs;
$info.exact;
mp3.formatDuration($info.durationMs);   # "3:34"
```

`formatDuration` gives `m:ss`, or `h:mm:ss` from one hour; seconds are
truncated and a negative value prints as `0:00`.

`readAudioWith(data, start, end, false)` and `parseWith(data, false)` skip
the frame walk:

```jennifer
def quick as mp3.AudioInfo init mp3.readAudioWith($data, 0, len($data), false);
$quick.exact;   # false unless a VBR header states the frame count
```

The estimate can be far off on a VBR file without a header: if the first
frame is a quiet, low-bitrate one, the estimate can be twice the real
length.

## Bitrate and VBR

`bitrate` is the first frame's bitrate for a constant-bitrate stream, and the
measured average (stream bytes over duration) for a variable one. A CBR
stream keeps the declared value because dividing its size by its duration
gives a few hundred bits per second less: frame sizes are floor divisions.

`vbr` is true when the stream has a `Xing` or `VBRI` header, or when the
frame walk saw the bitrate index change. An `Info` header marks a CBR file
and does not set it.

## Xing, Info and VBRI

Encoders write the frame count into a first frame that decodes to silence.

| Identifier | Means | Where |
|---|---|---|
| `Xing` | variable bitrate | after the frame header and side information |
| `Info` | the same structure, constant bitrate | the same place |
| `VBRI` | Fraunhofer's format | 32 bytes after the 4-byte frame header |

```jennifer
$info.vbrHeader.kind;         # "Xing", "Info", "VBRI" or ""
$info.vbrHeader.frames;       # frame count; 0 when not stated
$info.vbrHeader.streamBytes;  # audio bytes; 0 when not stated
$info.vbrHeader.quality;      # the encoder quality, or -1 when not stated
$info.vbrHeader.hasToc;       # whether a seek table is present
```

A Xing header's flag bits select which of its four optional fields follow.
A truncated header keeps the fields read before the end. Layouts are in
[the MPEG frame header](../reference/mpeg.md#xing-and-info).

## Cost

The frame walk is the deck's hot loop: one table lookup and one comparison
per frame, with no function call. In profiling on a five-megabyte file the
walk took 83 ms before this, and a version that called one small helper per
frame spent a fifth of that on call overhead. Skip the walk with
`parseWith($data, false)` when bulk-reading a library where an estimate is
enough.
