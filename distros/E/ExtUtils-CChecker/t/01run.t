#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use ExtUtils::CChecker;

my $cc = ExtUtils::CChecker->new;

ok( defined $cc, 'defined $cc' );
isa_ok( $cc, [ "ExtUtils::CChecker" ], '$cc' );

ok( $cc->try_compile_run( "int main(void) { return 0; }\n" ), 'Trivial C program compiles and runs' );
ok( !$cc->try_compile_run( "int foo bar splot\n" ), 'Broken C program does not compile and run' );

ok( $cc->try_compile_run( source => "int main(void) { return 0; }\n" ), 'source named argument' );

$cc->try_compile_run(
   source => "int main(void) { return 0; }\n",
   define => "HAVE_C",
);

is( $cc->extra_compiler_flags, [ "-DHAVE_C" ], 'HAVE_C defined' );

done_testing;
