<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Cheatsheet

Every export of `@deckyard/mp3`, by topic, called through the import alias:
`import "@deckyard/mp3/" as mp3;` then `mp3.open(path)`. `tools/check-docs.sh`
checks each signature against the source.

## Version

| Constant | Value | Meaning |
|---|---|---|
| `VERSION` | `"0.1.0"` | The deck version, stamped by `tools/inject-version.sh`. |

## Errors

| Constant | Value | Meaning |
|---|---|---|
| `ERROR_KIND` | `"mp3"` | The `kind` of every `Error` the deck raises; `fs` errors keep their own. |
| `SYNCSAFE_MAX` | `268435455` | The largest value a 28-bit synchsafe integer can hold. |

## Genres

The ID3v1 genre table and the ID3v2 `TCON` resolver.

| Constant | Value | Meaning |
|---|---|---|
| `GENRES` | a `list of string` | Every genre an ID3v1 genre byte can name, in numeric order. |
| `GENRE_COUNT` | `192` | Assigned genre numbers; `GENRES` holds 0 to `GENRE_COUNT - 1`. |
| `GENRE_NONE` | `255` | The genre byte an ID3v1 tag uses for "no genre set". |

| Signature | Returns | Does |
|---|---|---|
| `genreName(number)` | `string` | The name of genre 0-191, else `""`. |
| `genreNumber(name)` | `int` | The number of a genre name, ignoring case and outer whitespace; `-1` if unknown. |
| `resolveGenre(raw)` | `string` | `TCON` text (`Rock`, `17`, `(17)`, `(17)Surf`, `(RX)`, `(CR)`) to a name; unresolvable text comes back trimmed. |

## Text encodings

| Constant | Value | Meaning |
|---|---|---|
| `TEXT_LATIN1` | `0` | ID3v2 text encoding 0: ISO-8859-1, one byte per character. |
| `TEXT_UTF16` | `1` | ID3v2 text encoding 1: UTF-16 with a byte-order mark. All versions. |
| `TEXT_UTF16BE` | `2` | ID3v2 text encoding 2: UTF-16BE with no byte-order mark. ID3v2.4 only. |
| `TEXT_UTF8` | `3` | ID3v2 text encoding 3: UTF-8. ID3v2.4 only. |

| Signature | Returns | Does |
|---|---|---|
| `decodeText(data, enc)` | `string` | Decode unterminated ID3v2 text; invalid UTF-8 falls back to ISO-8859-1. Throws for `enc` outside 0-3. |
| `encodeText(s, enc)` | `bytes` | Encode without terminator; `TEXT_UTF16` writes an `ff fe` BOM. Throws for `enc` outside 0-3 or non-Latin-1 text with `TEXT_LATIN1`. |

## MPEG frame headers

### `MpegVersion`

Which MPEG audio generation a frame was coded to. The zero value is `Mpeg25`.

| Variant | Meaning |
|---|---|
| `Mpeg25` | The unofficial MPEG-2.5 extension: 11025, 12000 and 8000 Hz |
| `Mpeg2` | MPEG-2: 22050, 24000 and 16000 Hz |
| `Mpeg1` | MPEG-1: 44100, 48000 and 32000 Hz |

### `Layer`

Which MPEG audio layer a frame was coded to. MP3 is Layer III. The zero value is `LayerI`.

| Variant | Meaning |
|---|---|
| `LayerI` | Layer I, 384 samples per frame, four-byte slots |
| `LayerII` | Layer II, 1152 samples per frame |
| `LayerIII` | Layer III, what MP3 means: 1152 samples on MPEG-1, 576 below it |

### `ChannelMode`

How a frame carries its channels. The zero value is `Stereo`.

| Variant | Meaning |
|---|---|
| `Stereo` | Two independently coded channels |
| `JointStereo` | Two channels sharing coded information |
| `DualChannel` | Two unrelated mono channels in one stream |
| `Mono` | One channel |

### `FrameHeader`

One decoded MPEG audio frame header.

| Field | Meaning |
|---|---|
| `offset as int` | where the header starts in the buffer it was read from |
| `version as MpegVersion` | MPEG-1, MPEG-2 or MPEG-2.5 |
| `layer as Layer` | Layer I, II or III |
| `bitrate as int` | bits per second; `0` for a free-format frame |
| `sampleRate as int` | samples per second |
| `channelMode as ChannelMode` | stereo, joint stereo, dual channel or mono |
| `channels as int` | 1 for mono, 2 for everything else |
| `modeExtension as int` | the joint-stereo mode extension bits, 0-3 |
| `padding as bool` | whether the frame carries one extra slot |
| `crc as bool` | whether a 16-bit CRC follows the header |
| `copyright as bool` | the copyright bit |
| `original as bool` | the original-media bit |
| `emphasis as int` | the de-emphasis field, 0-3 |
| `frameSize as int` | the whole frame in bytes, header included |
| `samples as int` | PCM samples per channel the frame decodes to |

