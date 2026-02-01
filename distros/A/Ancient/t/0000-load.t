#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

my @modules = qw(
    slot
    util
    noop
    const
    doubly
    object
    lru
    heap
    file
    nvec
);

plan tests => scalar(@modules);

for my $mod (@modules) {
    use_ok($mod) || print "Bail out! Cannot load $mod\n";
}

diag( "Testing slot $slot::VERSION, Perl $], $^X" );
