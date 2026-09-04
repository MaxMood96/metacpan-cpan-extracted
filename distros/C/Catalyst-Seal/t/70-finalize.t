#!/usr/bin/env perl
use strict;
use warnings;

use FindBin ();
use lib "$FindBin::Bin/lib";

use Test::More;
use Scalar::Util ();

BEGIN { $ENV{CATALYST_DEBUG} = 0 }

require Catalyst::Seal;
use Catalyst::Seal::Finalize ();
require TestApp;
require SealTest;

my $app = TestApp->psgi_app;

sub res {
    my ($qs) = @_;
    my $r = SealTest::response($app, PATH_INFO => '/enc', QUERY_STRING => $qs);
    my %h;
    for (my $i = 0; $i < @{ $r->[1] }; $i += 2) {
        $h{ lc $r->[1][$i] } = $r->[1][$i + 1];
    }
    # kind=fh returns a filehandle body, which is not an arrayref.
    my $body = $r->[2];
    my $text = '';
    if (ref $body eq 'ARRAY') {
        $text = join '', map { defined $_ ? $_ : '' } @$body;
    }
    elsif (defined $body) {
        while (defined(my $chunk = $body->getline)) { $text .= $chunk }
        $body->close if $body->can('close');
    }

    return { status => $r->[0], headers => \%h, body => $text };
}

ok(
    Catalyst->can('finalize_encoding') == \&Catalyst::Seal::Finalize::_finalize_encoding,
    'finalize_encoding is the memoised version',
) or plan skip_all => 'the finalize step did not apply on this Catalyst';

# ------------------------------------------------- the key must see the charset
#
# HTTP::Headers::content_type returns the media type with its parameters
# stripped, so "text/plain" and "text/plain; charset=ISO-8859-1" both come back
# as "text/plain". Keying the decision on that collapses the two, and whichever
# ran first decides for the other: a response with a manual charset gets its
# body encoded a second time. The memo keys on the raw header instead.
#
# Driving them in both orders, in one process, is the whole point. A single
# order can pass with the bug present.
{
    Catalyst::Seal::Finalize::_clear();
    my $plain  = res('ct=text/plain&kind=wide');
    my $latin  = res('ct=text/plain%3B%20charset=ISO-8859-1&kind=wide');

    is($plain->{headers}{'content-type'}, 'text/plain; charset=UTF-8',
        'no charset: encoded and the charset appended');
    is($latin->{headers}{'content-type'}, 'text/plain; charset=ISO-8859-1',
        'a manual charset is left alone, after the plain one was cached');

    Catalyst::Seal::Finalize::_clear();
    my $latin2 = res('ct=text/plain%3B%20charset=ISO-8859-1&kind=wide');
    my $plain2 = res('ct=text/plain&kind=wide');

    is($latin2->{headers}{'content-type'}, 'text/plain; charset=ISO-8859-1',
        'and in the other order');
    is($plain2->{headers}{'content-type'}, 'text/plain; charset=UTF-8',
        'the plain one is still encoded after the manual one was cached');

    isnt($latin->{body}, $plain->{body},
        'the two bodies really did take different paths');
}

# ---------------------------------------------------------- the encodable set

{
    Catalyst::Seal::Finalize::_clear();

    is(res('ct=application/json&kind=wide')->{headers}{'content-type'},
        'application/json', 'a non-encodable type is left alone');
    is(res('ct=text/plain&cenc=gzip&kind=wide')->{headers}{'content-type'},
        'text/plain', 'a content-encoding other than identity suppresses encoding');
    is(res('ct=text/plain&cenc=identity&kind=wide')->{headers}{'content-type'},
        'text/plain; charset=UTF-8', 'identity does not');

    # Distinct inputs, distinct entries: a memo that collapsed them would have
    # failed the assertions above, and this says so directly.
    cmp_ok(Catalyst::Seal::Finalize::memo_size(), '>=', 3,
        'each distinct input got its own entry');
}

# ------------------------------------------------------- runtime encoding

