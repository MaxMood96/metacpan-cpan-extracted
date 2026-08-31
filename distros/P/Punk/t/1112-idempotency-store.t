#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use Punk ();

# The store discipline Punk::Plugin::Idempotency promises, proven rather
# than commented:
#
#   - a receipt written through the plugin NEVER enters the memory tier,
#     and a replay never consults it. A tier is a per-worker copy, and a
#     tier that has not yet seen a write answers "no entry" - which here
#     means "execute the work a second time", the exact failure the
#     plugin exists to prevent. The POD says the path does not exist;
#     this file is why it can.
#   - a response past max_record is served but not recorded, says so in
#     a header, and the next retry of that key executes again.

my $dir = File::Temp->newdir;
my @sink;
my $ran = 0;
my $big_ran = 0;

{
    package TierIdem;
    use Punk;
    logging level => 'warn', to => sub { push @sink, $_[0] };
    cache 'file', dir => "$dir", memory => '1M', memory_ttl => 60;
    plugin 'Idempotency' => {
        scope      => sub { 'alice' },
        max_record => 200,
    };

    post '/orders' => sub {
        my ($c) = @_;
        $ran++;
        $c->json({ order => $ran }, 201);
    }, { idempotent => 1 };

    post '/export' => sub {
        my ($c) = @_;
        $big_ran++;
        $c->text('x' x 500);
    }, { idempotent => 1 };
}
my $app = TierIdem->to_app;

sub req {
    my (%o) = @_;
    my $body = $o{body} // '';
    open my $in, '<', \$body;
    my $r = $app->({
        REQUEST_METHOD => 'POST',
        PATH_INFO      => $o{path},
        QUERY_STRING   => '',
        CONTENT_TYPE   => 'application/json',
        CONTENT_LENGTH => length $body,
        'psgi.input'   => $in,
        HTTP_IDEMPOTENCY_KEY => $o{key},
    });
    my %h = @{ $r->[1] };
    my $b = ref $r->[2] eq 'ARRAY' ? join('', @{ $r->[2] }) : '';
    return ($r->[0], \%h, $b);
}

my $store = TierIdem->punk_app->{cache}{default};
isa_ok($store, 'Punk::Cache', 'the app cache resolved');
{
    my %s = $store->stats;
    is($s{shared}, 0, 'and it is tiered - the store this file is about');
}

# ---- a receipt never enters the tier -----------------------------------------

{
    my ($s1) = req(path => '/orders', body => '{}', key => 'k1');
    is($s1, 201, 'the first request executed');

    my ($s2, $h2, $b2) = req(path => '/orders', body => '{}', key => 'k1');
    is($s2, 201, 'the retry answered');
    is($h2->{'Idempotency-Replayed'}, 'true', '...as a replay');
    is($ran, 1, 'so the receipt IS in the backend - the handler ran once');

    my %s = $store->stats;
    is($s{memory_entries}, 0,
        'and the tier holds NOTHING: the write went straight to the backend');
    is($s{memory_hits} // 0, 0, 'no read was ever answered from the tier');
    is($s{memory_misses} // 0, 0,
        'no read ever CONSULTED the tier - the path does not exist, which is '
      . 'stronger than "it missed"');
}

# the same counters move for ordinary traffic, or the block above proves
# nothing - a tier that counted nothing for anybody would pass it too
{
    $store->set('ordinary', 'v');
    $store->get('ordinary');
    my %s = $store->stats;
    is($s{memory_entries}, 1,
        'ordinary cache traffic DOES populate the tier - the counters are '
      . 'live, so the zeros above are the plugin, not a dead gauge');
}

# ---- the ceiling -------------------------------------------------------------

{
    @sink = ();
    my ($s1, $h1, $b1) = req(path => '/export', body => '{}', key => 'e1');
    is($s1, 200, 'an oversized response is served normally');
    is(length $b1, 500, 'in full');
    is($h1->{'Idempotency-Recorded'}, 'false',
        'and says it was not recorded');
    ok((grep { /max_record/ } @sink),
        'the refusal is logged at warn, naming max_record');

    my ($s2, $h2) = req(path => '/export', body => '{}', key => 'e1');
    is($s2, 200, 'the retry answers');
    ok(!defined $h2->{'Idempotency-Replayed'}, 'but nothing was replayable');
    is($big_ran, 2, 'so it executed again - replayability was given up');
    is($h2->{'Idempotency-Recorded'}, 'false', 'and was refused again');
}

{
    my ($s1, $h1) = req(path => '/orders', body => '{}', key => 'k2');
    ok(!defined $h1->{'Idempotency-Recorded'},
        'a response under the ceiling carries no refusal header');
    my ($s2, $h2) = req(path => '/orders', body => '{}', key => 'k2');
    is($h2->{'Idempotency-Replayed'}, 'true', 'and replays as ever');
}

# ---- what fails at boot ------------------------------------------------------

for my $bad (0, -1, 'lots') {
    my $err = do { local $@; eval {
        package BadCeiling;
        use Punk;
        cache 'file', dir => "$dir";
        plugin 'Idempotency' => { scope => sub { 'x' }, max_record => $bad };
    }; $@ };
    like($err, qr/max_record must be a positive number of bytes/,
        "max_record => '$bad' croaks at boot");
}

done_testing;
