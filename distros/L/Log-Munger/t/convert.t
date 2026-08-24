#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use Scalar::Util qw(looks_like_number);

BEGIN {
	use_ok('Log::Munger')            || print "Bail out!\n";
	use_ok('Log::Munger::RulesTest') || print "Bail out!\n";
}

my $yaml = <<'YAML';
---
includes:
- base
vars_templated:
  LINE: '(?<who>[% WORD %]) port=(?<port>[% INT %]) load=(?<load>[% NUMBER %]) verdict=(?<verdict>[% WORD %]) shout=(?<shout>[% WORD %]) blob=(?<blob>[% NOTSPACE %])'
convert:
  port: int
  load: float
  who: int
  b_x: int
  verdict: lc
  shout: uc
decompose:
  - field: blob
    type: kv
    prefix: 'b_'
    remove: true
    tests:
      - input: 'x=5'
        result: { b_x: '5' }
rules:
  - name: c
    field: MESSAGE
    anchored: true
    patterns: [LINE]
    tests:
      positive:
        - string: 'host port=022 load=0.50 verdict=DENIED shout=quiet blob=x=5'
          result: { who: 'host', port: '022', load: '0.50', verdict: 'DENIED', shout: 'quiet', blob: 'x=5' }
      negative: ['nope']
YAML

my ( $fh, $file ) = tempfile( 'lm_convert_XXXXXX', SUFFIX => '.yaml', TMPDIR => 1, UNLINK => 1 );
print {$fh} $yaml;
close($fh);

# the file must test clean
my $res = Log::Munger::RulesTest->test( 'file' => $file );
is( scalar( @{ $res->{'errors'} } ), 0, 'convert file tests clean' )
	or diag( join( "\n", @{ $res->{'errors'} } ) );

my $m = Log::Munger->new( 'rules' => [$file] );
my $r = $m->process_item( 'item' => { MESSAGE => 'host port=022 load=0.50 verdict=DENIED shout=quiet blob=x=5' } );

# numeric coercion
ok( looks_like_number( $r->{'port'} ), 'port is numeric' );
is( $r->{'port'}, 22, 'int drops leading zero (022 -> 22)' );
ok( looks_like_number( $r->{'load'} ), 'load is numeric' );
cmp_ok( $r->{'load'}, '==', 0.5, 'float 0.50 -> 0.5' );

# a value that is not a number is left as a string
is( $r->{'who'}, 'host', 'non-numeric field declared int is left untouched' );

# convert applies to a decomposed field (rule-level convert of b_x from the kv)
ok( !exists( $r->{'blob'} ), 'kv source removed' );
is( $r->{'b_x'}, 5, 'decomposed field coerced to int' );
ok( looks_like_number( $r->{'b_x'} ), 'decomposed field is numeric' );

# case folding: lc/uc normalize a captured token whose case varies between the
# sources that produce it (SELinux "denied" vs AppArmor "DENIED")
is( $r->{'verdict'}, 'denied', 'lc folds the captured value down' );
is( $r->{'shout'},   'QUIET',  'uc folds the captured value up' );

# the case folds must not be gated on looks_like_number the way int/float are
my $folded = { 'convert' => { 'v' => 'lc' } };
my $compiled_fold = Log::Munger::LogProcessor->_compile_convert( $folded->{'convert'} );
my %fold_captures = ( 'v' => 'MiXeD' );
Log::Munger::LogProcessor->_convert( { 'convert' => $compiled_fold }, \%fold_captures );
is( $fold_captures{'v'}, 'mixed', 'lc applies to a non-numeric string' );

# the documented aliases resolve to the same two folds
is_deeply(
	Log::Munger::LogProcessor->_compile_convert( { 'a' => 'lower', 'b' => 'LOWERCASE', 'c' => 'Upper', 'd' => 'uppercase' } ),
	{ 'a' => 'lc', 'b' => 'lc', 'c' => 'uc', 'd' => 'uc' },
	'lc/uc aliases normalize'
);

# mac: a MAC address is written four different ways depending on who printed
# it, and a consumer correlating one field against another should not have to
# reconcile them
my $mac_convert = Log::Munger::LogProcessor->_compile_convert( { 'm' => 'mac' } );
foreach my $spelling ( 'C4:D8:D5:3B:8C:4B', 'C4-D8-D5-3B-8C-4B', 'c4d8.d53b.8c4b', 'c4 d8 d5 3b 8c 4b', 'c4d8d53b8c4b' ) {
	my %mac_captures = ( 'm' => $spelling );
	Log::Munger::LogProcessor->_convert( { 'convert' => $mac_convert }, \%mac_captures );
	is( $mac_captures{'m'}, 'c4:d8:d5:3b:8c:4b', "mac normalizes \"$spelling\"" );
}

# not twelve hex digits, so passed through rather than mangled -- this runs
# against whatever the pattern captured, and a pattern can be looser than its
# author intended
my %not_a_mac = ( 'm' => 'unknown' );
Log::Munger::LogProcessor->_convert( { 'convert' => $mac_convert }, \%not_a_mac );
is( $not_a_mac{'m'}, 'unknown', 'mac leaves a value that is not a MAC alone' );

is_deeply(
	Log::Munger::LogProcessor->_compile_convert( { 'a' => 'MAC', 'b' => 'macaddr', 'c' => 'mac_address' } ),
	{ 'a' => 'mac', 'b' => 'mac', 'c' => 'mac' },
	'mac aliases normalize'
);

# an unknown convert type is a load-time error
eval {
	my $bad = { 'convert' => { 'x' => 'stringy' }, 'rules' => [] };
	Log::Munger::LogProcessor->_compile_convert( $bad->{'convert'} );
};
like( $@, qr/unknown \(expected int, float, lc, uc, or mac\)/, 'unknown convert type dies at compile' );

# RulesTest reports a bad file-level convert map
my $badres = Log::Munger::RulesTest->test(
	'hash' => { 'convert' => { 'x' => 'weird' }, 'vars' => {}, 'rules' => [] } );
like( join( "\n", @{ $badres->{'errors'} } ), qr/\.convert is invalid/, 'RulesTest flags bad convert' );

done_testing();
