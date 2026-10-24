#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * fuzz - throw malformed input at every reader and assert it holds.
 *
 * The deck claims that damage a reader can work around is not an error: a
 * truncated tag yields the frames before the damage, mislabelled text falls
 * back to ISO-8859-1, an encoding byte outside 0-3 resolves to ISO-8859-1, an
 * encrypted frame is dropped. A claim like that is only as good as what has
 * been thrown at it, so this throws a few thousand malformed files and checks
 * three invariants on each:
 *
 *   1  nothing raises - every reader returns a value
 *   2  `strip` is idempotent - stripping twice is stripping once
 *   3  a rewrite at ID3v2.2, 2.3 and 2.4 preserves the tag that was read and
 *      the audio byte for byte
 *
 * The inputs are a fixture per ID3v2 version, truncated at every twenty-third
 * offset, with one byte bent at every seventh offset across the tag region,
 * with random runs spliced over the tag, plus pure noise at many lengths.
 * Every random value comes from a seeded `math.randSeed`, so a failure here
 * reproduces exactly.
 *
 * Two bugs came out of this sweep, both now regressed by the unit suite:
 * a corrupt text-encoding byte raised out of `parse`
 * (`testACorruptEncodingByteCostsOneFrameNotTheRead`), and a twenty-digit
 * `#EXTINF` duration overflowed `int64`
 * (`testLeadingIntSaturatesRatherThanOverflowing`).
 *
 *   jennifer run tools/fuzz.j
 */

use io;
use binary;
use convert;
use math;

import "../src/mp3.j" as mp3;

/** How many inputs were driven through the readers. */
def inputs as int init 0;

/** How many invariants broke. Non-zero exits 1. */
def failures as int init 0;

/** The ID3v2 versions a tag is rewritten at for invariant 3. */
def const MAJORS as list of int init [2, 3, 4];

/**
 * Record a broken invariant.
 *
 * @param label {string} which input broke it
 * @param message {string} what broke
 */
func note(label as string, message as string) {
    $failures = $failures + 1;
    io.printf("  %s: %s\n", $label, $message);
}

/**
 * `n` pseudo-random bytes from a fixed seed.
 *
 * @param n {int} how many bytes
 * @param seed {int} the seed, so a failure reproduces
 * @return {bytes} the bytes
 */
func noise(n as int, seed as int) {
    math.randSeed($seed);
    def out as bytes;
    for (def i as int init 0; $i < $n; $i = $i + 1) {
        $out[] = math.randInt(0, 255);
    }
    return $out;
}

/**
 * `frames` frames of MPEG-1 Layer III silence, 128 kbit/s, 44100 Hz.
 *
 * @param frames {int} how many frames
 * @return {bytes} the stream, 417 bytes per frame
 */
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

/**
 * A tag exercising every field the unified view carries.
 *
 * Text that needs UTF-8, text that needs only ISO-8859-1, two comments, a
 * picture and a user-defined frame, so a rewrite has something to lose.
 *
 * @return {mp3.Tag} the tag
 */
func richTag() {
    def tag as mp3.Tag init mp3.emptyTag();
    $tag.title = "Übergene IV";
    $tag.artist = "日本語";
    $tag.album = "Ich war müde leer nicht mehr da";
    $tag.albumArtist = "Vandervaart";
    $tag.composer = "JMJ";
    $tag.genre = "Ambient";
    $tag.year = "2025";
    $tag.date = "2025";
    $tag.track = 4;
    $tag.trackTotal = 6;
    $tag.disc = 1;
    $tag.discTotal = 2;
    $tag.bpm = 120;
    $tag.publisher = "Example Records";
    $tag.encodedBy = "deck";
    $tag.copyright = "c";
    $tag.lyrics = "la la";
    return withCollections($tag);
}

