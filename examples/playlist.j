#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * playlist example - reading and writing M3U and M3U8.
 *
 * Parses an extended M3U with groups, totals its durations, resolves its
 * relative paths, and builds a playlist from scratch.
 *
 *   jennifer run examples/playlist.j
 */

use io;
use strings;

import "../src/mp3.j" as mp3;

# -- read one -----------------------------------------------------------------

def source as string init '#EXTM3U
#PLAYLIST:Evening
#EXTGRP:Side A
#EXTINF:258,Maike Vandervaart - Ich war müde leer nicht mehr da
single/01.mp3
#EXTINF:258,Maike Vandervaart - Ich war müde leer nicht mehr da (Artists Cut)
single/02.mp3
#EXTGRP:Side B
#EXTINF:-1,Unknown length
single/03.mp3
# a comment nothing understands
https://example.invalid/stream.mp3
';

def pl as mp3.Playlist init mp3.parsePlaylist($source);
io.printf(
    "%s: %d entries, %s\n",
    $pl.title,
    len($pl.entries),
    mp3.formatDuration(mp3.playlistDuration($pl) * 1000));
for (def e in $pl.entries) {
    def length as string init mp3.formatDuration($e.duration * 1000);
    if ($e.duration == mp3.DURATION_UNKNOWN) {
        $length = "  -  ";
    }
    io.printf("  [%s] %s  %s\n", $e.group, $length, $e.path);
}
io.printf("\n");

# -- resolve the relative paths against where the playlist lives --------------

def resolved as mp3.Playlist init mp3.resolvePlaylist($pl, "/music/vandervaart");
for (def e in $resolved.entries) {
    io.printf("  %s\n", $e.path);
}
io.printf("\n");

# -- build one ----------------------------------------------------------------

def built as mp3.Playlist init mp3.newPlaylist();
$built.title = "Short";
$built = mp3.addEntry($built, mp3.playlistEntry("one.mp3", "First - one", 61));
$built = mp3.addEntry($built, mp3.playlistEntry("two.mp3", "Second - two", 125));

def grouped as mp3.PlaylistEntry init mp3.playlistEntry("three.mp3", "Third - three", 90);
$grouped.group = "Encore";
$built = mp3.addEntry($built, $grouped);

io.printf("%s", mp3.buildPlaylist($built));
io.printf("\n");

# -- the plain form -----------------------------------------------------------

def plain as mp3.Playlist init $built;
$plain.extended = false;
io.printf("plain:\n%s", mp3.buildPlaylist($plain));

# A plain playlist read back has paths and nothing else.
def plainBack as mp3.Playlist init mp3.parsePlaylist(mp3.buildPlaylist($plain));
io.printf(
    "read back: extended %t, first duration %d\n",
    $plainBack.extended,
    $plainBack.entries[0].duration);

# `openPlaylist` and `savePlaylist` do the same over the filesystem, choosing
# the encoding from the extension.
io.printf("%d lines in all\n", len(strings.split(mp3.buildPlaylist($built), "\n")) - 1);
