#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use Punk::Test;

# The date half of Punk::Plugin::ConditionalGet: `last_modified => sub {}`,
# answered before the handler runs. The comparison is exact - the date the
# client was given is the date we would send - which is the psf_not_modified
# convention the file path has always used, so an unrecognised or obsolete
# date form costs a re-send and can never produce a wrong 304.

# an IMF-fixdate without strftime, so the test is locale-proof the same way
# ps_http_date is
sub http_date {
    my ($t) = @_;
    my @d = qw(Sun Mon Tue Wed Thu Fri Sat);
    my @m = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime $t;
    return sprintf '%s, %02d %s %04d %02d:%02d:%02d GMT',
        $d[$wday], $mday, $m[$mon], $year + 1900, $hour, $min, $sec;
}

my $EPOCH = 1700000000;
my $DATE  = http_date($EPOCH);

{
    package App;
    use Punk;
    plugin 'ConditionalGet';
    our %RAN;
    get '/feed' => sub { $RAN{feed}++; $_[0]->text('the feed') },
        { last_modified => sub { $EPOCH } };
    get '/both' => sub { $RAN{both}++; $_[0]->text('both') },
        { etag => sub { 'v7' }, last_modified => sub { $EPOCH } };
    get '/future' => sub { $RAN{future}++; $_[0]->text('x') },
        { last_modified => sub { time + 5000 } };
    get '/unknown' => sub { $RAN{unknown}++; $_[0]->text('x') },
        { last_modified => sub { undef } };
    get '/broken' => sub { $RAN{broken}++; $_[0]->text('x') },
        { last_modified => sub { die "no clock\n" } };
    get '/off' => sub { $RAN{off}++; $_[0]->text('x') },
        { last_modified => 0 };
}

my $t = Punk::Test->new('App');

# ---- the 200 carries the date, the exact date comes back as a 304 ------------
$t->get_ok('/feed')->status_is(200)
  ->header_is('Last-Modified' => $DATE)
  ->content_is('the feed');
is($App::RAN{feed}, 1, 'the handler ran for the 200');

# the feed-reader transcript: If-Modified-Since only, no If-None-Match
$t->get_ok('/feed', headers => { 'If-Modified-Since' => $DATE })
  ->status_is(304)
  ->header_is('Last-Modified' => $DATE)
  ->header_is('Content-Type' => undef)
  ->header_is('Content-Length' => undef)
  ->content_is('');
is($App::RAN{feed}, 1, 'the 304 was answered before the handler');

# ---- dates that do not match cost a re-send, never a wrong 304 ---------------
$t->get_ok('/feed', headers => { 'If-Modified-Since' => http_date($EPOCH - 3600) })
  ->status_is(200);
is($App::RAN{feed}, 2, 'a stale date runs the handler');

# the obsolete RFC 850 form: no parser exists, exact-match declines it
$t->get_ok('/feed', headers => { 'If-Modified-Since' => 'Tuesday, 14-Nov-23 22:13:20 GMT' })
  ->status_is(200);

# garbage is a re-send too
$t->get_ok('/feed', headers => { 'If-Modified-Since' => 'not a date' })
  ->status_is(200);

# ---- precedence: If-None-Match wins, If-Modified-Since is ignored ------------
$t->get_ok('/both')->status_is(200)
  ->header_is('ETag' => '"v7"')
  ->header_is('Last-Modified' => $DATE);

$t->get_ok('/both', headers => { 'If-None-Match' => '"nope"',
                                 'If-Modified-Since' => $DATE })
  ->status_is(200, 'a mismatching If-None-Match ignores a matching date');

$t->get_ok('/both', headers => { 'If-None-Match' => '"v7"',
                                 'If-Modified-Since' => http_date(0) })
  ->status_is(304, 'a matching If-None-Match ignores a stale date')
  ->header_is('ETag' => '"v7"')
  ->header_is('Last-Modified' => $DATE);

# If-None-Match on a route with no etag validator: the date must stay ignored
$t->get_ok('/feed', headers => { 'If-None-Match' => '"anything"',
                                 'If-Modified-Since' => $DATE })
  ->status_is(200, 'If-None-Match present means the date is not consulted');

# ---- HEAD is conditional too --------------------------------------------------
$t->head_ok('/feed', headers => { 'If-Modified-Since' => $DATE })
  ->status_is(304);

# ---- a future epoch is clamped to now -----------------------------------------
{
    my $before = time;
    $t->get_ok('/future')->status_is(200);
    my $after = time;
    my $lm = $t->header('Last-Modified');
    my %ok = map { http_date($_) => 1 } $before .. $after;
    ok($lm && $ok{$lm}, "a future epoch advertises now, not the future ($lm)");
}

# ---- undef contributes nothing ------------------------------------------------
$t->get_ok('/unknown', headers => { 'If-Modified-Since' => $DATE })
  ->status_is(200)
  ->header_is('Last-Modified' => undef);

# ---- a croaking validator is the app's 500, before the handler ----------------
$t->get_ok('/broken')->status_is(500)->content_like(qr/no clock/);
is($App::RAN{broken}, undef, 'the handler never ran behind a broken validator');

# ---- last_modified => 0 is saying nothing -------------------------------------
$t->get_ok('/off', headers => { 'If-Modified-Since' => $DATE })
  ->status_is(200)
  ->header_is('Last-Modified' => undef);

# ---- cache safety: an lm-only route still hands out a validator ---------------
$t->get_ok('/feed', headers => { Cookie => 'session=abc' })
  ->status_is(200)
  ->header_is('Cache-Control' => 'private')
  ->header_like('Vary' => qr/Accept-Encoding/);

# ---- the boot croaks -----------------------------------------------------------
{
    package BadApp;
    use Punk;
    main::like(
        main::exception(sub { get '/x' => sub { }, { last_modified => 1 } }),
        qr/takes a coderef.*no body form/s,
        'last_modified => 1 croaks: a body has no timestamp to derive');
    main::like(
        main::exception(sub { get '/y' => sub { }, { last_modified => 'now' } }),
        qr/takes a coderef/,
        'and so does any other truthy non-coderef');
}
sub exception { my ($cb) = @_; local $@; eval { $cb->() }; $@ }

# ---- without the plugin the option is inert ------------------------------------
{
    package Plain;
    use Punk;
    our $RAN = 0;
    get '/feed' => sub { $RAN++; $_[0]->text('x') },
        { last_modified => sub { $EPOCH } };
}
my $p = Punk::Test->new('Plain');
$p->get_ok('/feed', headers => { 'If-Modified-Since' => $DATE })
  ->status_is(200)
  ->header_is('Last-Modified' => undef);
is($Plain::RAN, 1, 'no plugin, no check, the handler runs');

done_testing;
