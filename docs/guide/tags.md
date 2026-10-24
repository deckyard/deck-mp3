<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Tags

`Tag` is the version-independent view of a file's metadata. `open` and
`parse` fill it from whichever tags the file carries; `write` and `save`
render it in the ID3 version the write options name.

```jennifer
def track as mp3.Track init mp3.open("song.mp3");
def tag as mp3.Tag init $track.tag;

$tag.title;         # "Ich war müde leer nicht mehr da"
$tag.artist;        # "Maike Vandervaart"
$tag.track;         # 1
$tag.trackTotal;    # 3
```

## Fields

| Field | Frame (2.3+ / 2.2) | Notes |
|---|---|---|
| `title` | `TIT2` / `TT2` | |
| `artist` | `TPE1` / `TP1` | the performer |
| `album` | `TALB` / `TAL` | |
| `albumArtist` | `TPE2` / `TP2` | |
| `composer` | `TCOM` / `TCM` | |
| `genre` | `TCON` / `TCO` | numeric references resolved, see [Genres](#genres) |
| `year` | `TDRC`, else `TDRL`, else `TYER` / `TYE` | the leading four digits of a timestamp |
| `date` | `TDRC`, else `TDRL` | the full timestamp; equal to `year` when only `TYER` is present |
| `track` / `trackTotal` | `TRCK` / `TRK` | `3/12` split on the `/` |
| `disc` / `discTotal` | `TPOS` / `TPA` | `1/2` split on the `/` |
| `bpm` | `TBPM` / `TBP` | leading digits; saturates at 999999999 |
| `publisher` | `TPUB` / `TPB` | |
| `encodedBy` | `TENC` / `TEN` | |
| `copyright` | `TCOP` / `TCR` | |
| `lyrics` | `USLT` / `ULT` | the first lyrics frame only |
| `comments` | `COMM` / `COM` | every comment, in stored order |
| `pictures` | `APIC` / `PIC` | every picture, in stored order |
| `extra` | `TXXX` / `TXX` | keyed by description; the first frame per description wins |

A missing field is `""`, `0` or an empty list or map. For a text frame that
appears twice, the first one wins.

Writing puts the year in `TDRC` on ID3v2.4 (the full `date` when set,
otherwise `year`) and in `TYER` / `TYE` on ID3v2.3 and 2.2. Only fields that
are set produce frames, and empty comments and pictures with no data are
skipped.

## Editing

An edit is an assignment to a copy:

```jennifer
def edited as mp3.Tag init $track.tag;
$edited.genre = "Electronic";
$edited.albumArtist = "Maike Vandervaart";

mp3.save(mp3.withTag($track, $edited), $track.path);
```

`$track.tag` is unchanged until `withTag` returns a new track. See
[Reading and writing files](files.md) for `write` and `save`.

The zero value of `Tag` is an empty tag; `emptyTag()` returns the same for
use in an expression.

A list field is built in a local and assigned, because `$tag.comments[] = x`
is a parse error in Jennifer:

```jennifer
def comments as list of mp3.Comment init [];
$comments[] = mp3.Comment{language: "eng", description: "", text: "a note"};
$tag.comments = $comments;
```

## Comments

Players show the comment with an empty description. Taggers add others keyed
by description (iTunes writes `iTunNORM` and `iTunSMPB`). `commentText`
returns the first comment with an empty description, else the first comment,
else `""`.

```jennifer
mp3.commentText($tag);
```

A comment's `language` is written lower-cased; a value that is not three
ISO-8859-1 characters is written as `eng`.

## Pictures

`kind` is the ID3v2 picture type, an index into `PICTURE_TYPES` (0-20);
`PICTURE_FRONT_COVER` is 3. `coverArt` returns the front cover, else the
first picture, else an empty `Picture`.

```jennifer
def cover as mp3.Picture init mp3.coverArt($tag);
if (len($cover.data) > 0) {
    io.printf("%s, %s\n", mp3.pictureTypeName($cover.kind), $cover.mimeType);
}
```

ID3v2.2 stores a three-character image format instead of a media type.
Reading maps `JPG` and `PNG` to `image/jpeg` and `image/png`, and any other
format to `image/` plus the format in lower case; writing ID3v2.2 maps back,
with `JPG` for a type it cannot map. A media type that is empty or not
printable ASCII is written as `image/jpeg`, and a picture type outside 0-20
as 0.

## Genres

`genre` is text. Reading passes `TCON` through `resolveGenre`, which handles
the spellings the versions have used:

```jennifer
mp3.resolveGenre("Rock");         # "Rock"
mp3.resolveGenre("17");           # "Rock"
mp3.resolveGenre("(17)");         # "Rock"
mp3.resolveGenre("(17)Surf");     # "Surf"
mp3.resolveGenre("Chiptune");     # "Chiptune"
```

The full table is in [ID3v1 and genres](id3v1.md).

## User-defined text

`extra` holds the `TXXX` frames by description: MusicBrainz identifiers,
ReplayGain values and similar. Each entry is written back as a `TXXX` frame.

```jennifer
$tag.extra["replaygain_track_gain"];    # "-6.50 dB"
```

## Merging

`mergeTags(primary, fallback)` returns `primary` with its empty fields taken
from `fallback`. Text fields count as empty when `""`, numbers when `0`;
`comments` and `pictures` are taken whole from `fallback` only when `primary`
has none. `extra` is not merged. `parse` and `open` merge the ID3v2 tag over
the ID3v1 tag this way.

```jennifer
def merged as mp3.Tag init mp3.mergeTags(mp3.tagFromId3v2($id3), mp3.tagFromId3v1($v1));
```

## Text encodings

Each frame is written in the narrowest encoding that holds its text:
ISO-8859-1 when every character fits, otherwise UTF-8 on ID3v2.4 and UTF-16
with a byte-order mark on ID3v2.3 and 2.2. NUL characters are removed from
text-frame values and from descriptions before writing.

Reading accepts all four encodings. UTF-8 text that does not decode falls
back to ISO-8859-1, an unpaired UTF-16 surrogate becomes U+FFFD, and an
encoding byte outside 0-3 is read as ISO-8859-1. The encoding byte is
described in [the ID3 formats on disk](../reference/id3.md#text-encodings).