| Signature | Returns | Does |
|---|---|---|
| `parseFrameHeader(data, offset)` | `FrameHeader` | Decode the header at `offset`; throws when there is no legal header there. |
| `versionName(version)` | `string` | The name of an MPEG generation. |
| `layerName(layer)` | `string` | The name of an MPEG audio layer. |
| `channelModeName(mode)` | `string` | The name of a channel mode. |

## The audio stream

### `VbrHeader`

The encoder-written header that opens a variable-bitrate stream.

| Field | Meaning |
|---|---|
| `kind as string` | `"Xing"`, `"Info"`, `"VBRI"`, or `""` when the stream carries no such header |
| `frames as int` | how many frames the stream holds, or `0` when unstated |
| `streamBytes as int` | how many bytes of audio, or `0` when unstated |
| `quality as int` | the encoder quality 0-100, or `-1` when unstated |
| `hasToc as bool` | whether a seek table is present |

### `AudioInfo`

Everything the audio stream itself says about a file.

| Field | Meaning |
|---|---|
| `present as bool` | whether any MPEG audio frame was found at all |
| `offset as int` | where the first frame starts in the file |
| `length as int` | how many bytes of audio follow it |
| `version as MpegVersion` | the generation the first frame was coded to |
| `layer as Layer` | the layer the first frame was coded to |
| `channelMode as ChannelMode` | the first frame's channel mode |
| `channels as int` | 1 or 2 |
| `sampleRate as int` | samples per second |
| `bitrate as int` | bits per second: declared for CBR, measured average for VBR |
| `vbr as bool` | whether the bitrate varies between frames |
| `vbrHeader as VbrHeader` | the encoder-written header, if any |
| `frames as int` | how many frames the stream holds, or `0` when unknown |
| `durationMs as int` | how long the stream plays, in milliseconds |
| `exact as bool` | whether `frames` and `durationMs` were counted or stated, not estimated |

| Signature | Returns | Does |
|---|---|---|
| `readAudio(data, start, end)` | `AudioInfo` | Describe the MPEG audio between two offsets, walking every frame when no VBR header states the length. |
| `readAudioWith(data, start, end, scan)` | `AudioInfo` | `readAudio`; with `scan` false, estimate instead of walking. |
| `formatDuration(durationMs)` | `string` | `m:ss`, or `h:mm:ss` from one hour; seconds truncated, negative as `0:00`. |

## ID3v1

| Constant | Value | Meaning |
|---|---|---|
| `ID3V1_SIZE` | `128` | How long an ID3v1 tag is: `TAG` and 125 bytes of fixed-width fields. |

### `Id3v1`

An ID3v1 or ID3v1.1 tag.

| Field | Meaning |
|---|---|
| `present as bool` | whether the file carried a tag at all |
| `title as string` | up to 30 characters |
| `artist as string` | up to 30 characters |
| `album as string` | up to 30 characters |
| `year as string` | four characters, conventionally `YYYY` |
| `comment as string` | up to 30 characters, or 28 on ID3v1.1 |
| `track as int` | the ID3v1.1 track number, or `0` |
| `genre as int` | the genre byte as stored; `GENRE_NONE` when absent |
| `version11 as bool` | whether the tag uses the ID3v1.1 track field |

| Signature | Returns | Does |
|---|---|---|
| `readId3v1(data)` | `Id3v1` | Read the tag in the last 128 bytes; `present` false when there is none. |
| `renderId3v1(tag)` | `bytes` | 128 bytes; ID3v1.1 when `track` is 1-255; text above U+00FF becomes `?`. |

## ID3v2

| Constant | Value | Meaning |
|---|---|---|
| `ID3V2_HEADER_SIZE` | `10` | How long an ID3v2 header is, and an ID3v2.4 footer with it. |

### `Id3v2Frame`

One ID3v2 frame, as stored.

| Field | Meaning |
|---|---|
| `id as string` | the frame identifier - three characters on ID3v2.2, four on ID3v2.3 and ID3v2.4 |
| `flags as int` | the two frame flag bytes, status high and format low; `0` on ID3v2.2, which has none |
| `data as bytes` | the frame body, de-unsynchronised and decompressed |

### `Id3v2`

An ID3v2 tag.

