#!/usr/bin/env perl

use strict;
use warnings;

use Data::FSM;
use Data::FSM::State;
use Data::FSM::Transition;

my $state1 = Data::FSM::State->new(
        'name' => 'From',
);
my $state2 = Data::FSM::State->new(
        'name' => 'To',
);
my $fsm = Data::FSM->new(
        'id' => 7,
        'states' => [
                $state1,
                $state2,
        ],
        'transitions' => [
                Data::FSM::Transition->new(
                        'from' => $state1,
                        'to' => $state2,
                ),
        ],
);

# Print out.
print 'Id: '.$fsm->id."\n";
print "States:\n";
foreach my $state (@{$fsm->states}) {
        print '- '.$state->name."\n";
}
print "Transitions:\n";
foreach my $transition (@{$fsm->transitions}) {
        print '- '.$transition->from->name.' -> '.$transition->to->name."\n";
}

# Output:
# Id: 7
# States:
# - From
# - To
# Transitions:
# - From -> To