# $c->encoding is a documented per-request call, so it is in the key. If it were
# not, the first request through a content type would decide for every later one
# whatever the application asked for.
{
    Catalyst::Seal::Finalize::_clear();

    my $utf8 = res('ct=text/plain&kind=wide&encoding=UTF-8');
    my $none = res('ct=text/plain&kind=wide&encoding=clear');
    # kind=latin, because the snowman in kind=wide does not map to Latin-1 and
    # the encoder dies. Stock dies the same way; that is covered in the parity
    # table, and is not what this block is about.
    my $l1   = res('ct=text/plain&kind=latin&encoding=ISO-8859-1');

    is($utf8->{headers}{'content-type'}, 'text/plain; charset=UTF-8',
        'UTF-8 encodes');
    is($none->{headers}{'content-type'}, 'text/plain',
        'clear_encoding suppresses encoding, after UTF-8 was cached');
    is($l1->{headers}{'content-type'}, 'text/plain; charset=ISO-8859-1',
        'a different encoding is not served the UTF-8 answer');

    isnt($utf8->{body}, $none->{body}, 'and the bodies differ accordingly');
}

# -------------------------------------------------------------- body shapes

{
    Catalyst::Seal::Finalize::_clear();
    is(res('ct=text/plain&kind=array')->{headers}{'content-type'}, 'text/plain',
        'an arrayref body is not encoded');
    is(res('ct=text/plain&kind=fh')->{headers}{'content-type'}, 'text/plain',
        'a filehandle body is not encoded');
    is(res('ct=text/plain&kind=undef')->{headers}{'content-type'}, 'text/plain',
        'an absent body is not encoded');
    is(res('ct=text/plain&kind=ascii')->{body}, 'plain ascii',
        'an ascii body survives encoding unchanged');
}

# --------------------------------------------------------------------- cap

{
    local $Catalyst::Seal::Finalize::MAX_KEYS = 4;
    Catalyst::Seal::Finalize::_clear();

    res("ct=text/plain%3B%20x=$_&kind=wide") for 1 .. 100;

    cmp_ok(Catalyst::Seal::Finalize::memo_size(), '<=', 4,
        'the decision memo stopped growing at the cap');
    cmp_ok(Catalyst::Seal::Finalize::capped(), '>', 0, 'and said so');

    # Still correct past the cap, which is the point of capping rather than
    # clearing.
    is(res('ct=text/plain%3B%20charset=ISO-8859-1&kind=wide')->{headers}{'content-type'},
        'text/plain; charset=ISO-8859-1', 'decisions are still right past the cap');
}
Catalyst::Seal::Finalize::_clear();

# ----------------------------------------------------------------- DESTROY

{
    ok(
        Catalyst::Response->can('DESTROY') == \&Catalyst::Seal::Finalize::_response_destroy,
        'the response destructor is the eval version',
    );

    # DEMOLISH still runs, once, and still gets the global destruction flag.
    #
    # The destructor is called directly rather than by letting the object fall
    # out of scope. The earlier version did the latter and CPAN Testers failed
    # it on 5.16.3, 5.18.0, 5.18.2 and 5.18.4 where it passed on 5.42.
    #
    # Reproduced on 5.20.3 in docker: there the object is not freed at the
    # `undef`, it is freed when the enclosing block exits, and that happens
    # *after* the `local` on the glob has been restored. So the real DEMOLISH
    # ran and the localised counter stayed at nought. The test was measuring
    # the order the interpreter unwinds a scope in, not this distribution.
    #
    # The same run confirmed there is nothing wrong with the code: on 5.20,
    # sealed and stock call DEMOLISH exactly once for each of `undef $r`,
    # scope exit, scope exit after undef, and reassignment. The replacement
    # destructor is faithful.
    #
    # The assertions sit inside the block on purpose. $r is still alive here,
    # and its own destruction at block exit calls DEMOLISH a second time.
    {
        my @calls;
        no warnings 'redefine', 'once';
        local *Catalyst::Response::DEMOLISH = sub { push @calls, $_[1]; return };

        my $r = Catalyst::Response->new;
        Catalyst::Seal::Finalize::_response_destroy($r);

        is(scalar @calls, 1, 'DEMOLISH ran exactly once');
        ok(defined $calls[0], 'and was given the in-global-destruction flag');
    }

    # And the destructor really is what perl will call, so the above is not
    # testing a subroutine nothing reaches.
    is(
        Catalyst::Response->can('DESTROY'),
        \&Catalyst::Seal::Finalize::_response_destroy,
        'and that is the DESTROY perl will call',
    );

    # A subclass falls through to Moose, the way the stock destructor does.
    {
        package SealTest::Response::Sub;
        our @ISA = ('Catalyst::Response');
    }
    my $ok = eval { my $r = bless {}, 'SealTest::Response::Sub'; undef $r; 1 };
    ok($ok, 'a subclass instance destroys without blowing up') or diag $@;
}

done_testing;
