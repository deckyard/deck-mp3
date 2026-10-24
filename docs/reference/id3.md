<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The ID3 formats on disk

## File layout

```
+------------------+  0
| ID3v2 tag        |  "ID3", optional, states its own length
+------------------+  id3v2Size(data)
| MPEG audio       |  frames, back to back
+------------------+  len(data) - 128
| ID3v1 tag        |  "TAG", optional, always 128 bytes
+------------------+  len(data)
```

Both tags are optional. Junk between the ID3v2 tag and the first frame is
common, so the frame scanner searches instead of assuming the audio starts at
`id3v2Size(data)`. An ID3v1 tag is recognised only by `TAG` at
`len(data) - 128`.

## ID3v1

128 bytes, all ISO-8859-1, NUL-padded.

| Offset | Length | Field |
|---|---|---|
| 0 | 3 | `TAG` |
| 3 | 30 | title |
| 33 | 30 | artist |
| 63 | 30 | album |
| 93 | 4 | year |
| 97 | 30 | comment |
| 127 | 1 | genre |

ID3v1.1 splits the comment:

| Offset | Length | Field |
|---|---|---|
| 97 | 28 | comment |
| 125 | 1 | `00`, the marker |
| 126 | 1 | track number, 1-255 |

A NUL at 125 and a non-NUL at 126 marks ID3v1.1.

Genre 0-191 indexes the table; 255 means "no genre". See
[ID3v1 and genres](../guide/id3v1.md).

## ID3v2 header

Ten bytes.

| Offset | Length | Field |
|---|---|---|
| 0 | 3 | `ID3` |
| 3 | 1 | major version: 2, 3 or 4 |
| 4 | 1 | revision |
| 5 | 1 | flags |
| 6 | 4 | size, synchsafe, excluding this header |

A major version outside 2-4, or a version or revision byte of `ff`, makes
the reader treat the file as untagged.

| Flag | Bit | Means |
|---|---|---|
| unsynchronisation | `0x80` | the body is unsynchronised |
| extended header | `0x40` | an extended header follows (ID3v2.3 and up) |
| experimental | `0x20` | ignored |
| footer | `0x10` | a ten-byte footer closes the tag (ID3v2.4) |

The footer is the header with `3DI` in place of `ID3`. It is not included in
the stated size; `id3v2Size` adds its ten bytes. The result is clamped to the
buffer length.

## Synchsafe integers

Four bytes of seven bits each, high bit clear, so the field never contains
a byte that could start an MPEG sync word.

```
value = (b0 & 0x7f) << 21 | (b1 & 0x7f) << 14 | (b2 & 0x7f) << 7 | (b3 & 0x7f)
```

The maximum is `268435455` (`SYNCSAFE_MAX`). On read, a set high bit is
masked off, not rejected, because real files set it.

## Extended header

ID3v2.3 states a size that **excludes** its own four-byte length field;
ID3v2.4 states one that **includes** it. The deck skips the extended header
without reading it. On ID3v2.2 the same flag bit means whole-tag compression,
which is ignored.

## Frame header

| | ID3v2.2 | ID3v2.3 | ID3v2.4 |
|---|---|---|---|
| identifier | 3 bytes | 4 bytes | 4 bytes |
| size | 3 bytes, big-endian | 4 bytes, big-endian | 4 bytes, synchsafe |
| flags | none | 2 bytes | 2 bytes |
| total | 6 | 10 | 10 |

An identifier is upper-case letters and digits only. A NUL where one belongs
starts the padding and ends the frame list; any other illegal identifier also
ends it.

### Plain sizes in ID3v2.4

Several widely used taggers wrote a plain big-endian size into ID3v2.4 frame
headers instead of a synchsafe one. When the two readings differ, the reader
takes the synchsafe one if it ends on a plausible frame boundary - the end of
the tag, the padding, or a legal identifier - otherwise the plain one if that
does, otherwise the synchsafe one. The writer always writes synchsafe.

This keeps those files readable, at a price: a crafted tag can split into
different frames here than in a strict reader. Do not use this deck to vet a
file that a strict parser will read later, or the other way round - a frame
one of them sees can be invisible to the other.

### ID3v2.3 frame flags

Status byte, then format byte.

| Bit | Status | Format |
|---|---|---|
| `0x80` | tag alter preservation | compression (zlib) |
| `0x40` | file alter preservation | encryption |
| `0x20` | read only | grouping |

Extra bytes at the front of the body, in order: a four-byte decompressed size
when compressed, an encryption method byte when encrypted, a group byte when
grouped.

### ID3v2.4 frame flags

| Bit | Status | Format |
|---|---|---|
| `0x40` | tag alter preservation | grouping |
| `0x20` | file alter preservation | |
| `0x10` | read only | |
| `0x08` | | compression (zlib) |
| `0x04` | | encryption |
| `0x02` | | unsynchronisation |
| `0x01` | | data length indicator |

