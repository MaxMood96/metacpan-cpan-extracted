#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use YAML::XS ();

use File::SOPS::Encrypted;
use File::SOPS::Format::YAML;

# ----------------------------------------------------------------------------
# k91 / docs/adr/0017: the foreign-resolution guard (k86, ADR 0013)
# used to gate AND decide on the leaf's stringification, and only asked the
# emitter what it actually writes once the stringification had already
# disagreed.
#
# For every leaf class but one the two are the same string. A boolean SV is the
# exception, and it breaks the proxy in both directions:
#
#   leaf   "$leaf"     token the emitter writes   digest text
#   !!1    1           true                       True
#   !!0    (empty)     false                      False
#
# k90 came through the second step by exactly this route: its digest text
# was `1` back then, `_go_agrees("1", "1")` said yes, and the guard returned
# before asking the emitter anything -- while the document carried a bare
# `true`. sops -d exit 51, silently. The false half never even reached the
# second step, because an empty string does not match $GO_LOOKS_AT.
#
# Nothing about the REFUSAL RULE changes here and no document moves: measured
# over 225 leaves x 2 slots x 2 handlers = 900 rows, before and after in one
# process, 900 identical outcomes and 0 moved. What is asserted below is the
# MECHANISM -- that the verdict now comes from the token and from nothing else,
# which is not visible in any document today and was not visible in k90's
# either, until sops read it.
#
# No binary is needed: every claim here is about which question this module
# asks itself. The round trip against sops is pinned in t/30 and t/04.
# ----------------------------------------------------------------------------

my $HAS_BOOL_SV = do {
    no warnings;
    eval q{
        no warnings 'experimental::builtin';
        use builtin qw(is_bool);
        is_bool(!!1) ? 1 : 0
    } || 0;
};

unless ($HAS_BOOL_SV) {
    plan skip_all =>
        "perl $] has no boolean SV (SvIsBOOL arrived in 5.36), so no leaf on "
      . "this perl has a written token that differs from its stringification "
      . "and the gap k91 describes cannot be reached. See docs/adr/0016.";
}

# Everything this file asserts is about which of the guard's own helpers get
# called, and with what. Wrapping them is the only way to see that from
# outside: the guard returns nothing when it accepts a leaf, which is exactly
# why the gap it had was invisible.
my $orig_emitted = \&File::SOPS::Format::YAML::_emitted_plain_scalar;
my $orig_agrees  = \&File::SOPS::Format::YAML::_go_agrees;
my $orig_guard   = \&File::SOPS::Format::YAML::_reject_foreign_resolution;
my (@tokens, @resolved, @entered);
{
    no warnings 'redefine';
    *File::SOPS::Format::YAML::_reject_foreign_resolution = sub {
        push @entered, $_[1];
        return $orig_guard->(@_);
    };
    *File::SOPS::Format::YAML::_emitted_plain_scalar = sub {
        my $token = $orig_emitted->(@_);
        push @tokens, $token;
        return $token;
    };
    *File::SOPS::Format::YAML::_go_agrees = sub {
        push @resolved, $_[0];
        return $orig_agrees->(@_);
    };
}

# One leaf through the guarded emitter, reporting what the guard asked about it.
# The token is the one the guard was ANSWERED with rather than one derived here
# from the leaf: a float reaches the emitter as its carrier (ADR 0006), and the
# carrier is what a reader gets to resolve.
sub guard_asked {
    my ($leaf) = @_;
    @tokens   = ();
    @resolved = ();
    @entered  = ();
    my @warnings;
    # Some corpus leaves (a bare 'True'/'False', in either its parsed or its
    # raw-Perl-string form) are, since k92 / ADR 0019, a str-vs-bool type
    # divergence the emitter carps about. This file is about a different,
    # earlier mechanism (k91, the gate and the stringification proxy) and
    # none of its subtests inspect the message, so it is captured here rather
    # than left to print -- t/35-string-go-reads-as-boolean.t is where that
    # warning is asserted. Exposed on the return value rather than silently
    # dropped, in case a future subtest here does want to look at it.
    my $document = eval {
        local $SIG{__WARN__} = sub { push @warnings, $_[0] };
        File::SOPS::Format::YAML->emit({ v => $leaf }, mac_covered => 1);
    };
    return {
        died     => ($document ? '' : $@),
        tokens   => [ @tokens ],
        resolved => [ @resolved ],
        entered  => [ @entered ],
        warnings => [ @warnings ],
    };
}

