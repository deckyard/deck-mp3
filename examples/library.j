#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * library example - a directory of MP3s, end to end.
 *
 * Writes a small album into a temporary directory, reads it back, retags one
 * file in place with `save`, and writes an M3U8 playlist with
 * `entryFromTrack` and `savePlaylist`.
 *
 *   jennifer run examples/library.j
 */

use io;
use fs;
use path;
use binary;
use strings;

import "../src/mp3.j" as mp3;

func silence(frames as int) {
    def head as bytes;
    $head[] = 0xff;
    $head[] = 0xfb;
    $head[] = 0x90;
    $head[] = 0x00;
    def parts as list of bytes init [];
    for (def i as int init 0; $i < $frames; $i = $i + 1) {
        $parts[] = $head;
        $parts[] = binary.make(413, 0);
    }
    return binary.join($parts);
}

def titles as list of string init [
    "Ich war müde leer nicht mehr da",
    "Ich war müde leer nicht mehr da (Artists Cut)",
    "Ich war müde leer nicht mehr da (Instrumental)"
];
def lengths as list of int init [70, 310, 300, 250];

def dir as string init fs.makeTempDir();
defer fs.removeAll($dir);
io.printf("working in %s\n\n", $dir);

# -- write the album ----------------------------------------------------------

for (def i as int init 0; $i < len($titles); $i = $i + 1) {
    def tag as mp3.Tag init mp3.emptyTag();
    $tag.title = $titles[$i];
    $tag.artist = "Maike Vandervaart";
    $tag.album = "Ich war müde leer nicht mehr da";
    $tag.albumArtist = "Maike Vandervaart";
    $tag.genre = "Ambient";
    $tag.year = "2025";
    $tag.track = $i + 1;
    $tag.trackTotal = len($titles);

    def name as string init io.sprintf("%d|pad=2|fill=0", $i + 1) + " - " + $titles[$i] + ".mp3";
    def data as bytes init mp3.write(silence($lengths[$i]), $tag, mp3.defaultOptions());
    fs.writeBytes(path.join($dir, $name), $data);
}

# -- read it back -------------------------------------------------------------

def names as list of string init fs.list($dir);
def tracks as list of mp3.Track init [];
for (def name in $names) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    $tracks[] = mp3.open(path.join($dir, $name));
}

io.printf("%d tracks\n", len($tracks));
for (def t in $tracks) {
    io.printf("  %d. %s\n", $t.tag.track, mp3.describe($t));
}
io.printf("\n");

# -- retag one of them in place -----------------------------------------------

def third as mp3.Track init $tracks[2];
def fixed as mp3.Tag init $third.tag;
$fixed.genre = "Electronic";
def comments as list of mp3.Comment init [];
$comments[] = mp3.Comment{language: "eng", description: "", text: "the one everybody knows"};
$fixed.comments = $comments;
mp3.save(mp3.withTag($third, $fixed), $third.path);

def reread as mp3.Track init mp3.open($third.path);
io.printf(
    "retagged: %s, genre %s, comment \"%s\"\n",
    $reread.tag.title,
    $reread.tag.genre,
    mp3.commentText($reread.tag));
io.printf("audio untouched: %t\n\n", mp3.strip(fs.readBytes($third.path)) == silence(300));

# -- generate a playlist ------------------------------------------------------

# Entries are collected in a list and the field assigned once. `addEntry`
# copies the whole list, so calling it per track is quadratic - fine for three
# tracks, seconds of work for a real library.
def entries as list of mp3.PlaylistEntry init [];
for (def name in $names) {
    if (not strings.endsWith($name, ".mp3")) {
        continue;
    }
    def t as mp3.Track init mp3.open(path.join($dir, $name));
    # a playlist beside the music carries relative paths
    def entry as mp3.PlaylistEntry init mp3.entryFromTrack($t);
    $entry.path = $name;
    $entries[] = $entry;
}

def pl as mp3.Playlist init mp3.newPlaylist();
$pl.title = "Ich war müde leer nicht mehr da";
$pl.entries = $entries;

def file as string init path.join($dir, "Vandervaart.m3u8");
mp3.savePlaylist($pl, $file);
io.printf("%s", fs.readString($file));
io.printf("\ntotal %s\n", mp3.formatDuration(mp3.playlistDuration($pl) * 1000));

# -- and read the playlist back, resolving its paths --------------------------

def back as mp3.Playlist init mp3.resolvePlaylist(mp3.openPlaylist($file), $dir);
def missing as int init 0;
for (def e in $back.entries) {
    if (not fs.isFile($e.path)) {
        $missing = $missing + 1;
    }
}
io.printf("%d entries resolve, %d missing\n", len($back.entries) - $missing, $missing);
