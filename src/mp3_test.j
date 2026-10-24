# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box unit tests for the mp3 module.
 *
 * `jennifer test src/mp3_test.j`. One test file per topic under `topics/`,
 * spliced with `include` in the order `mp3.j` uses.
 *
 * The functions that touch the filesystem (`open`, `save`, `writeFile`,
 * `openPlaylist`, `savePlaylist`) are tested in a temporary directory in
 * `file_test.j` and `m3u_test.j`; everything else works on byte buffers.
 *
 * The MPEG fixtures every later overlay builds its test files from live in
 * `mpeg_test.j`.
 */

use testing;
use strings;
use maps;
use binary;
use convert;
use encoding;
use fs;
use path;

include "topics/core_test.j";
include "topics/genres_test.j";
include "topics/text_test.j";
include "topics/mpeg_test.j";
include "topics/audio_test.j";
include "topics/id3v1_test.j";
include "topics/id3v2_test.j";
include "topics/tag_test.j";
include "topics/file_test.j";
include "topics/m3u_test.j";
