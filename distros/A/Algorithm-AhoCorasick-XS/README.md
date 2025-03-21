# NAME

Algorithm::AhoCorasick::XS - fast Aho-Corasick multiple string matcher

# SYNOPSIS

    # *** EARLY RELEASE - API SUBJECT TO CHANGE ***

    my $ac = Algorithm::AhoCorasick::XS->new([qw(he she hers his)]);
    for my $match ($ac->match_details("ahishers")) {
        printf "Word %s appears from %d to %d\n", $match->{word}, $match->{start}, $match->{end}; 
    }
    # Outputs:
    # Word his appears from 1 to 3
    # Word she appears from 3 to 5
    # Word he appears from 4 to 5
    # Word hers appears from 4 to 7

    # I only care about the words matched
    my @words = $ac->matches($input);    # or unique_matches to remove duplicates

    # I only care about the first match, if any
    my $first_match = $ac->first_match($input);

# DESCRIPTION

Implements Aho-Corasick, which given an input string and a set of substrings, will
tell you which of those substrings are present in the input, and where.

Aho-Corasick matches all substrings at once, so no matter how many you have, it
runs in roughly linear time (proportional to the size of the input string + the sum
of sizes of all substrings + the number of matches).

# MOTIVATION

The excellent [Algorithm::AhoCorasick](https://metacpan.org/pod/Algorithm::AhoCorasick) is pure Perl, and roughly 100 times slower.
Other modules suffer from bugs (false negatives) when given overlapping substrings,
segfault, or won't tell you precisely which substrings matched.

# FUNCTIONS

- new ( ARRAYREF\_OF\_SUBSTRINGS )

    Constructs a matcher object given an arrayref of substrings. Builds the internal
    automaton.

- matches ( INPUT )

    Given a string, returns a list of the substrings which are present in the input.
    There may be duplicates if a substring occurs more than once.

- unique\_matches ( INPUT )

    As above but runs `uniq` on the list for you.

- first\_match ( INPUT )

    Returns the first match only (or undef if none). This is efficient - the matcher
    will stop once it encounters the first match, and the rest of the string will be
    ignored.

- match\_details ( INPUT )

    Returns a list of hashrefs, containing the keys `word`, `start` and `end`.
    These correspond to an occurence of a substring - the word, start and end offset
    within the string.

# ENCODING SUPPORT

The matcher runs at the byte level, so you can use any encoding you like. If you
want to match strings regardless of encoding, I recommend that you encode everything
into UTF-8 and apply NFC normalization (or perhaps NFD).

## Passing Unicode strings

If you pass Unicode strings to the matcher, they will be interpreted as a sequence
of UTF-8 bytes. This means the output of `matches`, `match_details` etc. will also
be in terms of bytes.

You can simply call ` decode('UTF-8', ...) ` on the substrings to get their
Unicode versions. The offsets will be in bytes though; converting them to character
offsets in the Unicode string is a little more tricky:

    use Encode qw(decode);
    my $unicode_start = length(decode('UTF-8', bytes::substr($string, 0, $start)));
    my $unicode_end   = $start + length(decode('UTF-8', $word)) - 1;

This will be handled for you in a future version.

# CAVEATS

This is an early release and has not been tested thoroughly, use at your own risk.
The API is subject to change until version 1.0.

If your keyword list contains duplicates, you will get duplicate matches.

# COPYRIGHT & LICENSE

Copyright 2017 Richard Harris. This library is free software; you may redistribute
it and/or modify it under the same terms as Perl itself.

# AUTHOR

Richard Harris <richardjharris@gmail.com>

# SEE ALSO

[Algorithm::AhoCorasick](https://metacpan.org/pod/Algorithm::AhoCorasick)
