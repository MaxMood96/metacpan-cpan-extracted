#!/usr/bin/env perl

use strict;
use warnings;

use Data::FSM::State;

my $obj = Data::FSM::State->new(
        'id' => 7,
        'initial' => 0,
        'name' => 'From',
);

# Print out.
print 'Id: '.$obj->id."\n";
print 'Initial: '.$obj->initial."\n";
print 'Name: '.$obj->name."\n";

# Output:
# Id: 7
# Initial: 0
# Name: From