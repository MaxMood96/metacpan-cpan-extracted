#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok('Log::Munger::RulesTest') || print "Bail out!\n";
}

#
# RulesTest itself: the lint and the test runner it puts every rule file
# through. That the shipped files pass it is asserted for all of them at once
# in t/all_rules_clean.t, so nothing here loads a shipped file for its own sake
# -- the cases below are synthetic, because a lint is only worth trusting if it
# has been shown to fail on the things it claims to catch.
#

#
# Fatal-path: a missing file returns a results hash with fatal set, not a die.
#
my $missing = Log::Munger::RulesTest->test( 'file' => 'this_rule_file_does_not_exist_xyz' );
ok( defined( $missing->{'fatal'} ), 'missing file yields fatal, not a die' );

#
# A clean synthetic rules hash produces no errors.
#
my $good = {
	'vars'  => { 'GOOD' => '(?<good>\\d+)' },
	'rules' => [
		{   'name'  => 'g',
			'gate'  => [ { 'field' => 'PROGRAM', 'values' => ['x'] } ],
			'field' => 'MESSAGE',
			'patterns' => ['GOOD'],
			'tests'    => {
				'positive' => [ { 'string' => 'abc 123', 'result' => { 'good' => '123' } } ],
				'negative' => ['no digits here'],
			},
		},
	],
};
my $gres = Log::Munger::RulesTest->test( 'hash' => $good );
is( scalar( @{ $gres->{'errors'} } ), 0, 'clean synthetic rules: no errors' )
	or diag( "errors:\n" . join( "\n", @{ $gres->{'errors'} } ) );

#
# The lint must catch: un-degrokked grok, an illegal named capture, a missing
# var reference in patterns, and a positive test that fails to match.
#
my $bad = {
	'vars'  => {
		'BADGROK' => '%{FOO:bar}',
		'BADCAP'  => '(?<has-dash>\\d+)',
	},
	'rules' => [
		{   'name'     => 'r1',
			'gate'     => [ { 'field' => 'PROGRAM', 'values' => ['x'] } ],
			'patterns' => ['MISSINGVAR'],
			'tests'    => {
				'positive' => [ { 'string' => '123', 'result' => { 'good' => '123' } } ],
				'negative' => ['abc'],
			},
		},
	],
};
my $bres  = Log::Munger::RulesTest->test( 'hash' => $bad );
my $joined = join( "\n", @{ $bres->{'errors'} } );
ok( scalar( @{ $bres->{'errors'} } ) > 0, 'bad synthetic rules: errors present' );
like( $joined, qr/un-degrokked grok/,        'lint catches leftover grok' );
like( $joined, qr/illegal named-capture/,    'lint catches illegal capture name' );
like( $joined, qr/looks like a var reference/, 'lint catches missing var reference' );
like( $joined, qr/did not match any pattern/,  'positive test failure reported' );

#
# A test case may name a program, and then the rule's gate has to accept it.
# This is the only thing that exercises a gate, so it is worth pinning that it
# fails in both directions rather than merely passing when everything is right.
#
my $gated = sub {
	my (%opts) = @_;
	return {
		'vars'  => { 'LINE' => '(?<who>\\w+) logged in' },
		'rules' => [
			{   'name'  => 'g',
				'gate'  => [ { 'field' => 'PROGRAM', 'values' => [ $opts{'gate'} ] } ],
				'field' => 'MESSAGE',
				'patterns' => ['LINE'],
				'tests'    => {
					'positive' => [ { 'string' => 'neti logged in', 'program' => $opts{'program'}, 'result' => { 'who' => 'neti' } } ],
					'negative' => [ $opts{'negative'} ],
				},
			},
		],
	};
};

# gate accepts the named program: the case runs as any other positive test does
is( scalar( @{ Log::Munger::RulesTest->test(
			'hash' => $gated->( 'gate' => '//^sshd(?:-session)?$//', 'program' => 'sshd-session', 'negative' => 'nope' )
		)->{'errors'} } ),
	0, 'gate accepting the named program: no errors' );

# gate too narrow: the daemon's own lines never reach the rule
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $gated->( 'gate' => 'sshd', 'program' => 'sshd-session', 'negative' => 'nope' )
			)->{'errors'} } ),
	qr/gate 0 on PROGRAM does not accept "sshd-session"/,
	'gate too narrow to admit a named program is an error'
);