sub bool_sv {
    my ($true) = @_;
    my $x = 5;
    return $true ? ($x > 3) : ($x > 9);
}

# A leaf exactly as a YAML parse hands it over -- YAML::XS keeps the source text
# of every scalar, which is what puts the spelling into the next document and
# what makes these leaves reachable at all. A caller-supplied Perl string of the
# same characters is quoted on the way out and is not this test's subject.
sub yaml_leaf {
    my ($source) = @_;
    local $YAML::XS::Boolean = 'JSON::PP';
    return YAML::XS::Load("v: $source\n")->{v};
}

###############################################################################
# 1. THE VERDICT. Whatever the guard resolves through its model of Go is the
#    token the emitter writes -- never the leaf's stringification.
###############################################################################

subtest 'a boolean is resolved as the token, not as its stringification' => sub {
    for my $case ([ 1, 'true', 'True' ], [ 0, 'false', 'False' ]) {
        my ($true, $token, $digest) = @$case;
        my $leaf = bool_sv($true);
        my $asked = guard_asked($leaf);

        is($asked->{died}, '', "a $token leaf is written");
        # docs/adr/0070: a mac_covered emit() now runs a CLASSIFICATION pass
        # over every leaf before Dump (to find the safely-quotable ones), and
        # this leaf is not one of them -- it does not diverge, so it is left
        # in place and reaches the real reject_scalar guard during Dump too.
        # Both passes ask the emitter the same question, so the token is seen
        # twice rather than once; a genuinely quotable leaf (True/False, the
        # seven non-finite str spellings) is asked only in the classification
        # pass, because by the time Dump runs it has been replaced by a
        # sentinel the guard never looks twice at (t/30, t/35 pin that case).
        is_deeply($asked->{tokens}, [ $token, $token ],
            "the guard asked the emitter twice, and was told $token both times");
        is(File::SOPS::Encrypted->value_to_bytes($leaf), $digest,
            "and the digest covers $digest");
        is_deeply($asked->{resolved}, [ $token, $token ],
            "so what it resolved is $token both times, and nothing else")
            or diag('resolved: ' . join(', ', map { "'$_'" } @{$asked->{resolved}}));
    }
};

subtest 'the stringification is never what the guard resolves' => sub {
    # The general form of the case above: for any leaf the guard looks at, the
    # strings it resolves through its model of Go are exactly the token. Before
    # k91 an int, a float and a hinted string passed this too -- their two
    # strings are the same -- and a boolean did not.
    my @leaves = (
        [ 'an int'             => 5432 ],
        [ 'a negative int'     => -10 ],
        [ 'a float'            => 1.5 ],
        [ 'a computed float'   => 0.1 + 0.2 ],
        [ 'a hinted string'    => 'yes-ish' ],
        [ 'a true boolean'     => bool_sv(1) ],
        [ 'a false boolean'    => bool_sv(0) ],
        [ 'a parsed 007'       => yaml_leaf('007') ],
    );
    for my $case (@leaves) {
        my ($what, $leaf) = @$case;
        my $asked = guard_asked($leaf);
        is($asked->{died}, '', "$what is written");
        is_deeply($asked->{resolved}, $asked->{tokens},
            "$what: the guard resolved the emitted token and nothing else")
            or diag("tokens: @{$asked->{tokens}} resolved: @{$asked->{resolved}}");
    }
};

###############################################################################
# 2. THE GATE. It decides whether the emit below is worth paying for, and it
#    must not skip a leaf whose TOKEN Go's resolver looks at. That is the half
#    a false boolean fell through: its stringification is the empty string.
###############################################################################

# The ADR 0013 spellings as a parse hands them over, plus the leaf classes that
# reach the guard from a caller's own Perl rather than from a parse.
my @corpus = (
    (map { [ "a YAML-parsed $_" => yaml_leaf($_) ] }
        qw( 0755 010 007 08 09 0o10 0x1f 0b101 1_000 0_7 .inf .nan Null NULL
            TRUE True False true false yes no on off y n ~ null 1e3 1E3 0755e0
            -0 -0.0 0.0 1.5 5432 12:30:15 1:30 _7 0o8 123abc localhost
            supersecret 2024-invoice 9223372036854775807 ),
        '2015-01-01', '2015-01-01T12:00:00Z', 'v1.2.3', '192.168.1.1'),
    (map { [ "the Perl string '$_'" => $_ ] }
        qw( 0755 0o10 .inf Null TRUE True yes 123abc supersecret ), ''),
    [ 'a Perl int'           => 5432 ],
    [ 'a Perl float'         => 0.1 + 0.2 ],
    [ 'a Perl negative zero' => -0.0 ],
    [ 'a true boolean'       => bool_sv(1) ],
    [ 'a false boolean'      => bool_sv(0) ],
    [ 'an ENC[...] slot'     => 'ENC[AES256_GCM,data:aa,iv:bb,tag:cc,type:str]' ],
);