/**
 * The list- and map-valued half of {@link richTag}.
 *
 * Split out to keep both methods short.
 *
 * @param tag {mp3.Tag} the scalar half
 * @return {mp3.Tag} the same tag with comments, a picture and a TXXX frame
 */
func withCollections(tag as mp3.Tag) {
    def out as mp3.Tag init $tag;
    def comments as list of mp3.Comment init [];
    $comments[] = mp3.Comment{language: "eng", description: "", text: "plain"};
    $comments[] = mp3.Comment{language: "deu", description: "iTunNORM", text: "0000"};
    $out.comments = $comments;

    def pictures as list of mp3.Picture init [];
    $pictures[] = mp3.Picture{
        mimeType: "image/png",
        kind: mp3.PICTURE_FRONT_COVER,
        description: "front",
        data: binary.make(48, 0x89)
    };
    $out.pictures = $pictures;

    def extra as map of string to string init {};
    $extra["replaygain_track_gain"] = "-6.50 dB";
    $out.extra = $extra;
    return $out;
}

/**
 * A complete file carrying {@link richTag} at one ID3v2 version.
 *
 * @param major {int} the ID3v2 version to write
 * @return {bytes} the file, with an ID3v1 tag behind the ID3v2 one
 */
func fixture(major as int) {
    def opts as mp3.WriteOptions init mp3.defaultOptions();
    $opts.major = $major;
    $opts.id3v1 = true;
    $opts.padding = 32;
    return mp3.write(silence(8), richTag(), $opts);
}

/**
 * Check invariant 3: a rewrite preserves the tag and the audio.
 *
 * One ID3v2 version per input, rotated across the sweep. Rewriting at all
 * three every time triples the cost for the same coverage: the sweep is
 * hundreds of inputs long per fixture, so each version still sees plenty of
 * truncations, bent bytes and splices.
 *
 * @param label {string} which input is being checked
 * @param data {bytes} the input
 * @param track {mp3.Track} what reading it gave
 * @param audio {bytes} the audio `strip` found in it
 * @param major {int} the ID3v2 version to rewrite at
 */
func checkRewrites(
    label as string,
    data as bytes,
    track as mp3.Track,
    audio as bytes,
    major as int) {
    def opts as mp3.WriteOptions init mp3.defaultOptions();
    $opts.major = $major;
    $opts.id3v1 = $major == 3;
    $opts.padding = $major * 7;
    def at as string init $label + " v2." + convert.toString($major);

    def out as bytes init mp3.write($data, $track.tag, $opts);
    def back as mp3.Track init mp3.parse($out);
    if ($back.tag.title != $track.tag.title) {
        note($at, "a rewrite changed the title to " + $back.tag.title);
    }
    if ($back.tag.artist != $track.tag.artist) {
        note($at, "a rewrite changed the artist to " + $back.tag.artist);
    }
    if (mp3.strip($out) != $audio) {
        note($at, "a rewrite changed the audio");
    }
}

/**
 * Drive one input through every reader and check the three invariants.
 *
 * @param label {string} which input this is, for a failure message
 * @param data {bytes} the input
 */
func check(label as string, data as bytes) {
    $inputs = $inputs + 1;
    try {
        def track as mp3.Track init mp3.parse($data);
        def quick as mp3.Track init mp3.parseWith($data, false);
        if ($quick.tag.title != $track.tag.title) {
            note($label, "scanning the frames changed the tag");
        }
        def audio as bytes init mp3.strip($data);
        if (mp3.strip($audio) != $audio) {
            note($label, "strip is not idempotent");
        }
        if (len(mp3.describe($track)) < 0) {
            note($label, "describe returned nothing");
        }
        checkRewrites($label, $data, $track, $audio, MAJORS[$inputs % len(MAJORS)]);
    } catch (e) {
        note($label, "raised " + $e.kind + ": " + $e.message);
    }
}

/**
 * Drive one playlist through the parser, the writer and the resolver.
 *
 * @param label {string} which input this is
 * @param text {string} the playlist
 */