| Field | Meaning |
|---|---|
| `present as bool` | whether the file opened with an ID3v2 tag |
| `major as int` | the ID3v2 major version: 2, 3 or 4 |
| `minor as int` | the revision number, almost always 0 |
| `flags as int` | the header flag byte |
| `size as int` | how many bytes the whole tag occupies in the file, header and footer included |
| `frames as list of Id3v2Frame` | every readable frame, in stored order; encrypted frames are dropped |

| Signature | Returns | Does |
|---|---|---|
| `id3v2Size(data)` | `int` | Tag size with header and footer, from the header alone; `0` without a tag. |
| `readId3v2(data)` | `Id3v2` | Read the tag at the start of `data`; a damaged tag yields the frames before the damage. |
| `hasFrame(tag, id)` | `bool` | Whether a tag carries a frame with this identifier. |
| `frame(tag, id)` | `Id3v2Frame` | The first frame with this identifier, or one with `id` `""`. |
| `framesWithId(tag, id)` | `list of Id3v2Frame` | Every frame with this identifier, in the order stored. |
| `frameText(f)` | `string` | The first value of a text or URL frame, else `""`. |
| `frameValues(f)` | `list of string` | Every non-empty value of a text frame. |
| `frameDescription(f)` | `string` | The description of `TXXX` / `WXXX`, else `""`. |
| `renderId3v2(frames, major, padding)` | `bytes` | A plain tag (no unsync, footer or compression) with `padding` NUL bytes. |

## Tags

| Constant | Value | Meaning |
|---|---|---|
| `PICTURE_TYPES` | a `list of string` | The 21 `APIC` picture type names, 0-20. |
| `PICTURE_FRONT_COVER` | `3` | The `APIC` picture type for the front cover, the one players show. |

### `Picture`

One embedded picture.

| Field | Meaning |
|---|---|
| `mimeType as string` | the media type, `"image/jpeg"` or `"image/png"` in practice; ID3v2.2's three-letter image format is mapped onto it |
| `kind as int` | the picture type, an index into `PICTURE_TYPES` |
| `description as string` | a short label, often empty |
| `data as bytes` | the image itself |

### `Comment`

One comment.

| Field | Meaning |
|---|---|
| `language as string` | the ISO-639-2 language code, `"eng"` by default |
| `description as string` | what distinguishes this comment from the others |
| `text as string` | the comment itself |

### `Tag`

Everything a tag says, independent of which version said it.

| Field | Meaning |
|---|---|
| `title as string` | the track title |
| `artist as string` | the performing artist |
| `album as string` | the album title |
| `albumArtist as string` | the album's artist, when it differs |
| `composer as string` | who wrote it |
| `genre as string` | the genre as text, with numeric references resolved |
| `year as string` | the four-digit year |
| `date as string` | the full recording time when the tag carried one |
| `track as int` | the track number, or `0` |
| `trackTotal as int` | how many tracks the release has, or `0` |
| `disc as int` | the disc number, or `0` |
| `discTotal as int` | how many discs the release has, or `0` |
| `bpm as int` | beats per minute, or `0` |
| `publisher as string` | the label |
| `encodedBy as string` | the encoding software or person |
| `copyright as string` | the copyright notice |
| `lyrics as string` | the unsynchronised lyrics |
| `comments as list of Comment` | every comment, in the order stored |
| `pictures as list of Picture` | every embedded picture |
| `extra as map of string to string` | the `TXXX` frames, by description |

| Signature | Returns | Does |
|---|---|---|
| `emptyTag()` | `Tag` | A tag with every field empty; the same as the zero value. |
| `canonicalFrameId(id)` | `string` | The ID3v2.3 name of an ID3v2.2 identifier; others unchanged. |
| `tagFromId3v2(id3)` | `Tag` | The unified view of an ID3v2 tag. |
| `pictureTypeName(kind)` | `string` | The name of picture type 0-20, else `""`. |
| `coverArt(tag)` | `Picture` | The front cover, else the first picture, else an empty one. |
| `commentText(tag)` | `string` | The first comment with no description, else the first comment, else `""`. |
| `tagFromId3v1(v1)` | `Tag` | The unified view of an ID3v1 tag. |
| `mergeTags(primary, fallback)` | `Tag` | `primary` with empty fields filled from `fallback`; `extra` is not merged. |
| `framesFromTag(tag, major)` | `list of Id3v2Frame` | ID3v2 frames for every set field. |
| `textFrame(id, value, major)` | `Id3v2Frame` | A text frame in the narrowest encoding, id mapped for ID3v2.2. |
| `id3v1FromTag(tag)` | `Id3v1` | The ID3v1 subset of a tag; an unknown genre becomes `GENRE_NONE`. |

## Whole files

