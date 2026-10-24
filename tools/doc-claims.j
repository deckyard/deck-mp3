#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * doc-claims - assert that the values the guides print are what the code
 * returns.
 *
 * `tools/check-docs.sh` runs this and compares its output to the markdown:
 * every integer a guide annotates a snippet with must be one of the values
 * claimed here, labelled with that guide's path, and every listing printed
 * here must appear verbatim in the guide it names.
 *
 * Two output shapes, both read by check-docs.sh:
 *
 *   claim <doc> <what> => <value>
 *   <<<listing <doc> ... >>>
 *
 *   jennifer run tools/doc-claims.j
 */

use io;
use binary;

import "../src/mp3.j" as mp3;

def failures as int init 0;

/**
 * Print one claim, and check it.
 *
 * @param doc {string} the guide that prints this value
 * @param what {string} the expression the guide shows
 * @param actual {int} what the code returns
 * @param expected {int} what the guide says
 */
func claim(doc as string, what as string, actual as int, expected as int) {
    if ($actual == $expected) {
        io.printf("claim %s %s => %d\n", $doc, $what, $actual);
        return;
    }
    $failures = $failures + 1;
    io.printf("MISMATCH %s: %s is %d, the guide says %d\n", $doc, $what, $actual, $expected);
}

/**
 * Build the file the guides describe: the Ich war müde leer nicht mehr da tag over silence.
 *
 * @return {bytes} a complete MP3, ID3v2.4 tagged
 */
func fixture() {
    def head as bytes;
    $head[] = 0xff;
    $head[] = 0xfb;
    $head[] = 0x90;
    $head[] = 0x00;
    def parts as list of bytes init [];
    for (def i as int init 0; $i < 20; $i = $i + 1) {
        $parts[] = $head;
        $parts[] = binary.make(413, 0);
    }
    def tag as mp3.Tag init mp3.emptyTag();
    $tag.title = "Ich war müde leer nicht mehr da";
    $tag.artist = "Maike Vandervaart";
    $tag.track = 1;
    $tag.trackTotal = 3;
    return mp3.write(binary.join($parts), $tag, mp3.defaultOptions());
}

def track as mp3.Track init mp3.parse(fixture());

# docs/guide/tags.md opens by reading a file with this tag.
claim("docs/guide/tags.md", "$tag.track", $track.tag.track, 1);
claim("docs/guide/tags.md", "$tag.trackTotal", $track.tag.trackTotal, 3);

# docs/guide/audio.md reads the stream of the same file.
claim("docs/guide/audio.md", "$info.sampleRate", $track.audio.sampleRate, 44100);

# docs/guide/id3v1.md quotes the genre table.
claim("docs/guide/id3v1.md", 'mp3.genreNumber("rock")', mp3.genreNumber("rock"), 17);
claim("docs/guide/id3v1.md", 'mp3.genreNumber("Chiptune")', mp3.genreNumber("Chiptune"), -1);

# docs/guide/playlists.md prints what buildPlaylist emits.
def pl as mp3.Playlist init mp3.newPlaylist();
$pl.title = "Evening";
$pl = mp3.addEntry($pl, mp3.playlistEntry("one.mp3", "First - one", 61));
$pl = mp3.addEntry($pl, mp3.playlistEntry("two.mp3", "Second - two", 125));
def encore as mp3.PlaylistEntry init mp3.playlistEntry("three.mp3", "Third - three", 90);
$encore.group = "Encore";
$pl = mp3.addEntry($pl, $encore);

io.printf("<<<listing docs/guide/playlists.md\n");
io.printf("%s", mp3.buildPlaylist($pl));
io.printf(">>>\n");

if ($failures > 0) {
    io.printf("%d claim(s) do not match the code\n", $failures);
    exit 1;
}
io.printf("every claim matches the code\n");
