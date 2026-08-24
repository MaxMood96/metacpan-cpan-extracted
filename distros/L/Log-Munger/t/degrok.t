#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use YAML::XS qw(Load);

BEGIN { use_ok('Log::Munger::Degrok') || print "Bail out!\n"; }

#
# string(): grok "%{TOKEN}" -> "[% TOKEN %]" and "%{TOKEN:name}" -> capture
#
is( Log::Munger::Degrok->string( 'string' => '%{FOO}' ), '[% FOO %]', 'string: bare token' );
is(
	Log::Munger::Degrok->string( 'string' => '%{FOO:bar}' ),
	'(?<bar>[% FOO %])',
	'string: capturing token'
);
is(
	Log::Munger::Degrok->string( 'string' => '%{FOO:bar} and %{BAZ:qux}' ),
	'(?<bar>[% FOO %]) and (?<qux>[% BAZ %])',
	'string: multiple tokens on one line'
);
is( Log::Munger::Degrok->string( 'string' => 'no grok here' ), 'no grok here', 'string: passthrough' );

# undef input dies
eval { Log::Munger::Degrok->string( 'string' => undef ); };
like( $@, qr/\$opts\{string\} is undef/, 'string: undef dies' );

#
# file(): every line is translated
#
my ( $ffh, $fpath ) = tempfile( UNLINK => 1 );
print {$ffh} "a %{FOO} b\n%{BAR:baz}\n";
close($ffh);
my $file_out = Log::Munger::Degrok->file( 'file' => $fpath );
is( $file_out, "a [% FOO %] b\n(?<baz>[% BAR %])\n", 'file: translates each line' );

#
# grok2rules(): split into vars (plain) and vars_templated (contain grok),
# degrokking the templated ones. Build a small grok patterns file.
#
sub write_grok {
	my ($body) = @_;
	my ( $fh, $path ) = tempfile( UNLINK => 1 );
	print {$fh} $body;
	close($fh);
	return $path;
}

my $grok = write_grok(
	    "YEAR (?>\\d\\d){1,2}\n"
	  . "MYINT (?:[+-]?[0-9]+)\n"
	  . "MYSTAMP %{YEAR}-%{MYINT}\n"
	  . "BASE10NUM overridden\n" );

my $basic = Load( Log::Munger::Degrok->grok2rules( 'file' => $grok ) );
is_deeply(
	[ sort keys %{ $basic->{'vars'} } ],
	[ 'BASE10NUM', 'MYINT', 'YEAR' ],
	'grok2rules: plain patterns land in vars'
);
is_deeply( [ keys %{ $basic->{'vars_templated'} } ], ['MYSTAMP'], 'grok2rules: grok patterns land in vars_templated' );
# the raw source newline is retained here (RuleFileParser strips it at load time)
like(
	$basic->{'vars_templated'}{'MYSTAMP'},
	qr/\A\Q[% YEAR %]-[% MYINT %]\E\s*\z/,
	'grok2rules: templated value is degrokked'
);

#
# overwrite validation: no_silent is a documented, accepted value (regression:
# it was rejected by a typo'd validation table). An unknown value dies.
#
eval { Log::Munger::Degrok->grok2rules( 'file' => $grok, 'overwrite' => 'no_silent' ); };
is( $@, '', 'grok2rules: overwrite=no_silent is accepted' );

eval { Log::Munger::Degrok->grok2rules( 'file' => $grok, 'overwrite' => 'bogus' ); };
like( $@, qr/expected values/, 'grok2rules: unknown overwrite value dies' );

#
# includes: resolving/merging an include must not die (regression:
# Log::Munger::RuleFileParser was not loaded, so this path threw
# "Can't locate object method new"). base carries BASE10NUM, so under
# no_silent the local BASE10NUM must be dropped in favor of the include.
#
my $with_inc;
eval { $with_inc = Log::Munger::Degrok->grok2rules( 'file' => $grok, 'includes' => ['base'], 'overwrite' => 'no_silent' ); };
is( $@, '', 'grok2rules: includes path does not die' );

SKIP: {
	skip 'includes path died', 3 if ( $@ || !defined($with_inc) );
	my $inc = Load($with_inc);
	is_deeply( $inc->{'includes'}, ['base'], 'grok2rules: includes recorded' );
	ok( !exists( $inc->{'vars'}{'BASE10NUM'} ), 'grok2rules: no_silent skips a name already in an include' );
	ok( exists( $inc->{'vars'}{'MYINT'} ), 'grok2rules: names not in the include still pass through' );
}

# a missing grok file dies
eval { Log::Munger::Degrok->grok2rules( 'file' => '/this/does/not/exist_xyz' ); };
like( $@, qr/Failed to read/, 'grok2rules: unreadable file dies' );

done_testing();
