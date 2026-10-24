# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# mp3 - the ID3v1 numeric genre table.
# Spliced into mp3.j via include - not a standalone module.

/**
 * Every genre an ID3v1 genre byte can name, in numeric order.
 *
 * 0-79 are the original ID3v1 list, 80-125 the Winamp 1.x extensions,
 * 126-147 Winamp 5.0 and 148-191 Winamp 5.6. 192 and up are unassigned; 255
 * is the conventional "no genre".
 *
 * Index 133 is `Afro-Punk`, the name Winamp 5.6 gave the entry that replaced
 * an earlier slur. The number is unchanged.
 */
export def const GENRES as list of string init [
    "Blues",
    "Classic Rock",
    "Country",
    "Dance",
    "Disco",
    "Funk",
    "Grunge",
    "Hip-Hop",
    "Jazz",
    "Metal",
    "New Age",
    "Oldies",
    "Other",
    "Pop",
    "R&B",
    "Rap",
    "Reggae",
    "Rock",
    "Techno",
    "Industrial",
    "Alternative",
    "Ska",
    "Death Metal",
    "Pranks",
    "Soundtrack",
    "Euro-Techno",
    "Ambient",
    "Trip-Hop",
    "Vocal",
    "Jazz+Funk",
    "Fusion",
    "Trance",
    "Classical",
    "Instrumental",
    "Acid",
    "House",
    "Game",
    "Sound Clip",
    "Gospel",
    "Noise",
    "AlternRock",
    "Bass",
    "Soul",
    "Punk",
    "Space",
    "Meditative",
    "Instrumental Pop",
    "Instrumental Rock",
    "Ethnic",
    "Gothic",
    "Darkwave",
    "Techno-Industrial",
    "Electronic",
    "Pop-Folk",
    "Eurodance",
    "Dream",
    "Southern Rock",
    "Comedy",
    "Cult",
    "Gangsta",
    "Top 40",
    "Christian Rap",
    "Pop/Funk",
    "Jungle",
    "Native American",
    "Cabaret",
    "New Wave",
    "Psychadelic",
    "Rave",
    "Showtunes",
    "Trailer",
    "Lo-Fi",
    "Tribal",
    "Acid Punk",
    "Acid Jazz",
    "Polka",
    "Retro",
    "Musical",
    "Rock & Roll",
    "Hard Rock",
    "Folk",
    "Folk-Rock",
    "National Folk",
    "Swing",
    "Fast Fusion",
    "Bebob",
    "Latin",
    "Revival",
    "Celtic",
    "Bluegrass",
    "Avantgarde",
    "Gothic Rock",
    "Progressive Rock",
    "Psychedelic Rock",
    "Symphonic Rock",
    "Slow Rock",
    "Big Band",
    "Chorus",
    "Easy Listening",
    "Acoustic",
    "Humour",
    "Speech",
    "Chanson",
    "Opera",
    "Chamber Music",
    "Sonata",
    "Symphony",
    "Booty Bass",
    "Primus",
    "Porn Groove",
    "Satire",
    "Slow Jam",
    "Club",
    "Tango",
    "Samba",
    "Folklore",
    "Ballad",
    "Power Ballad",
    "Rhythmic Soul",
    "Freestyle",
    "Duet",
    "Punk Rock",
    "Drum Solo",
    "A capella",
    "Euro-House",
    "Dance Hall",
    "Goa",
    "Drum & Bass",
    "Club-House",
    "Hardcore",
    "Terror",
    "Indie",
    "BritPop",
    "Afro-Punk",
    "Polsk Punk",
    "Beat",
    "Christian Gangsta Rap",
    "Heavy Metal",
    "Black Metal",
    "Crossover",
    "Contemporary Christian",
    "Christian Rock",
    "Merengue",
    "Salsa",
    "Thrash Metal",
    "Anime",
    "Jpop",
    "Synthpop",
    "Abstract",
    "Art Rock",
    "Baroque",
    "Bhangra",
    "Big Beat",
    "Breakbeat",
    "Chillout",
    "Downtempo",
    "Dub",
    "EBM",
    "Eclectic",
    "Electro",
    "Electroclash",
    "Emo",
    "Experimental",
    "Garage",
    "Global",
    "IDM",
    "Illbient",
    "Industro-Goth",
    "Jam Band",
    "Krautrock",
    "Leftfield",
    "Lounge",
    "Math Rock",
    "New Romantic",
    "Nu-Breakz",
    "Post-Punk",
    "Post-Rock",
    "Psytrance",
    "Shoegaze",
    "Space Rock",
    "Trop Rock",
    "World Music",
    "Neoclassical",
    "Audiobook",
    "Audio Theatre",
    "Neue Deutsche Welle",
    "Podcast",
    "Indie Rock",
    "G-Funk",
    "Dubstep",
    "Garage Rock",
    "Psybient"
];

