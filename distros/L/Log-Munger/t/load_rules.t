#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

BEGIN {
	use_ok('Log::Munger::RuleFileParser') || print "Bail out!\n";
}

#
# Loading a rule file: the parser object, the shape of what comes back, and the
# include merge.
#
# What a var's regexp actually matches is not asserted here. base.yaml carries
# vars_tests for every one of its primitives and t/all_rules_clean.t runs them,
# so pasting the expanded values into a test would only mean an edit to
# base.yaml has to be made twice.
#

my $parser = Log::Munger::RuleFileParser->new;
isa_ok( $parser, 'Log::Munger::RuleFileParser' );

#
# base: the primitive library every other file inherits
#
my $base = $parser->load( 'file' => 'base' );
is( ref($base), 'HASH', 'load(base) returns a hash ref' );
is( ref( $base->{'vars'} ), 'HASH', 'base .vars is a hash ref' );

# the primitives other rule files are written against. A missing one breaks
# every file that references it, so the set is pinned by name.
my @primitives = qw(
	IP IPv4 IPv6 HOSTNAME HOSTNAMEorIP
	INT FLOAT INTorFLOAT STATUS_WORD
	GREEDYDATA_NO_COLON GREEDYDATA_NO_SEMICOLON GREEDYDATA_NO_BRACKET
);

foreach my $name (@primitives) {
	my $value = $base->{'vars'}{$name};
	if ( !defined($value) || ref($value) ne '' ) {
		fail("base .vars.$name is a plain string");
		next;
	}
	my $compiled = eval { qr/$value/ };
	ok( defined($compiled), "base .vars.$name is present and compiles as a regexp" )
		or diag("$name failed to compile... $@");
}

#
# postfix: an including file
#
# The merge is the thing being checked. Every name base defines has to survive
# into the including file carrying the same value, and the file has to have
# added rules of its own -- a merge that quietly dropped one side would still
# produce a loadable hash.
#
my $postfix = $parser->load( 'file' => 'postfix' );
is( ref( $postfix->{'vars'} ), 'HASH', 'postfix .vars is a hash ref' );

my @lost = grep { !exists( $postfix->{'vars'}{$_} ) } sort keys( %{ $base->{'vars'} } );
is_deeply( \@lost, [], 'postfix inherits every var base defines' );

my @clobbered = grep { $postfix->{'vars'}{$_} ne $base->{'vars'}{$_} }
	grep { exists( $postfix->{'vars'}{$_} ) } sort keys( %{ $base->{'vars'} } );
is_deeply( \@clobbered, [], 'an inherited var keeps the value base gave it' );

cmp_ok( scalar( keys %{ $postfix->{'vars'} } ), '>', scalar( keys %{ $base->{'vars'} } ),
	'postfix adds vars of its own on top of the include' );

is( ref( $postfix->{'rules'} ), 'ARRAY', 'postfix .rules is an array ref' );

# the shipped postfix file dispatches every postfix daemon (23 in the canonical
# logstash set); guard against accidental rule loss
cmp_ok( scalar( @{ $postfix->{'rules'} } ), '>=', 23, 'postfix ships >= 23 dispatch rules' );

# base is a var library and declares no rules of its own
ok( !exists( $base->{'rules'} ), 'base declares no rules' );

#
# a file that does not exist is a die, not an empty hash
#
eval { $parser->load( 'file' => 'definitely_does_not_exist303d01df34' ); };
like( $@, qr/could not be found/, 'loading a missing rule file dies' );

done_testing();