# gate too wide: a negative case naming a program it must not claim
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $gated->(
					'gate'     => '//^(?:sshd.*|cron)$//',
					'program'  => 'sshd-session',
					'negative' => { 'string' => 'neti logged in', 'program' => 'cron' }
				)
			)->{'errors'} } ),
	qr/matched a pattern but should not have \(gate accepted "cron"\)/,
	'gate wide enough to claim another daemon is an error'
);

# a negative case whose program the gate refuses passes, whatever the patterns say
is( scalar( @{ Log::Munger::RulesTest->test(
			'hash' => $gated->(
				'gate'     => 'sshd',
				'program'  => 'sshd',
				'negative' => { 'string' => 'neti logged in', 'program' => 'cron' }
			)
		)->{'errors'} } ),
	0, 'a refused program satisfies a negative case on its own' );

# a gated rule whose tests never name a program is warned about, since nothing
# has checked the gate at all
my $ungated = $gated->( 'gate' => 'sshd', 'program' => 'sshd', 'negative' => 'nope' );
delete( $ungated->{'rules'}[0]{'tests'}{'positive'}[0]{'program'} );
like(
	join( "\n", @{ Log::Munger::RulesTest->test( 'hash' => $ungated )->{'warnings'} } ),
	qr/is gated but no test names a program/,
	'a gated rule with no program named anywhere is a warning'
);

# ...and a gateless rule is not warned about, having no gate to check
my $gateless = $gated->( 'gate' => 'sshd', 'program' => 'sshd', 'negative' => 'nope' );
delete( $gateless->{'rules'}[0]{'gate'} );
delete( $gateless->{'rules'}[0]{'tests'}{'positive'}[0]{'program'} );
unlike(
	join( "\n", @{ Log::Munger::RulesTest->test( 'hash' => $gateless )->{'warnings'} } ),
	qr/is gated but no test names a program/,
	'a gateless rule is not warned about'
);

#
# A case may list the fields a convert has to have turned into numbers.
#
# The whole point is that this cannot be done with looks_like_number, which
# answers yes for the captured string either way, so the case that matters is
# the one where the convert is absent and the value still reads as a number.
#
my $converting = sub {
	my (%opts) = @_;
	return {
		'vars'    => { 'LINE' => 'port=(?<port>\\d+) blob=(?<blob>\\S+)' },
		'convert' => $opts{'convert'},
		'decompose' =>
			[ { 'field' => 'blob', 'type' => 'kv', 'prefix' => 'b_', 'remove' => 1, 'tests' => [ { 'input' => 'x=5', 'result' => { 'b_x' => '5' } } ] } ],
		'rules' => [
			{   'name'     => 'c',
				'field'    => 'MESSAGE',
				'patterns' => ['LINE'],
				'tests'    => {
					'positive' => [
						{   'string'  => 'port=44444 blob=x=5',
							'numeric' => $opts{'numeric'},
							'result'  => { 'port' => '44444', 'blob' => 'x=5' },
						},
					],
					'negative' => ['nope'],
				},
			},
		],
	};
};

is( scalar( @{ Log::Munger::RulesTest->test(
			'hash' => $converting->( 'convert' => { 'port' => 'int' }, 'numeric' => ['port'] )
		)->{'errors'} } ),
	0, 'numeric: a converted capture passes' );

like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $converting->( 'convert' => {}, 'numeric' => ['port'] )
			)->{'errors'} } ),
	qr/numeric names "port", which came out as the string "44444"; no convert turned it into a number/,
	'numeric: a capture no convert covers is an error, even though it reads as a number'
);

# a decomposed field is fair game too, since decompose runs before convert
is( scalar( @{ Log::Munger::RulesTest->test(
			'hash' => $converting->( 'convert' => { 'b_x' => 'int' }, 'numeric' => ['b_x'] )
		)->{'errors'} } ),
	0, 'numeric: a decomposed field a convert then coerces passes' );

like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $converting->( 'convert' => { 'port' => 'int' }, 'numeric' => ['nosuchfield'] )
			)->{'errors'} } ),
	qr/numeric names "nosuchfield", which nothing produced/,
	'numeric: naming a field nothing produces is an error'
);

# a rule that converts a field to a number and lists none is warned about
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $converting->( 'convert' => { 'port' => 'int' }, 'numeric' => undef )
			)->{'warnings'} } ),
	qr/converts to a number but no test lists as numeric/,
	'numeric: an unchecked numeric convert is a warning'
);

