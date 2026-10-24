<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# ID3v1 and genres

ID3v1 is the last 128 bytes of the file (`ID3V1_SIZE`): `TAG` and six
fixed-width ISO-8859-1 fields. The byte layout is in
[the ID3 formats on disk](../reference/id3.md#id3v1).

```jennifer
def v1 as mp3.Id3v1 init mp3.readId3v1($data);
if ($v1.present) {
    io.printf("%s / %s / %s\n", $v1.artist, $v1.title, mp3.genreName($v1.genre));
}
```

Without a tag, `readId3v1` returns `present` false, empty strings, `track`
0 and `genre` `GENRE_NONE` (255). Fields are read up to the first NUL and
trimmed. `genre` is the raw byte, so it can be 192-254, which `genreName`
maps to `""`.

## ID3v1.1

ID3v1.1 stores a track number in the last two bytes of the 30-byte comment:
a NUL at comment byte 28 and a non-zero byte at 29. A tag with that marker
reads with `version11` true, `track` set and a 28-byte comment.

`renderId3v1` always returns 128 bytes. It writes ID3v1.1 with a 28-byte
comment when `track` is 1-255, and the plain 30-byte comment otherwise, so a
track number outside 1-255 is dropped. `present` is ignored.

```jennifer
def v1 as mp3.Id3v1 init mp3.id3v1FromTag($tag);
def block as bytes init mp3.renderId3v1($v1);
```

## What is lost

`id3v1FromTag` keeps title, artist, album, year, `commentText($tag)`, the
track number and the genre. Everything else in a [`Tag`](tags.md) is
dropped. On render, text longer than its field is truncated, characters
above U+00FF become `?`, NULs are removed, and a genre outside 0-191 becomes
`GENRE_NONE`. A genre name the table does not know also becomes
`GENRE_NONE`.

```jennifer
$v1.title = "日本語";
mp3.readId3v1($written).title;   # "???"

$v1.title = "Ich war müde leer nicht mehr da";   # one character over
mp3.readId3v1($written).title;   # "Ich war müde leer nicht mehr d"
```

`defaultOptions()` does not write ID3v1. Turn it on for players that read
nothing else:

```jennifer
def opts as mp3.WriteOptions init mp3.defaultOptions();
$opts.id3v1 = true;
```

`optionsFor($track)` writes ID3v1 when the file already had one.

## The genre table

`GENRES` holds 192 names (`GENRE_COUNT`): 0-79 are the original ID3v1 list,
80-125 the Winamp 1.x extensions, 126-147 Winamp 5.0 and 148-191 Winamp 5.6.
192 and up are unassigned; 255 is the conventional "no genre".

```jennifer
mp3.genreName(17);        # "Rock"
mp3.genreName(255);       # ""
mp3.genreNumber("rock");  # 17
mp3.genreNumber("Chiptune");   # -1
```

`genreNumber` ignores case and surrounding whitespace.

Index 133 is `Afro-Punk`, the name Winamp 5.6 gave the entry that replaced
an earlier slur. Readers that emit the old spelling still agree on the
number.

## `TCON` spellings

`resolveGenre` reads every form ID3v2 `TCON` has used:

| Stored | Resolves to |
|---|---|
| `Rock` | `Rock` |
| `17` | `Rock` |
| `(17)` | `Rock` |
| `(17)Hard Rock` | `Hard Rock` |
| `(RX)` | `Remix` |
| `(CR)` | `Cover` |
| `Chiptune` | `Chiptune` |
| `(999)` | `(999)` |

Input is trimmed first. A name the table does not know, or a number outside
it, is returned unchanged; a refinement after `(n)` wins over the number.

## Out of scope

The 227-byte `TAG+` extended tag, Lyrics3 and APE tags are not implemented.
They sit between the audio and the ID3v1 tag, and
[`audioRange`](files.md#where-the-audio-is) counts them as audio.