/** How many genre numbers are assigned: `GENRES` holds 0 to `GENRE_COUNT - 1`. */
export def const GENRE_COUNT as int init 192;

/** The genre byte an ID3v1 tag uses for "no genre set". */
export def const GENRE_NONE as int init 255;

/**
 * The name of a numeric ID3v1 genre.
 *
 * @param number {int} the genre byte, 0-191
 * @return {string} the genre name, or `""` for an unassigned number
 * @example
 *   mp3.genreName(17);    # "Rock"
 *   mp3.genreName(255);   # ""
 */
export func genreName(number as int) {
    if ($number < 0 or $number >= GENRE_COUNT) {
        return "";
    }
    return GENRES[$number];
}

/**
 * The number of a named ID3v1 genre.
 *
 * Ignores case and surrounding whitespace.
 *
 * @param name {string} the genre name
 * @return {int} the genre number, or `-1` when the name is not in the table
 * @example
 *   mp3.genreNumber("rock");       # 17
 *   mp3.genreNumber("Chiptune");   # -1
 */
export func genreNumber(name as string) {
    def want as string init strings.lower(strings.trim($name));
    if ($want == "") {
        return -1;
    }
    def width as int init len($want);
    for (def i as int init 0; $i < GENRE_COUNT; $i = $i + 1) {
        # the length test is what keeps this cheap: it rejects all but a
        # handful of the 192 names without allocating a lower-cased copy
        if (len(GENRES[$i]) != $width) {
            continue;
        }
        if (strings.lower(GENRES[$i]) == $want) {
            return $i;
        }
    }
    return -1;
}

/**
 * Resolve an ID3v2 `TCON` genre string to a readable name.
 *
 * `TCON` has carried four spellings over the versions: a bare name
 * (`Rock`), a bare number (`17`), an ID3v2.3 numeric reference
 * (`(17)`), and a reference with a refinement after it (`(17)Hard Rock`).
 * The two ID3v2.3 escapes `(RX)` and `(CR)` mean Remix and Cover. Text after
 * `(n)` wins over the number. Input is trimmed; text that resolves to nothing
 * is returned trimmed.
 *
 * @param raw {string} the frame text as stored
 * @return {string} the resolved name, or the trimmed `raw`
 * @example
 *   mp3.resolveGenre("(17)");          # "Rock"
 *   mp3.resolveGenre("(17)Surf");      # "Surf"
 *   mp3.resolveGenre("Chiptune");      # "Chiptune"
 */
export func resolveGenre(raw as string) {
    def text as string init strings.trim($raw);
    if ($text == "") {
        return "";
    }
    if (strings.startsWith($text, "(")) {
        def close as int init strings.indexOf($text, ")");
        if ($close > 0) {
            def inner as string init strings.substring($text, 1, $close);
            def rest as string init strings.trim(strings.substring($text, $close + 1));
            def resolved as string init refinementName($inner);
            if ($rest != "") {
                return $rest;
            }
            if ($resolved != "") {
                return $resolved;
            }
        }
    }
    def numeric as int init genreNumber($text);
    if ($numeric >= 0) {
        return GENRES[$numeric];
    }
    if (isAllDigits($text)) {
        def byNumber as string init genreName(leadingInt($text));
        if ($byNumber != "") {
            return $byNumber;
        }
    }
    return $text;
}

/**
 * The genre named by the inside of an ID3v2.3 `(...)` reference.
 *
 * @param inner {string} the text between the parentheses
 * @return {string} the genre name, or `""` when it names nothing
 */
func refinementName(inner as string) {
    if ($inner == "RX") {
        return "Remix";
    }
    if ($inner == "CR") {
        return "Cover";
    }
    if (not isAllDigits($inner)) {
        return "";
    }
    return genreName(leadingInt($inner));
}

/**
 * Whether every character of `s` is an ASCII digit.
 *
 * @param s {string} the text to test; `""` is false
 * @return {bool} true when `s` is one or more digits and nothing else
 */
func isAllDigits(s as string) {
    if ($s == "") {
        return false;
    }
    def chars as list of string init strings.chars($s);
    for (def ch in $chars) {
        def code as int init convert.toCodepoint($ch);
        if ($code < 0x30 or $code > 0x39) {
            return false;
        }
    }
    return true;
}
