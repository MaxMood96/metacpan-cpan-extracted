#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Slurp qw(write_file);

BEGIN {
	use_ok('Log::Munger::RuleFileParser') || print "Bail out!\n";
}

#
# What only exists once includes collide.
#
# The whole point of includes is that a file can pull in base and then override
# what it needs to, so the properties below are all about who wins: the file
# over its includes, an earlier include over a later one, and a plain var over
# an include's templated one. Alongside those live the two ways a templated var
# can be unresolvable -- a reference to a name defined nowhere and a circular
# reference -- both of which have to die loudly at load rather than quietly
# producing a var that matches nothing.
#

my $dir = tempdir( 'CLEANUP' => 1 );

write_file(
	$dir . '/deep.yaml', "---
vars:
  ONLY_DEEP: 'deep'
"
);

write_file(
	$dir . '/first.yaml', "---
includes:
  - $dir/deep.yaml
vars:
  SHARED: 'from-first-include'
  DUP: 'from-first-include'
  ONLY_INCLUDE: 'include-only'
vars_templated:
  TEMPLATED_SHARED: 'x[% ONLY_INCLUDE %]y'
"
);

write_file(
	$dir . '/second.yaml', "---
vars:
  DUP: 'from-second-include'
"
);

write_file(
	$dir . '/consumer.yaml', "---
includes:
  - $dir/first.yaml
  - $dir/second.yaml
vars:
  SHARED: 'from-file'
  TEMPLATED_SHARED: 'plain-shadow'
"
);

my $parser = Log::Munger::RuleFileParser->new;

my $rules;
eval { $rules = $parser->load( 'file' => $dir . '/consumer.yaml' ); };
ok( !$@, 'consumer file with includes loads' ) or diag($@);

is( $rules->{'vars'}{'SHARED'}, 'from-file', 'the file wins a var conflict with an include' );
is( $rules->{'vars'}{'DUP'}, 'from-first-include', 'an earlier include wins a var conflict with a later one' );
is( $rules->{'vars'}{'ONLY_INCLUDE'}, 'include-only', 'a var only an include defines is merged in' );
is( $rules->{'vars'}{'ONLY_DEEP'}, 'deep', 'an include of an include is loaded' );
is( $rules->{'vars'}{'TEMPLATED_SHARED'},
	'plain-shadow', 'a plain var shadows an include\'s templated var of the same name' );

#
# a reference to a name defined nowhere has to die at load, naming both ends
#
write_file(
	$dir . '/missing_reference.yaml', "---
vars:
  AAA: 'aaa'
vars_templated:
  COMPOSED: 'x(?<cap>[% MISSING %])y'
"
);
eval { $parser->load( 'file' => $dir . '/missing_reference.yaml' ); };
like(
	$@,
	qr/COMPOSED references "MISSING"/,
	'a templated var referencing an undefined name dies naming both'
);

#
# circular references are unschedulable and have to die rather than vanish
#
write_file(
	$dir . '/circular.yaml', "---
vars_templated:
  LOOP_A: 'a[% LOOP_B %]'
  LOOP_B: 'b[% LOOP_A %]'
"
);
eval { $parser->load( 'file' => $dir . '/circular.yaml' ); };
like( $@, qr/circular/, 'circular templated references die' );

done_testing();
