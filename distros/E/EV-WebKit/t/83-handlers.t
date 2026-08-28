use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use Scalar::Util qw(weaken);
use EV; use EV::WebKit;

# The constructor used to be the ONLY way to set a handler, so anything that
# wanted to observe a browser had to BE the code that created it. A layer built
# on top (EV::WebKit::Control) has to chain an existing handler -- and it must do
# that through the public API, not by reaching into the object.

my @seen;
my $b = EV::WebKit->new(window => [300,200], ephemeral => 1,
                        on_console => sub { push @seen, "orig: $_[0]" });

is(ref $b->on_console, 'CODE', 'on_console reads back the handler given to new()');
is($b->on_navigate, undef, 'an unset handler reads back undef');

# set, chaining the previous one -- the pattern Control uses
my $prev = $b->on_console;
my @mine;
my $ret = $b->on_console(sub { $prev->(@_); push @mine, "mine: $_[0]" });
isa_ok($ret, 'EV::WebKit', 'the setter returns $b, so it');

$b->load_html('<script>console.log("hi")</script>', sub { EV::break });
TWK::run_with_timeout(15);
{ my $t = EV::timer(1, 0, sub { EV::break }); EV::run }
ok(scalar(grep { /orig: log: hi/ } @seen), 'the chained-to original handler still runs');
ok(scalar(grep { /mine: log: hi/ } @mine), '...and so does the new one');

my $ok = eval { $b->on_load('not a coderef'); 1 };
ok(!$ok && $@ =~ /code reference/, 'a non-coderef handler croaks, like every callback in this API');

$b->on_console(undef);
is($b->on_console, undef, 'a handler can be cleared');
$b->quit;

# on_console must work when it was NOT given to new(): the console proxy is a
# user script, so it has to be installed on demand.
{
    my @late;
    my $c = EV::WebKit->new(window => [300,200], ephemeral => 1);   # NO on_console
    $c->on_console(sub { push @late, $_[0] });
    $c->load_html('<script>console.log("late")</script>', sub { EV::break });
    TWK::run_with_timeout(15);
    { my $t = EV::timer(1, 0, sub { EV::break }); EV::run }
    ok(scalar(grep { /log: late/ } @late),
        'on_console set after construction still receives console output (proxy installed lazily)')
        or diag('the console proxy is only installed when on_console is given to new()');
    $c->quit;
}

# The accessor itself must not make the instance uncollectable. (What the
# CALLER's closure captures is the caller's business -- but the accessor adds no
# reference of its own.)
{
    my $wb;
    {
        my $d = EV::WebKit->new(window => [200,150], ephemeral => 1);
        weaken($wb = $d);
        $d->on_navigate(sub { });   # captures nothing
        $d->quit;
    }
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    ok(!defined $wb, 'setting a handler does not make the instance uncollectable');
}

# A handler passed to new() is validated there, not at fire time.
#
# The accessors croak on a non-CODE value, and on_request/on_response croak in
# the constructor -- but the accessor-backed handlers skipped both when passed
# to new(). The value was stored, and the only symptom came much later: the
# dispatch eval turned "Not a CODE reference" into a warn and the handler
# simply never ran.
{
    for my $h (qw(on_error on_load on_close on_navigate on_console
                  on_dialog on_policy on_file_chooser on_download on_authenticate
                  on_request on_response)) {
        eval { EV::WebKit->new(window => [200,150], ephemeral => 1, $h => 'not-a-coderef') };
        like($@, qr/\Q$h\E must be a code reference/, "new($h => string) croaks");
    }
    my $b = eval { EV::WebKit->new(window => [200,150], ephemeral => 1, on_close => sub { }) };
    ok($b, '...and a real code reference is still accepted') and $b->quit;
}

done_testing;