| Constant | Value | Meaning |
|---|---|---|
| `DEFAULT_PADDING` | `1024` | NUL bytes `defaultOptions` leaves after the frames. |
| `DEFAULT_MAJOR` | `4` | The ID3v2 version `defaultOptions` writes. |

### `Track`

One MP3 file, read.

| Field | Meaning |
|---|---|
| `path as string` | where the file was read from, or `""` for a buffer |
| `tag as Tag` | the unified view, ID3v2 merged over ID3v1 |
| `audio as AudioInfo` | what the MPEG stream says |
| `id3v2 as Id3v2` | the ID3v2 tag, with every frame as stored |
| `id3v1 as Id3v1` | the ID3v1 tag |

### `WriteOptions`

What to write, and how.

| Field | Meaning |
|---|---|
| `major as int` | the ID3v2 version to write: 2, 3 or 4 |
| `padding as int` | how many NUL bytes to leave after the frames |
| `id3v2 as bool` | whether to write an ID3v2 tag at the front |
| `id3v1 as bool` | whether to write an ID3v1 tag at the end |

### `AudioRange`

Where the audio starts and ends within a file.

| Field | Meaning |
|---|---|
| `start as int` | the first audio byte, past any ID3v2 tag |
| `end as int` | one past the last audio byte, before any ID3v1 tag |

| Signature | Returns | Does |
|---|---|---|
| `defaultOptions()` | `WriteOptions` | The default write options: ID3v2.4, 1 KiB of padding, no ID3v1 tag. |
| `optionsFor(track)` | `WriteOptions` | The file's ID3v2 version (else `DEFAULT_MAJOR`), ID3v1 only if it had one. |
| `audioRange(data)` | `AudioRange` | The bytes between the ID3v2 and ID3v1 tags. |
| `strip(data)` | `bytes` | `data` without its ID3v2 and ID3v1 tags. |
| `parse(data)` | `Track` | Read a buffer; `path` is `""`. |
| `parseWith(data, scan)` | `Track` | `parse`; with `scan` false, skip the frame walk. |
| `open(path)` | `Track` | Read a file; `path` is set. |
| `withTag(track, tag)` | `Track` | A copy of `track` with `tag`. |
| `write(data, tag, options)` | `bytes` | The audio of `data` with new tags; old tags are discarded. |
| `writeFile(source, target, tag, options)` | `null` | `write` from file to file, atomically by rename. |
| `save(track, target)` | `null` | `writeFile` from `track.path` with `optionsFor(track)`; throws when `path` is empty. |
| `describe(track)` | `string` | One line: names, duration, bitrate, rate, channel mode, separated by two spaces. |

## Playlists

| Constant | Value | Meaning |
|---|---|---|
| `DURATION_UNKNOWN` | `-1` | An entry duration that is not known. |

### `PlaylistEntry`

One entry of a playlist.

| Field | Meaning |
|---|---|
| `path as string` | the file, as written in the playlist |
| `title as string` | what to show, conventionally `artist - title` |
| `duration as int` | how long it plays in seconds, or `DURATION_UNKNOWN` |
| `group as string` | the `#EXTGRP` group the entry belongs to |
| `album as string` | the `#EXTALB` album |
| `artist as string` | the `#EXTART` artist |

### `Playlist`

A playlist.

| Field | Meaning |
|---|---|
| `title as string` | the `#PLAYLIST` name, or `""` |
| `extended as bool` | whether the file opened with `#EXTM3U` |
| `entries as list of PlaylistEntry` | the entries, in order |

| Signature | Returns | Does |
|---|---|---|
| `newPlaylist()` | `Playlist` | An empty extended playlist. |
| `playlistEntry(path, title, duration)` | `PlaylistEntry` | Build one playlist entry. |
| `addEntry(playlist, entry)` | `Playlist` | Append one entry; copies the list, so quadratic in a loop. |
| `addEntries(playlist, entries)` | `Playlist` | Append a list of entries with one copy. |
| `entryFromTrack(track)` | `PlaylistEntry` | An entry for `track.path`, titled from the tag, duration rounded to seconds. |
| `parsePlaylist(text)` | `Playlist` | Read M3U or extended M3U text; never throws. |
| `buildPlaylist(playlist)` | `string` | Playlist text, `\n` line endings. |
| `playlistDuration(playlist)` | `int` | Total seconds; unknown durations count as 0. |
| `resolvePlaylist(playlist, baseDir)` | `Playlist` | Join relative paths onto `baseDir`; does not confine them. |
| `openPlaylist(playlistPath)` | `Playlist` | Read a file as UTF-8, or ISO-8859-1 when not valid UTF-8. |
| `savePlaylist(playlist, playlistPath)` | `null` | Write `.m3u8` as UTF-8, others as ISO-8859-1 when possible. |

