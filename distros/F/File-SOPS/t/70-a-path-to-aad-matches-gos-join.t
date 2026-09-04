#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS;

# ----------------------------------------------------------------------------
# k156: _path_to_aad answers ':' for an empty path -- the document ROOT --
# which is what Go's strings.Join([], ":") + ":" would produce. The earlier
# code returned '' for an undef OR empty array, with no live caller reaching
# the empty case (every format builds at least one key path before a leaf) but
# with a silent divergence on the wire if a future format ever did.
#
# The test pins the four answers the function can give, because they cover the
# three callers (the encrypt walk, the decrypt walk, the MAC verification) and
# the failure mode the divergence would have looked like from inside Perl.
# ----------------------------------------------------------------------------

# The leaf at the document ROOT: the case the divergence was about.
subtest '_path_to_aad([]) is the document ROOT, which Go spells ":"' => sub {
    is(File::SOPS::_path_to_aad([]), ':',
        'an empty arrayref is the document root, and Go joins it to ":"');
};

# An env comment under the empty key -- the ONE live path that hits the
# empty-component rule. Format::ENV writes those leaves under [''] precisely
# because _path_to_aad spells that as ":", matching what sops wrote.
subtest '_path_to_aad([ "" ]) is ":", the env comment AAD' => sub {
    is(File::SOPS::_path_to_aad([ '' ]), ':',
        'a single empty component joins to ":" -- what env comments live under');
};

# A leaf inside `db:`, the deepest case the INI walk produces.
subtest '_path_to_aad([ qw(db password) ]) joins and trails with ":"' => sub {
    is(File::SOPS::_path_to_aad([ 'db', 'password' ]), 'db:password:',
        'a non-empty path joins with ":" and trails one, exactly like Go');
};

# A undef path is a caller bug. The early return still answers "", which
# keeps the bug from looking like a quiet AAD mismatch.
subtest 'an undef path answers "", which is a caller bug visible at the cipher' => sub {
    is(File::SOPS::_path_to_aad(undef), '',
        'undef stays "", so a missing argument surfaces rather than quietly mismatches');
};

# A path containing a colon in a component is still bytes-of-keys -- the join
# does not escape. A sops document does not produce one (Go's own keys are
# literal), but the function is byte-faithful to whatever the parser produced.
subtest 'a colon in a component is taken literally, not escaped' => sub {
    is(File::SOPS::_path_to_aad([ 'a:b', 'c' ]), 'a:b:c:',
        'no escape -- a ":" inside a key is part of the component, by Go\'s rule');
};

done_testing();