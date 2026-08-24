#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Log::Munger::RuleFileParser' ) || print "Bail out!\n";
}

diag( "Testing Log::Munger::RuleFileParser $Log::Munger::RuleFileParser::VERSION, Perl $], $^X" );
