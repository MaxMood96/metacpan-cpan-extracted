#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Exception;

use Algorithm::TimelinePacking;

subtest 'default values' => sub {
    my $t = Algorithm::TimelinePacking->new;
    is($t->space, 0, 'space defaults to 0');
    is($t->width, undef, 'width defaults to undef');
};

subtest 'space attribute' => sub {
    my $t = Algorithm::TimelinePacking->new(space => 10);
    is($t->space, 10, 'space can be set in constructor');

    $t->space(20);
    is($t->space, 20, 'space is read-write');

    lives_ok { Algorithm::TimelinePacking->new(space => 0) } 'space accepts 0';
    lives_ok { Algorithm::TimelinePacking->new(space => 100) } 'space accepts positive int';

    dies_ok { Algorithm::TimelinePacking->new(space => -1) } 'space rejects negative';
    dies_ok { Algorithm::TimelinePacking->new(space => 1.5) } 'space rejects float';
    dies_ok { Algorithm::TimelinePacking->new(space => 'abc') } 'space rejects string';
};

subtest 'width attribute' => sub {
    my $t = Algorithm::TimelinePacking->new(width => 800);
    is($t->width, 800, 'width can be set in constructor');

    $t->width(1024);
    is($t->width, 1024, 'width is read-write');

    $t->width(undef);
    is($t->width, undef, 'width accepts undef');

    lives_ok { Algorithm::TimelinePacking->new(width => 0) } 'width accepts 0';
    lives_ok { Algorithm::TimelinePacking->new(width => 100) } 'width accepts positive int';
    lives_ok { Algorithm::TimelinePacking->new(width => undef) } 'width accepts undef';

    dies_ok { Algorithm::TimelinePacking->new(width => -1) } 'width rejects negative';
    dies_ok { Algorithm::TimelinePacking->new(width => 1.5) } 'width rejects float';
    dies_ok { Algorithm::TimelinePacking->new(width => 'abc') } 'width rejects string';
};

done_testing;
