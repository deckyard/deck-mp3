#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * frames example - the ID3v2 container under the unified tag.
 *
 * Builds a tag from raw frames, walks them, reads the unified view over them,
 * keeps an unmapped `PRIV` frame through an edit, and shows ID3v2.2 names.
 *
 *   jennifer run examples/frames.j
 */

use io;
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

# -- build a tag out of frames directly --------------------------------------

def frames as list of mp3.Id3v2Frame init [];
$frames[] = mp3.textFrame("TIT2", "Ich war müde leer nicht mehr da", 4);
$frames[] = mp3.textFrame("TPE1", "Maike Vandervaart", 4);
$frames[] = mp3.textFrame("TCON", "(26)", 4);
# a frame the unified view does not name: it survives as a frame
$frames[] = mp3.Id3v2Frame{id: "PRIV", flags: 0, data: binary.make(6, 0x2a)};

def raw as bytes init mp3.renderId3v2($frames, 4, 256);
def file as bytes init binary.join([$raw, silence(40)]);
io.printf("tag is %d bytes of %d\n\n", mp3.id3v2Size($file), len($file));

# -- walk what came back ------------------------------------------------------

def id3 as mp3.Id3v2 init mp3.readId3v2($file);
# a modifier runs to the next space, so the hex goes into a variable first
def flags as string init io.sprintf("%d|base=16", $id3.flags);
io.printf("ID3v2.%d.%d, flags 0x%s, %d frames\n", $id3.major, $id3.minor, $flags, len($id3.frames));
for (def f in $id3.frames) {
    def text as string init mp3.frameText($f);
    if ($text == "") {
        io.printf("  %s  %d bytes, not text\n", $f.id, len($f.data));
    } else {
        io.printf("  %s  %s\n", $f.id, $text);
    }
}
io.printf("\n");

# -- the unified view over the same frames -----------------------------------

def tag as mp3.Tag init mp3.tagFromId3v2($id3);
io.printf("title %s\n", $tag.title);
io.printf("artist %s\n", $tag.artist);
# the numeric genre reference resolved against the ID3v1 table
io.printf(
    "genre %s (from the frame text %s)\n\n",
    $tag.genre,
    mp3.frameText(mp3.frame($id3, "TCON")));

# -- keep an unmapped frame through an edit ----------------------------------

# mp3.write renders the unified view and nothing else, so a frame it does not
# name is dropped. To keep one, render the frames yourself.
def edited as mp3.Tag init $tag;
$edited.album = "Ich war müde leer nicht mehr da";

def rebuilt as list of mp3.Id3v2Frame init mp3.framesFromTag($edited, 4);
for (def f in $id3.frames) {
    if (not strings.startsWith($f.id, "T")) {
        $rebuilt[] = $f;
    }
}
def kept as bytes init binary.join([mp3.renderId3v2($rebuilt, 4, 256), mp3.strip($file)]);

def after as mp3.Id3v2 init mp3.readId3v2($kept);
io.printf(
    "after the edit: %d frames, album %s, PRIV kept: %t\n",
    len($after.frames),
    mp3.tagFromId3v2($after).album,
    mp3.hasFrame($after, "PRIV"));

# -- ID3v2.2's three-character names -----------------------------------------

def old as bytes init mp3.renderId3v2(mp3.framesFromTag($edited, 2), 2, 0);
def oldTag as mp3.Id3v2 init mp3.readId3v2($old);
def names as list of string init [];
for (def f in $oldTag.frames) {
    $names[] = $f.id + " -> " + mp3.canonicalFrameId($f.id);
}
io.printf("ID3v2.2 stores: %s\n", strings.join($names, ", "));