Extra bytes at the front of the body, in order: a group byte, an encryption
method byte, a four-byte synchsafe data length indicator.

ID3v2.4 unsynchronises per frame, and the stated frame size is the size
**after** unsynchronisation. ID3v2.3 unsynchronises the whole tag, and its
frame sizes describe the body with unsynchronisation already undone. The
reader therefore undoes it before splitting frames on ID3v2.3 and earlier,
and per frame body on ID3v2.4 (when either the tag flag or the frame flag
is set).

## Unsynchronisation

Writing: insert a `00` after every `ff` followed by `00` or by a byte `>= e0`,
and after a trailing `ff`.

Reading: replace every `ff 00` pair with a single `ff`.

## Text encodings

The first byte of a text frame's body.

| Byte | Encoding | Versions |
|---|---|---|
| 0 | ISO-8859-1 | all |
| 1 | UTF-16 with a byte-order mark | all |
| 2 | UTF-16BE, no mark | ID3v2.4 |
| 3 | UTF-8 | ID3v2.4 |

A string ends at a NUL in the frame's own encoding: two NUL bytes at an even
offset from the string start for the UTF-16 encodings, one NUL otherwise. The
last string of a frame is usually unterminated and runs to the end.

ID3v2.4 allows several values in one text frame, separated by that
terminator. Earlier versions allow one, so a trailing NUL there is padding.
Empty values are dropped either way.

UTF-16 (1) honours either byte-order mark; without one it is read
little-endian. The writer emits `ff fe` (little-endian). An odd trailing byte
or unpaired surrogate decodes to U+FFFD.

URL frames (`W...`) carry no encoding byte at all and are always ISO-8859-1.
The user-defined `WXXX` is the exception: it has one, like `TXXX`.

## Frame bodies

### `TXXX` - user-defined text

```
encoding(1)  description...00  value...
```

### `COMM` and `USLT` - comment, lyrics

```
encoding(1)  language(3)  description...00  text...
```

The language is a three-character ISO-639-2 code, `eng` by convention.

### `APIC` - attached picture

```
encoding(1)  mime-type...00  type(1)  description...00  image...
```

The media type is ISO-8859-1 and ends at the NUL. A type outside printable
ASCII is written as `image/jpeg`, so it can neither fail the write nor end the
field early.

### `PIC` - the ID3v2.2 attached picture

```
encoding(1)  format(3)  type(1)  description...00  image...
```

`format` is a three-character image format - `JPG`, `PNG` - where every later
version stores a media type.

The picture type byte indexes `PICTURE_TYPES`; `3` is the front cover.

## ID3v2.2 to ID3v2.3 frame identifiers

`canonicalFrameId` maps left to right; writing ID3v2.2 maps right to left
and throws for an id not in this table.

| 2.2 | 2.3 | | 2.2 | 2.3 | | 2.2 | 2.3 |
|---|---|---|---|---|---|---|---|
| `TT1` | `TIT1` | | `TOT` | `TOAL` | | `COM` | `COMM` |
| `TT2` | `TIT2` | | `TOA` | `TOPE` | | `ULT` | `USLT` |
| `TT3` | `TIT3` | | `TOL` | `TOLY` | | `PIC` | `APIC` |
| `TP1` | `TPE1` | | `TOR` | `TORY` | | `GEO` | `GEOB` |
| `TP2` | `TPE2` | | `TRC` | `TSRC` | | `CNT` | `PCNT` |
| `TP3` | `TPE3` | | `TKE` | `TKEY` | | `POP` | `POPM` |
| `TP4` | `TPE4` | | `TLA` | `TLAN` | | `UFI` | `UFID` |
| `TAL` | `TALB` | | `TMT` | `TMED` | | `SLT` | `SYLT` |
| `TCM` | `TCOM` | | `TFT` | `TFLT` | | `MCI` | `MCDI` |
| `TXT` | `TEXT` | | `TDY` | `TDLY` | | `WAR` | `WOAR` |
| `TCO` | `TCON` | | `TLE` | `TLEN` | | `WAF` | `WOAF` |
| `TRK` | `TRCK` | | `TBP` | `TBPM` | | `WAS` | `WOAS` |
| `TPA` | `TPOS` | | `TPB` | `TPUB` | | `WCM` | `WCOM` |
| `TYE` | `TYER` | | `TEN` | `TENC` | | `WCP` | `WCOP` |
| `TDA` | `TDAT` | | `TCR` | `TCOP` | | `WPB` | `WPUB` |
| `TIM` | `TIME` | | `TSS` | `TSSE` | | `WXX` | `WXXX` |
| `TRD` | `TRDA` | | `TXX` | `TXXX` | | | |

## Sources

- [ID3v2.4 structure](https://id3.org/id3v2.4.0-structure) and
  [frames](https://id3.org/id3v2.4.0-frames)
- [ID3v2.3](https://id3.org/id3v2.3.0)
- [ID3v2.2](https://id3.org/id3v2-00)
