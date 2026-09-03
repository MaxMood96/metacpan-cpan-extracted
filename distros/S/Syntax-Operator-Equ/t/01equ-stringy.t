#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use Syntax::Operator::Equ;
BEGIN { plan skip_all => "No PL_infix_plugin" unless XS::Parse::Infix::HAVE_PL_INFIX_PLUGIN; }

my $warnings = 0;
$SIG{__WARN__} = sub { $warnings++ };

ok(  "abc" equ "abc", 'identical strings');
ok(!("abc" equ "def"), 'different strings');
ok(  undef equ undef, 'undef is undef');
ok(!("abc" equ undef), 'undef is not a string');
ok(!(""    equ undef), 'undef is not empty string');

# overloaded 'eq' operator
{
   my $equal;
   package Greedy {
      use overload 'eq' => sub { $equal };
   }

   my $greedy = bless [], "Greedy";

   $equal = 1;
   ok(  $greedy equ "abc",  'Greedy is abc when set' );

   $equal = 0;
   ok(!($greedy equ "abc"), 'Greedy is not abc when unset' );
}

# unimport
SKIP: {
   no Syntax::Operator::Equ;

   sub equ { return "normal function" }

   # `equ` is a native infix operator in Perl 5.45.3 onwards
   skip "equ is a real operator on this perl", 1 if $^V ge v5.45.3;

   # We have to string-eval the 'equ' call because otherwise it won't even
   # compile >= 5.45.3
   is( eval 'equ', "normal function", 'equ() parses as a normal function call' );
}

ok(!$warnings, 'no warnings');

done_testing;
