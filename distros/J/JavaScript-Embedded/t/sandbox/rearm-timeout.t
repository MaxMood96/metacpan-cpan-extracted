use lib './lib';
use strict;
use warnings;
use JavaScript::Embedded;
use Test::More;

#
# The watchdog is a budget PER EXECUTION, not a deadline measured from the
# moment the context was built.
#
# It used to be the latter: new(timeout => N) stored N as an absolute point
# on the clock, so a context was born already owing N seconds to a process
# that had been running longer than that, and nothing re-armed it. Every
# eval() after that point died instantly with "RangeError: execution
# timeout" without any JavaScript having run - and the engine never
# recovered. What follows is a host process that is merely busy, which must
# cost a later script nothing.
#

my $js = JavaScript::Embedded->new( timeout => 1 );
$js->eval('function ping(){ return 42 } var Deep = { ping: function(){ return 43 } }');

is $js->eval('ping()'), 42, 'a fresh context runs';

# Busy for three times the budget, executing no JavaScript at all. Burning
# CPU rather than sleeping so this also fails against the old CPU clock.
my $start = time();
my $spin  = 0;
$spin++ while time() - $start < 3;

is $js->eval('ping()'), 42, 'eval still works after the process idled past the budget';
ok defined( $js->get_object('Deep.ping') ), 'so does get_object, which evaluates the name';
is $js->get_object('Deep.ping')->(), 43, 'and the function it resolved still calls';

# None of which may cost us the watchdog itself.
eval { $js->eval('while(1){}') };
ok $@ =~ /timeout/, 'a runaway script still trips the watchdog';

eval { $js->eval('while(1){}') };
ok $@ =~ /timeout/, 'and trips it again on the next execution';

is $js->eval('ping()'), 42, 'the engine is still usable after a timeout';

# A budget set later behaves the same way.
$js->set_timeout(2);
$start = time();
$spin++ while time() - $start < 4;
is $js->eval('ping()'), 42, 'set_timeout also survives an idle host process';

$js->set_timeout(0);
$spin++ while time() - $start < 6;
is $js->eval('ping()'), 42, 'a disabled watchdog stays disabled';

done_testing();
