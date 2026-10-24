# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * mp3 - read and edit MP3 metadata, and build M3U playlists.
 *
 * An MP3 file is a stream of MPEG audio frames with an optional ID3v2 tag in
 * front and an optional ID3v1 tag in the last 128 bytes.
 *
 *   whole file  {@link open} / {@link parse} / {@link save} / {@link strip}
 *   tags        {@link Tag} / {@link write} / {@link mergeTags}
 *   ID3v2       {@link readId3v2} / {@link renderId3v2} / {@link frameText}
 *   ID3v1       {@link readId3v1} / {@link renderId3v1} / {@link genreName}
 *   audio       {@link readAudio} / {@link parseFrameHeader} / {@link AudioInfo}
 *   playlists   {@link parsePlaylist} / {@link buildPlaylist}
 *
 * {@link Tag} is one struct for ID3v2.2, 2.3, 2.4 and ID3v1, read and
 * written; the raw ID3v2 frames stay reachable. Text is read in all four
 * ID3v2 encodings and written in the narrowest that holds it.
 *
 * Value-semantic: a function that changes a tag, track or playlist returns a
 * fresh value, so the calling shape is `$x = something($x, ...)`. Errors
 * raised by the deck have `kind` `"mp3"`.
 *
 * The topic files under `topics/` are spliced in with `include`; this file is
 * the module boundary. Tests: `mp3_test.j`.
 *
 * @module mp3
 * @see https://id3.org/id3v2.4.0-structure
 * @example
 *   import "@deckyard/mp3/" as mp3;
 *
 *   def track as mp3.Track init mp3.open("song.mp3");
 *   io.printf("%s - %s (%d s)\n", $track.tag.artist, $track.tag.title,
 *       $track.audio.durationMs // 1000);
 *
 *   def tag as mp3.Tag init $track.tag;
 *   $tag.genre = "Ambient";
 *   mp3.save(mp3.withTag($track, $tag), "song.mp3");
 */

use strings;
use convert;
use binary;
use encoding;
use maps;
use io;
use fs;
use path;
use uuid;
use compress;

include "topics/version.j";
include "topics/core.j";
include "topics/genres.j";
include "topics/text.j";
include "topics/mpeg.j";
include "topics/audio.j";
include "topics/id3v1.j";
include "topics/id3v2.j";
include "topics/tag.j";
include "topics/file.j";
include "topics/m3u.j";
