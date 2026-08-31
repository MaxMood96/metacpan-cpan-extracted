#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use PunkTest;
use Punk::Plugin::Idempotency ();

# Punk::Plugin::Idempotency's SYNOPSIS, executed.
#
# Read out of the POD rather than copied, the way t/0001-synopsis.t reads
# Punk.pm's: a copy drifts, and the front page of a correctness feature is
# the worst place for prose that no longer runs.
#
# Two substitutions, and only two, both because the page shows a DEPLOYMENT
# and this is a test: the cache directory becomes a temporary one, and the
# scope stops reading current_user - the auth battery is a different test,
# and the page's point about the scope is that it is YOURS. Everything else
# - the keyword, the options, the route and its handler - runs as written.

my $pm = $INC{'Punk/Plugin/Idempotency.pm'}
    or plan skip_all => 'cannot locate Punk::Plugin::Idempotency';

my $synopsis = do {
    open my $fh, '<', $pm or plan skip_all => "cannot read $pm: $!";
    local $/;
    my $pod = <$fh>;
    close $fh;
    $pod =~ /^=head1 SYNOPSIS\s*\n(.*?)^=head1 /ms
        or plan skip_all => 'no SYNOPSIS in Punk::Plugin::Idempotency';
    $1;
};

# The verbatim block, dedented. Anything not indented is prose.
my $code = join "\n",
           map  { my $l = $_; $l =~ s/\A    //; $l }
           grep { /\A(?:    |\s*\z)/ }
           split /\n/, $synopsis;

like($code, qr/scope\s*=>/,
    'the SYNOPSIS still passes a scope - if that stops being true the rest '
  . 'of this file is testing something else');
like($code, qr/idempotent\s*=>\s*1/, 'and still opts the route in');

my $dir = File::Temp::tempdir(CLEANUP => 1);
$code =~ s{'/var/cache/app'}{'$dir'}                      or die 'no cache dir';
$code =~ s{\$_\[0\]->current_user->\{id\}}{\$_[0]->env->{HTTP_X_USER}}
                                                          or die 'no scope';

# What the SYNOPSIS calls but does not show, because it is the application's.
my $created = 0;
{
    package MyApp;
    sub create_order { $created++; return { order => 'o-1', got => $_[0] } }
}

my $ok = eval "$code\n1";
ok($ok, 'the SYNOPSIS compiles and runs') or diag $@;

SKIP: {
    skip 'the SYNOPSIS did not compile', 7 unless $ok;

    my $app = MyApp->to_app;
    ok($app, 'and the application it describes compiles');

    my %env = (HTTP_X_USER => 'alice', HTTP_IDEMPOTENCY_KEY => 'syn-1');
    my $r1 = hit($app, method => 'POST', path => '/orders',
                 body => '{"item":1}', env => {%env});
    is($r1->[0], 201, 'the order route answers 201, as written');
    is($created, 1, 'and created the order');

    my $r2 = hit($app, method => 'POST', path => '/orders',
                 body => '{"item":1}', env => {%env});
    is($r2->[0], 201, 'the retry answers the same');
    my %h = @{ $r2->[1] };
    is($h{'Idempotency-Replayed'}, 'true', '...as a replay');
    is($created, 1,
        'so "at most once per key" - the comment in the SYNOPSIS - is true');
    is(join('', @{ $r2->[2] }), join('', @{ $r1->[2] }),
        'and the client got byte-for-byte what the first caller got');
}

done_testing;
