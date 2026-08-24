#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN { use_ok('Log::Munger::RulesUsable') || print "Bail out!\n"; }

#
# the happy path: a hash carrying a non-empty rules array is usable
#
my $good = { 'rules' => [ { 'patterns' => ['x'] } ] };
my $ok;
eval { $ok = Log::Munger::RulesUsable->usable( 'rules' => $good ); };
is( $@,  '', 'usable: valid rules hash does not die' );
is( $ok, 1,  'usable: returns 1 on success' );

#
# every die condition
#
eval { Log::Munger::RulesUsable->usable( 'rules' => undef ); };
like( $@, qr/\$opts\{rules\} is undef/, 'usable: undef rules dies' );

eval { Log::Munger::RulesUsable->usable( 'rules' => [] ); };
like( $@, qr/not "HASH"/, 'usable: non-hash rules dies' );

eval { Log::Munger::RulesUsable->usable( 'rules' => {} ); };
like( $@, qr/contains no rules/, 'usable: missing rules key dies' );

eval { Log::Munger::RulesUsable->usable( 'rules' => { 'rules' => {} } ); };
like( $@, qr/not "ARRAY"/, 'usable: rules not an array dies' );

eval { Log::Munger::RulesUsable->usable( 'rules' => { 'rules' => [] } ); };
like( $@, qr/contains no rules/, 'usable: empty rules array dies' );

done_testing();
