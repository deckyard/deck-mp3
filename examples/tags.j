#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * tags example - read a tag, change it, write it back.
 *
 * `Tag` is the same struct for every ID3 version; editing a tag is
 * assignment to its fields.
 *
 *   jennifer run examples/tags.j
 */

use io;
use binary;

import "../src/mp3.j" as mp3;

# A real MP3 would come off disk. This builds one in memory so the example
# has something to work on: ten frames of MPEG-1 Layer III silence.
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

def tag as mp3.Tag init mp3.emptyTag();
$tag.title = "Ich war müde leer nicht mehr da";
$tag.artist = "Maike Vandervaart";
$tag.album = "Ich war müde leer nicht mehr da";
$tag.genre = "Ambient";
$tag.year = "2025";
$tag.date = "2025";
$tag.track = 1;
$tag.trackTotal = 3;

def comments as list of mp3.Comment init [];
$comments[] = mp3.Comment{language: "eng", description: "", text: "from the deck examples"};
$tag.comments = $comments;

def extra as map of string to string init {};
$extra["replaygain_track_gain"] = "-6.50 dB";
$tag.extra = $extra;

def file as bytes init mp3.write(silence(400), $tag, mp3.defaultOptions());
io.printf("wrote %d bytes\n\n", len($file));

# -- read it back -----------------------------------------------------------

def track as mp3.Track init mp3.parse($file);
io.printf("%s\n", mp3.describe($track));
io.printf("album    %s\n", $track.tag.album);
io.printf("genre    %s\n", $track.tag.genre);
io.printf("year     %s (recorded %s)\n", $track.tag.year, $track.tag.date);
io.printf("track    %d of %d\n", $track.tag.track, $track.tag.trackTotal);
io.printf("comment  %s\n", mp3.commentText($track.tag));
io.printf("gain     %s\n\n", $track.tag.extra["replaygain_track_gain"]);

# -- change one field and write it back --------------------------------------

def edited as mp3.Tag init $track.tag;
$edited.genre = "Electronic";
$edited.albumArtist = "Vandervaart";

def rewritten as bytes init mp3.write($file, $edited, mp3.optionsFor($track));
def after as mp3.Track init mp3.parse($rewritten);
io.printf("genre is now %s, album artist %s\n", $after.tag.genre, $after.tag.albumArtist);

# The audio is carried over byte for byte, whatever the tag did.
io.printf("audio unchanged: %t\n\n", mp3.strip($rewritten) == mp3.strip($file));

# -- the same tag, written as ID3v2.3 and as ID3v1 ---------------------------

def older as mp3.WriteOptions init mp3.defaultOptions();
$older.major = 3;
$older.id3v1 = true;

def legacy as bytes init mp3.write($file, $edited, $older);
def read as mp3.Track init mp3.parse($legacy);
io.printf("ID3v2.%d with an ID3v1 tag behind it: %t\n", $read.id3v2.major, $read.id3v1.present);
io.printf(
    "ID3v1 says %s / %s, genre %d (%s)\n",
    $read.id3v1.artist,
    $read.id3v1.title,
    $read.id3v1.genre,
    mp3.genreName($read.id3v1.genre));

# ID3v1 has four 30-character fields and a numeric genre, so the frames the
# unified view does not fit into it are dropped.
io.printf("ID3v1 kept the album artist: %t\n", $read.id3v1.album == $edited.albumArtist);