# ...but a case fold is not a numeric convert and must not be warned about
unlike(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $converting->( 'convert' => { 'blob' => 'lc' }, 'numeric' => undef )
			)->{'warnings'} } ),
	qr/converts to a number but no test lists as numeric/,
	'numeric: an lc convert is not warned about'
);

#
# A case may say what the whole field set looks like once decompose and convert
# have run. This is what puts a decompose under test as the rule uses it, rather
# than in the isolation its own tests give it.
#
my $wired = sub {
	my (%opts) = @_;
	return {
		'vars'      => { 'LINE' => 'user=(?<who>\\w+) (?<blob>\\S+)' },
		'convert'   => { 'b_uid' => 'int' },
		'decompose' => [
			{   'field'  => $opts{'field'},
				'type'   => 'kv',
				'prefix' => 'b_',
				'remove' => 1,
				'tests'  => [ { 'input' => 'uid=5', 'result' => { 'b_uid' => '5' } } ],
			},
		],
		'rules' => [
			{   'name'     => 'w',
				'field'    => 'MESSAGE',
				'patterns' => ['LINE'],
				'tests'    => {
					'positive' => [
						{   'string'   => 'user=neti uid=5',
							'result'   => { 'who' => 'neti', 'blob' => 'uid=5' },
							'enriched' => $opts{'enriched'},
						},
					],
					'negative' => ['nope'],
				},
			},
		],
	};
};

is( scalar( @{ Log::Munger::RulesTest->test(
			'hash' => $wired->( 'field' => 'blob', 'enriched' => { 'who' => 'neti', 'b_uid' => '5' } )
		)->{'errors'} } ),
	0, 'enriched: the field set after a decompose passes' );

# the mutation that matters: the entry works, but nothing feeds it any more
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $wired->( 'field' => 'nosuchcapture', 'enriched' => { 'who' => 'neti', 'b_uid' => '5' } )
			)->{'errors'} } ),
	qr/\.enriched differs from what decompose and convert produced/,
	'enriched: a decompose pointed at a capture nothing produces is caught'
);

# ...and the entry's own tests still pass while that is true, which is the point
is( scalar( grep {/decompose output differs/}
		@{ Log::Munger::RulesTest->test(
				'hash' => $wired->( 'field' => 'nosuchcapture', 'enriched' => { 'who' => 'neti', 'b_uid' => '5' } )
			)->{'errors'} } ),
	0, 'enriched: ...while the decompose entry\'s own tests still pass' );

# exact in both directions, as result is
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $wired->( 'field' => 'blob', 'enriched' => { 'who' => 'neti' } )
			)->{'errors'} } ),
	qr/unexpected key "b_uid"/,
	'enriched: a field that appears unasked for is caught'
);

# a rule whose decompose fires but says nothing about it is warned about
like(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $wired->( 'field' => 'blob', 'enriched' => undef )
			)->{'warnings'} } ),
	qr/decomposes into fields no test says it produces/,
	'enriched: an untested decompose wiring is a warning'
);

# ...but one whose decompose never fires is not
unlike(
	join( "\n", @{ Log::Munger::RulesTest->test(
				'hash' => $wired->( 'field' => 'nosuchcapture', 'enriched' => undef )
			)->{'warnings'} } ),
	qr/decomposes into fields no test says it produces/,
	'enriched: a decompose that never fires is not warned about'
);

#
# decompose entries carry their own tests (input -> expected produced fields);
# RulesTest runs them, passing when correct and reporting when wrong.
#
my $dgood = {
	'decompose' => [
		{   'field' => 'kv', 'type' => 'kv', 'prefix' => 'x_', 'trim' => '<>,', 'remove' => 1,
			'tests' => [ { 'input' => 'a=1, b=<two>,', 'result' => { 'x_a' => '1', 'x_b' => 'two' } } ],
		},
	],
};
is( scalar( @{ Log::Munger::RulesTest->test( 'hash' => $dgood )->{'errors'} } ),
	0, 'correct decompose test passes' );

my $dbad = {
	'decompose' => [
		{   'field' => 'kv', 'type' => 'kv', 'prefix' => 'x_', 'remove' => 1,
			'tests' => [ { 'input' => 'a=1', 'result' => { 'x_a' => 'WRONG' } } ],
		},
	],
};
like(
	join( "\n", @{ Log::Munger::RulesTest->test( 'hash' => $dbad )->{'errors'} } ),
	qr/decompose output differs/,
	'wrong decompose test is caught'
);

done_testing();
