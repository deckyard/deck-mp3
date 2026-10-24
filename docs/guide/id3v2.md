<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# ID3v2

An ID3v2 tag is a ten-byte header, a list of frames, and padding. This page
covers the raw container, for frames [`Tag`](tags.md) does not name. Byte
layouts are in [the ID3 formats on disk](../reference/id3.md).

## Reading

```jennifer
def id3 as mp3.Id3v2 init mp3.readId3v2($data);

$id3.present;        # false when the buffer does not open with a readable tag
$id3.major;          # the version: 2, 3 or 4
$id3.size;           # bytes, header and footer included
len($id3.frames);
```

A tag with major version outside 2-4, or a version or revision byte of `ff`,
reads as absent. `id3v2Size($data)` reads only the header, so it is the
cheap way to find where the audio starts; it returns 0 without a tag and
never more than the buffer length.

## Frames

Each `Id3v2Frame` has an `id` as stored (three characters on ID3v2.2), the
two flag bytes as one integer (status byte high, `0` on ID3v2.2), and `data`.
`data` is de-unsynchronised and decompressed, with the group, encryption and
data-length bytes removed, but not otherwise decoded.

```jennifer
for (def f in $id3.frames) {
    io.printf("%s  %d bytes\n", $f.id, len($f.data));
}
```

| Call | Returns |
|---|---|
| `frame(tag, id)` | the first frame with that id, or one with `id` `""` |
| `framesWithId(tag, id)` | every frame with that id, in stored order |
| `hasFrame(tag, id)` | whether one exists |
| `frameText(f)` | the first value of a text (`T...`) or URL (`W...`) frame, else `""` |
| `frameValues(f)` | every non-empty value of a text frame (ID3v2.4 multi-value) |
| `frameDescription(f)` | the description of `TXXX` / `WXXX` (`TXX` / `WXX`), else `""` |

```jennifer
mp3.frameText(mp3.frame($id3, "TPE1"));     # "Maike Vandervaart"
len(mp3.framesWithId($id3, "COMM"));
```

Lookups never throw and compare `id` as stored: on an ID3v2.2 tag ask for
`TT2`, not `TIT2`. `frameText` and `frameValues` currently return nothing for
`WXXX` / `WXX`; read the URL from `data`.

## The three versions

| | ID3v2.2 | ID3v2.3 | ID3v2.4 |
|---|---|---|---|
| frame id | 3 characters | 4 characters | 4 characters |
| frame header | 6 bytes | 10 bytes | 10 bytes |
| frame size | 24-bit | 32-bit | 28-bit synchsafe |
| encodings | 0, 1 | 0, 1 | 0, 1, 2, 3 |
| year | `TYE` | `TYER` | `TDRC` timestamp |
| multi-value text | no | no | yes |
| unsynchronisation | whole tag | whole tag | per frame |

`canonicalFrameId` maps an ID3v2.2 identifier to its ID3v2.3 name and
returns any other id unchanged. `textFrame` maps the other way when writing
ID3v2.2:

```jennifer
mp3.canonicalFrameId("TT2");    # "TIT2"
mp3.textFrame("TIT2", "Ich war müde leer nicht mehr da", 2).id;   # "TT2"
```

## Writing

`renderId3v2(frames, major, padding)` writes a plain tag: no
unsynchronisation, extended header, footer or compression, and zero frame
flags.

```jennifer
def frames as list of mp3.Id3v2Frame init [];
$frames[] = mp3.textFrame("TIT2", "Ich war müde leer nicht mehr da", 4);
$frames[] = mp3.textFrame("TPE1", "Maike Vandervaart", 4);

def raw as bytes init mp3.renderId3v2($frames, 4, mp3.DEFAULT_PADDING);
```

`padding` NUL bytes follow the frames, so a later edit can grow the tag in
place. It throws when `major` is not 2-4, `padding` is negative, a frame id
is not legal for `major`, or a frame or the tag exceeds its size field.

## Keeping frames through an edit

`write` renders only what `Tag` holds. To keep other frames, append them to
the tag's frames and render the tag yourself:

```jennifer
def rebuilt as list of mp3.Id3v2Frame init mp3.framesFromTag($tag, 4);
for (def f in $id3.frames) {
    def id as string init mp3.canonicalFrameId($f.id);
    if (not strings.startsWith($id, "T") and $id != "COMM" and $id != "USLT" and $id != "APIC") {
        $rebuilt[] = $f;
    }
}
def out as bytes init binary.join([mp3.renderId3v2($rebuilt, 4, 1024), mp3.strip($data)]);
```

The filter skips what `framesFromTag` already writes (text, `TXXX`, `COMM`,
`USLT`, `APIC`); it also drops text frames `Tag` does not name, such as
`TSRC`. Copied frames keep their stored id, so the source tag must have the
major version being written; their flags are not carried over. `strip` also
removes the ID3v1 tag.

## What the reader tolerates

A damaged tag yields what can be read:

- a frame that runs past the end of the tag, a NUL or an illegal character
  where an identifier belongs, or a size that cannot be read ends the frame
  list; the frames before it are kept;
- an ID3v2.4 frame size written as a plain integer instead of synchsafe is
  detected (see [Plain sizes in ID3v2.4](../reference/id3.md#plain-sizes-in-id3v24));
- a zlib-compressed frame is expanded only when it states a decompressed
  length of at most 16 MiB and expands to at most 16 MiB; otherwise,
  or when it does not decompress, its body is kept compressed, so a crafted
  file cannot make the reader allocate what it asks for;
- an encrypted frame is dropped;
- a grouped frame loses its group byte;
- a text encoding byte outside 0-3 is read as ISO-8859-1.

## Unsynchronisation

Unsynchronisation inserts a `00` after every `ff` that could start an MPEG
sync word, so a decoder scanning for audio finds none inside the tag. Reading
undoes it for the whole tag on ID3v2.3 and earlier and per frame on ID3v2.4.
The deck never writes an unsynchronised tag.
