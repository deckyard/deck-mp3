<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Reading and writing files

```jennifer
def track as mp3.Track init mp3.open("song.mp3");

$track.path;      # where it was read from
$track.tag;       # the unified view, ID3v2 merged over ID3v1
$track.audio;     # AudioInfo for the stream
$track.id3v2;     # the raw ID3v2 tag
$track.id3v1;     # the raw ID3v1 tag
```

`parse($data)` does the same on a buffer and leaves `path` empty. A `Track`
does not hold the audio bytes, so copying one is cheap; `save` reads the
file again.

## Where the audio is

```jennifer
def r as mp3.AudioRange init mp3.audioRange($data);
$r.start;   # first byte after the ID3v2 tag
$r.end;     # one past the last byte before the ID3v1 tag
```

Only the ID3v2 and ID3v1 tags are excluded. An APE tag, a Lyrics3 block or
a `TAG+` tag counts as audio. `strip($data)` returns the bytes in that range.

```jennifer
fs.writeBytes("bare.mp3", mp3.strip(fs.readBytes("tagged.mp3")));
```

## Writing a buffer

```jennifer
def out as bytes init mp3.write($data, $tag, mp3.defaultOptions());
```

`write` copies the audio byte for byte and writes new tags from `tag` as
`options` says. The old tags are discarded, including frames `Tag` does not
name; [ID3v2](id3v2.md#keeping-frames-through-an-edit) shows how to keep
them.

| `WriteOptions` field | `defaultOptions()` | Means |
|---|---|---|
| `major` | 4 (`DEFAULT_MAJOR`) | ID3v2 version to write, 2-4 |
| `padding` | 1024 (`DEFAULT_PADDING`) | NUL bytes after the frames |
| `id3v2` | true | write an ID3v2 tag at the front |
| `id3v1` | false | write an ID3v1 tag at the end |

`optionsFor($track)` keeps what the file had: its ID3v2 version (or
`DEFAULT_MAJOR` if it had none) and an ID3v1 tag only if it carried one.

```jennifer
def out as bytes init mp3.write($data, $tag, mp3.optionsFor($track));
```

## Writing to disk

```jennifer
mp3.save(mp3.withTag($track, $edited), $track.path);
```

`save(track, target)` reads the audio from `track.path`, writes with
`optionsFor($track)`, and may overwrite its own source. It throws when
`track.path` is empty. `writeFile(source, target, tag, options)` does the
same with explicit options.

The write is atomic. The result is built in a temporary file beside the
target, named with a random v4 UUID so nothing can create it in advance, and
renamed over the target; on failure the temporary file is removed. Because
it is a rename, the target is replaced, not written through: a symlink
becomes a regular file and a hard link stops sharing. The audio is streamed
from the source buffer to the file, so a write holds one copy of the audio
in memory, not two.

## A directory

```jennifer
for (def name in fs.list($dir)) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    def track as mp3.Track init mp3.open(path.join($dir, $name));
    io.printf("%s\n", mp3.describe($track));
}
```

`describe` returns one line, fields separated by two spaces: artist and
title, duration, bitrate (with `VBR` when variable), sampling rate, channel
mode. Without audio it ends in `no audio`.

```jennifer
mp3.describe($track);
# Maike Vandervaart - Ich war müde leer nicht mehr da  4:18  160 kbit/s VBR  44100 Hz  stereo
```

On a large library, `parseWith($data, false)` skips the frame walk; see
[The audio stream](audio.md#duration).
