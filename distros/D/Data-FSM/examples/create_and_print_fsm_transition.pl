#!/usr/bin/env perl

use strict;
use warnings;

use Data::FSM::Transition;
use Data::FSM::State;

my $locked = Data::FSM::State->new(
        'name' => 'Locked',
);
my $unlocked = Data::FSM::State->new(
        'name' => 'Unlocked',
);
my $obj = Data::FSM::Transition->new(
        'callback' => sub {
                my $self = shift;
                print 'Id: '.$self->id."\n";
        },
        'from' => $locked,
        'id' => 7,
        'name' => 'Coin',
        'to' => $unlocked,
);

# Print out.
print 'Id: '.$obj->id."\n";
print 'From: '.$obj->from->name."\n";
print 'To: '.$obj->from->name."\n";
print 'Name: '.$obj->name."\n";

# Output:
# Id: 7
# From: Locked
# To: Locked
# Name: Coin