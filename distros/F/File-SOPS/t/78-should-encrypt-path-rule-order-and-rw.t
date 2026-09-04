#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS::Metadata;

# k142 -- docs: performance change to should_encrypt_path, cache guarded.
#
# should_encrypt_path recompiled qr/\Q$suffix\E$/ on every call and re-read four
# rw accessors twice each. The cache/read-once change must not move a single
# answer, so this file pins the exact semantics it optimises:
#
#   * every rule is tested against EVERY component of the path;
#   * the four rules apply in a FIXED order -- unencrypted_suffix,
#     encrypted_suffix, unencrypted_regex, encrypted_regex -- and a LATER rule
#     overrides an earlier one.
#
# The mutual-exclusion guard in BUILD makes the multi-rule case unreachable
# through the constructor, but the four rule attributes are rw and BUILD does
# not run again on a setter, so a caller can still put two rules on one object
# after construction. That degenerate case is where "later overrides earlier"
# is observable, and it is exactly what a value-keyed cache must not get wrong.

###############################################################################
# No rule at all: everything is encrypted, _unencrypted suffix included
###############################################################################
subtest 'no rule -- every leaf is encrypted' => sub {
    my $m = File::SOPS::Metadata->new(unencrypted_suffix => undef);
    is($m->should_encrypt_path(['x_unencrypted']), 1,
        'a key that spells the default suffix is still encrypted with no rule');
    is($m->should_encrypt_path(['db', 'password']), 1, 'and so is any other');
    is($m->should_encrypt_path([]), 1, 'the empty path too');
};

###############################################################################
# Each of the four rules on its own, against every path component
###############################################################################
subtest 'unencrypted_suffix alone (the default)' => sub {
    my $m = File::SOPS::Metadata->new;
    is($m->unencrypted_suffix, '_unencrypted', 'default rule is in force');
    is($m->should_encrypt_path(['db', 'password']), 1, 'no component matches');
    is($m->should_encrypt_path(['a', 'b_unencrypted']), 0, 'a leaf component matches');
    is($m->should_encrypt_path(['x_unencrypted', 'y']), 0,
        'a parent component matches -- tested against every component');
};

subtest 'encrypted_suffix alone' => sub {
    my $m = File::SOPS::Metadata->new(encrypted_suffix => '_enc');
    is($m->should_encrypt_path(['db', 'password']), 0, 'nothing matches -> not encrypted');
    is($m->should_encrypt_path(['db', 'pw_enc']), 1, 'a leaf component matches');
    is($m->should_encrypt_path(['a_enc', 'b']), 1, 'a parent component matches');
};

subtest 'unencrypted_regex alone' => sub {
    my $m = File::SOPS::Metadata->new(unencrypted_regex => '^public_');
    is($m->should_encrypt_path(['db', 'password']), 1, 'nothing matches -> encrypted');
    is($m->should_encrypt_path(['public_host']), 0, 'a leaf component matches');
    is($m->should_encrypt_path(['a', 'public_x', 'b']), 0, 'a middle component matches');
};

subtest 'encrypted_regex alone' => sub {
    my $m = File::SOPS::Metadata->new(encrypted_regex => '^secret_');
    is($m->should_encrypt_path(['db', 'password']), 0, 'nothing matches -> not encrypted');
    is($m->should_encrypt_path(['secret_token']), 1, 'a leaf component matches');
    is($m->should_encrypt_path(['a', 'secret_x']), 1, 'a parent component matches');
};

###############################################################################
# Degenerate rw case: two rules on one object, later overrides earlier
###############################################################################
subtest 'encrypted_suffix (later) overrides unencrypted_suffix (earlier)' => sub {
    my $m = File::SOPS::Metadata->new(unencrypted_suffix => '_plain');
    $m->encrypted_suffix('_enc');   # rw setter -- BUILD does not re-run

    is($m->should_encrypt_path(['a_plain', 'b_enc']), 1,
        'unencrypted_suffix says no, encrypted_suffix says yes -- the later rule wins');
    is($m->should_encrypt_path(['a_plain', 'b_plain']), 0,
        'and where the later rule finds no match it sets 0 outright');
    is($m->should_encrypt_path(['only_enc']), 1, 'encrypted_suffix match, no _plain');
};

subtest 'unencrypted_regex (later) overrides encrypted_suffix (earlier)' => sub {
    my $m = File::SOPS::Metadata->new(encrypted_suffix => '_enc');
    is($m->unencrypted_suffix, undef, 'the default suffix stood down for the chosen rule');
    $m->unencrypted_regex('^keep_');   # rw setter adds a third-in-order rule

    is($m->should_encrypt_path(['keep_enc']), 0,
        'encrypted_suffix says yes, unencrypted_regex says no -- the later rule wins');
    is($m->should_encrypt_path(['db_enc']), 1,
        'encrypted_suffix match that the later regex does not touch stays encrypted');
};

###############################################################################
# A mutated suffix is honoured, not served from a stale compiled matcher
###############################################################################
subtest 'a changed suffix value is recompiled, not cached stale' => sub {
    my $m = File::SOPS::Metadata->new(unencrypted_suffix => '_a');
    is($m->should_encrypt_path(['x_a']), 0, 'first suffix matches');
    is($m->should_encrypt_path(['x_b']), 1, 'and a non-match is encrypted');

    $m->unencrypted_suffix('_b');
    is($m->should_encrypt_path(['x_b']), 0, 'the new suffix now matches');
    is($m->should_encrypt_path(['x_a']), 1, 'and the old one no longer does');
};

done_testing;
