#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN { use_ok('Log::Munger::RulesTemplateOrder') || print "Bail out!\n"; }

#
# depends_for_rules_hash: extract the [% VAR %] references from each templated
# var, in order of first appearance.
#
my $hash = {
	'vars'           => { 'A' => 'a', 'B' => 'b' },
	'vars_templated' => { 'C' => '[% A %][% D %]', 'D' => '[% B %]' },
};

my $depends = Log::Munger::RulesTemplateOrder->depends_for_rules_hash( 'rules' => $hash );
is_deeply( $depends->{'C'}, [ 'A', 'D' ], 'depends: C references A then D' );
is_deeply( $depends->{'D'}, ['B'],        'depends: D references B' );

#
# order_for_rules_hash: a templated var must be scheduled after everything it
# depends on. C depends on D, so D must come before C. Plain vars (already
# available) are excluded from the schedule.
#
my $order = Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => $hash );
is( ref($order), 'ARRAY', 'order: returns an arrayref' );
my %pos = map { $order->[$_] => $_ } ( 0 .. $#{$order} );
ok( exists( $pos{'C'} ) && exists( $pos{'D'} ), 'order: both templated vars scheduled' );
ok( $pos{'D'} < $pos{'C'}, 'order: dependency (D) precedes dependent (C)' );
ok( !exists( $pos{'A'} ) && !exists( $pos{'B'} ), 'order: plain vars are not in the schedule' );

#
# a rules-only file (no vars / vars_templated) has nothing to order and must
# return an empty schedule rather than dying inside Algorithm::Dependency.
#
my $empty = Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => { 'rules' => [] } );
is_deeply( $empty, [], 'order: nothing to order yields []' );
is_deeply(
	Log::Munger::RulesTemplateOrder->depends_for_rules_hash( 'rules' => { 'rules' => [] } ),
	{}, 'depends: no vars_templated yields {}'
);

#
# die conditions
#
eval { Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => undef ); };
like( $@, qr/\$opts\{rules\} is undef/, 'order: undef rules dies' );

eval { Log::Munger::RulesTemplateOrder->order_for_rules_hash( 'rules' => [] ); };
like( $@, qr/not HASH/, 'order: non-hash rules dies' );

eval {
	Log::Munger::RulesTemplateOrder->depends_for_rules_hash(
		'rules' => { 'vars_templated' => [] } );
};
like( $@, qr/vars_templated.*not HASH/, 'depends: non-hash vars_templated dies' );

#
# file-based entry points, driven off the shipped base rule file
#
my $file_order = Log::Munger::RulesTemplateOrder->order_for_rules_file( 'file' => 'base' );
is( ref($file_order), 'ARRAY', 'order_for_rules_file(base): arrayref' );
ok( scalar(@{$file_order}) > 0, 'order_for_rules_file(base): non-empty schedule' );

my $file_depends = Log::Munger::RulesTemplateOrder->depends_for_rules_file( 'file' => 'base' );
is( ref($file_depends), 'HASH', 'depends_for_rules_file(base): hashref' );

# every dependency named by a templated var in base must itself be scheduled
# somewhere before it -- a real topological-order check against real data
my %fpos = map { $file_order->[$_] => $_ } ( 0 .. $#{$file_order} );
my $order_ok = 1;
foreach my $var ( keys %{$file_depends} ) {
	next if ( !exists( $fpos{$var} ) );
	foreach my $dep ( @{ $file_depends->{$var} } ) {
		# only templated deps appear in the schedule; plain-var deps do not
		next if ( !exists( $fpos{$dep} ) );
		$order_ok = 0 if ( $fpos{$dep} >= $fpos{$var} );
	}
}
ok( $order_ok, 'base: every templated dependency precedes its dependent' );

done_testing();
