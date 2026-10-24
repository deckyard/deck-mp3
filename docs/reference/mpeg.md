<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The MPEG frame header

Four bytes open every frame.

```
AAAAAAAA  AAABBCCD  EEEEFFGH  IIJJKLMM
```

| Bits | Field | Meaning |
|---|---|---|
| A (11) | sync | all ones |
| B (2) | version | `00` MPEG-2.5, `01` reserved, `10` MPEG-2, `11` MPEG-1 |
| C (2) | layer | `00` reserved, `01` Layer III, `10` Layer II, `11` Layer I |
| D (1) | protection | `0` means a 16-bit CRC follows the header |
| E (4) | bitrate index | `0` free format, `15` invalid |
| F (2) | sampling rate index | `3` reserved |
| G (1) | padding | the frame carries one extra slot |
| H (1) | private | |
| I (2) | channel mode | `00` stereo, `01` joint, `10` dual, `11` mono |
| J (2) | mode extension | joint stereo only |
| K (1) | copyright | |
| L (1) | original | |
| M (2) | emphasis | |

The protection bit is inverted: `0` means a CRC is present.

The deck treats a header with version `01`, layer `00`, bitrate index 0
(free format) or 15, or sampling-rate index 3 as no header at all.

## Sampling rates, Hz

| Index | MPEG-1 | MPEG-2 | MPEG-2.5 |
|---|---|---|---|
| 0 | 44100 | 22050 | 11025 |
| 1 | 48000 | 24000 | 12000 |
| 2 | 32000 | 16000 | 8000 |
| 3 | reserved | reserved | reserved |

## Bitrates, kbit/s

| Index | V1 L1 | V1 L2 | V1 L3 | V2 L1 | V2 L2/L3 |
|---|---|---|---|---|---|
| 0 | free | free | free | free | free |
| 1 | 32 | 32 | 32 | 32 | 8 |
| 2 | 64 | 48 | 40 | 48 | 16 |
| 3 | 96 | 56 | 48 | 56 | 24 |
| 4 | 128 | 64 | 56 | 64 | 32 |
| 5 | 160 | 80 | 64 | 80 | 40 |
| 6 | 192 | 96 | 80 | 96 | 48 |
| 7 | 224 | 112 | 96 | 112 | 56 |
| 8 | 256 | 128 | 112 | 128 | 64 |
| 9 | 288 | 160 | 128 | 144 | 80 |
| 10 | 320 | 192 | 160 | 160 | 96 |
| 11 | 352 | 224 | 192 | 176 | 112 |
| 12 | 384 | 256 | 224 | 192 | 128 |
| 13 | 416 | 320 | 256 | 224 | 144 |
| 14 | 448 | 384 | 320 | 256 | 160 |
| 15 | invalid | invalid | invalid | invalid | invalid |

MPEG-2.5 uses the MPEG-2 tables.

## Samples per frame

| Layer | MPEG-1 | MPEG-2 and MPEG-2.5 |
|---|---|---|
| I | 384 | 384 |
| II | 1152 | 1152 |
| III | 1152 | 576 |

## Frame length

Layer I counts in four-byte slots and divides before it multiplies:

```
frameSize = (12 * bitrate // sampleRate + padding) * 4
```

Layer II and III count in bytes:

```
frameSize = (samples // 8) * bitrate // sampleRate + padding
```

`bitrate` is bits per second and `padding` is 1 or 0. The divisions are floor
divisions: a 128 kbit/s 44100 Hz Layer III frame is 417 bytes, not 417.96.

## Side information

Bytes between the end of the four-byte header and the Xing or Info
identifier.

| | mono | stereo |
|---|---|---|
| MPEG-1 | 17 | 32 |
| MPEG-2 and MPEG-2.5 | 9 | 17 |

## Xing and Info

At the frame header plus 4 plus the side information size.

| Offset | Length | Field |
|---|---|---|
| 0 | 4 | `Xing` or `Info` |
| 4 | 4 | flags |
| 8 | 4 | frame count, if flag `0x01` |
| | 4 | stream bytes, if flag `0x02` |
| | 100 | table of contents, if flag `0x04` |
| | 4 | quality 0-100, if flag `0x08` |

The optional fields appear in that order, each only if its flag is set.
`Info` is the same structure in a constant-bitrate file.

## VBRI

At frame start plus 36 (32 bytes after the header), independent of the side
information size. The deck reads quality, stream bytes, frame count and
whether the table of contents has entries; a VBRI header shorter than 26
bytes yields `kind` `"VBRI"` with nothing else stated.

| Offset | Length | Field |
|---|---|---|
| 0 | 4 | `VBRI` |
| 4 | 2 | version |
| 6 | 2 | delay |
| 8 | 2 | quality |
| 10 | 4 | stream bytes |
| 14 | 4 | frame count |
| 18 | 2 | table-of-contents entries |
| 20 | 2 | scale |
| 22 | 2 | bytes per entry |
| 24 | 2 | frames per entry |

Written by the Fraunhofer encoder; Xing is more common.