subtest 'no leaf whose token Go looks at gets past the gate unasked' => sub {
    # $GO_LOOKS_AT, the first-byte set Go's resolveTable reacts to at all.
    my $go_looks_at = qr/\A[-+.0-9yYnNtTfFoO~]/;
    my (@unasked, $hinted);
    for my $case (@corpus) {
        my ($what, $leaf) = @$case;
        my $token = $orig_emitted->($leaf);
        next unless defined $token && $token =~ $go_looks_at;
        my $asked = guard_asked($leaf);
        # A JSON::PP::Boolean and an undef never become a written scalar at all:
        # the walk takes the first to ADR 0008's reject and drops the second
        # before either reaches this guard. Nothing here is about them.
        next unless @{$asked->{entered}};
        $hinted++;
        next if $asked->{died};                  # refused: it was asked about
        push @unasked, "$what (token '$token')" unless @{$asked->{tokens}};
    }
    cmp_ok($hinted, '>', 30,
        "$hinted leaves in the corpus are written as a token Go resolves");
    is_deeply(\@unasked, [],
        'and the guard asked the emitter about every one of them')
        or diag('slipped past the gate: ' . join('; ', @unasked));
};

subtest 'a leaf Go ignores still costs nothing but the gate' => sub {
    # The other half of the gate, and the reason it exists at all: asking the
    # emitter for EVERY leaf costs 5.2ms -> 17.0ms per 1000 string leaves
    # (docs/adr/0017). A string the resolver ignores must not reach the emit.
    for my $leaf ('supersecret', 'localhost', 'a1b2c3-4d5e',
                  'ENC[AES256_GCM,data:aa,iv:bb,tag:cc,type:str]') {
        my $asked = guard_asked($leaf);
        is($asked->{died}, '', "'$leaf' is written");
        is_deeply($asked->{tokens}, [],
            "and the guard never asked the emitter about it");
        is_deeply($asked->{resolved}, [],
            'nor resolved anything through its model of Go');
    }
};

###############################################################################
# 3. WHAT MUST NOT HAVE MOVED. The refusal rule is ADR 0013's and is unchanged.
###############################################################################

subtest 'the refusals and the acceptances are the ones ADR 0013 measured' => sub {
    for my $spelling (qw( 0755 010 0o10 0x1f 1_000 Null TRUE ), '2015-01-01') {
        my $asked = guard_asked(yaml_leaf($spelling));
        like($asked->{died}, qr/\Qcannot write this leaf to a SOPS YAML document\E/,
            "'$spelling' is still refused");
    }
    for my $spelling (qw( 007 08 1e3 0755e0 True null yes off 1:30 _7 0o8
                          123abc 2024-invoice ), '2015-01-01T12:00:00Z') {
        my $asked = guard_asked(yaml_leaf($spelling));
        is($asked->{died}, '', "'$spelling' is still written");
    }

    # docs/adr/0070: `.inf`/`.nan` moved OUT of the refusal set -- the two
    # parse-unambiguous non-finite spellings this file already names above
    # (they carry no digest divergence a bare source could hide, ADR 0026/
    # 0034), and the emitter quotes them instead of croaking.
    for my $spelling (qw( .inf .nan )) {
        my $asked = guard_asked(yaml_leaf($spelling));
        is($asked->{died}, '', "'$spelling' is no longer refused -- docs/adr/0070");
    }
};

subtest 'the sops branch is still not walked' => sub {
    my $asked = do {
        @tokens   = ();
        @resolved = ();
        @entered  = ();
        my $out = File::SOPS::Format::YAML->emit(
            { sops => { lastmodified => '2026-08-20T06:00:00Z', mac => '0755' } },
            mac_covered => 1);
        { tokens => [ @tokens ], resolved => [ @resolved ],
          entered => [ @entered ], out => $out };
    };
    like($asked->{out}, qr/mac: '?0755'?/, 'the metadata leaf is written as it is');
    is_deeply($asked->{tokens}, [], 'and nothing under sops reached the emitter probe');
    is(scalar @{$asked->{entered}}, 2,
        'the guard did see both metadata leaves, and returned on the path');
};

done_testing();