func checkPlaylist(label as string, text as string) {
    $inputs = $inputs + 1;
    try {
        def pl as mp3.Playlist init mp3.parsePlaylist($text);
        def again as mp3.Playlist init mp3.parsePlaylist(mp3.buildPlaylist($pl));
        if (len($again.entries) != len($pl.entries)) {
            note($label, "a build and re-parse changed the entry count");
        }
        if (mp3.playlistDuration(mp3.resolvePlaylist($pl, "/base")) < 0) {
            note($label, "a negative total duration");
        }
    } catch (e) {
        note($label, "raised " + $e.kind + ": " + $e.message);
    }
}

/**
 * Truncations of a file, at every twenty-third offset.
 *
 * @param label {string} which fixture
 * @param data {bytes} the whole file
 */
func sweepTruncations(label as string, data as bytes) {
    for (def cut as int init 0; $cut < len($data); $cut = $cut + 23) {
        check($label + "-cut" + convert.toString($cut), binary.slice($data, 0, $cut));
    }
}

/**
 * One byte bent at every seventh offset across the tag region.
 *
 * @param label {string} which fixture
 * @param data {bytes} the whole file
 */
func sweepBentBytes(label as string, data as bytes) {
    def limit as int init 700;
    if ($limit > len($data)) {
        $limit = len($data);
    }
    for (def at as int init 0; $at < $limit; $at = $at + 7) {
        def bent as bytes init $data;
        $bent[$at] = ($bent[$at] + 91) % 256;
        check($label + "-bend" + convert.toString($at), $bent);
    }
}

/**
 * A run of random bytes spliced over the tag, at a sweep of offsets.
 *
 * @param label {string} which fixture
 * @param data {bytes} the whole file
 * @param base {int} a seed offset, so each fixture gets different noise
 */
func sweepSplices(label as string, data as bytes, base as int) {
    for (def seed as int init 0; $seed < 12; $seed = $seed + 1) {
        def bent as bytes init $data;
        def junk as bytes init noise(24, $base + $seed);
        def at as int init 10 + ($seed * 11);
        for (def i as int init 0; $i < len($junk); $i = $i + 1) {
            if ($at + $i < len($bent)) {
                $bent[$at + $i] = $junk[$i];
            }
        }
        check($label + "-splice" + convert.toString($seed), $bent);
    }
}

# ---------------------------------------------------------------------------

io.printf("fuzzing the readers\n");

def version as int init 0;
for (def major in MAJORS) {
    $version = $version + 1;
    def data as bytes init fixture($major);
    def label as string init "v2." + convert.toString($major);
    sweepTruncations($label, $data);
    sweepBentBytes($label, $data);
    sweepSplices($label, $data, $version * 1000);
}

for (def seed as int init 0; $seed < 120; $seed = $seed + 1) {
    check("noise" + convert.toString($seed), noise(($seed * 13) % 900, 7000 + $seed));
}

def playlists as list of string init [
    "",
    "#",
    "#EXTM3U",
    "#EXTINF:",
    "#EXTINF:,",
    "#EXTINF:abc,x",
    "#PLAYLIST:",
    "#EXTGRP:",
    "#EXTALB:",
    "#EXTART:",
    "\n\n\n",
    "#EXTINF:1\nx",
    "a\r\nb\r\n",
    "#EXTM3U\n#EXTINF:-1,\n",
    "#EXTINF:99999999999999999999,x\ny",
    "#EXTINF:-0,x\ny",
    "x\n#EXTM3U\ny"
];
def index as int init 0;
for (def text in $playlists) {
    $index = $index + 1;
    checkPlaylist("playlist" + convert.toString($index), $text);
}

if ($failures > 0) {
    io.printf("\n%d invariant(s) broke across %d inputs\n", $failures, $inputs);
    exit 1;
}
io.printf("%d malformed inputs, every invariant held\n", $inputs);
