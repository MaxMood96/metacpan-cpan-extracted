#!/usr/bin/env perl

use v5.38;
use lib ('../lib', 'lib');
use Logic::Relational qw(variable call all);
use Logic::Relational::Program;

# 1. Initialize the Program
my $program = Logic::Relational::Program->new;

# 2. Define Suspicious Rules
# suspect(Person) :- located_at(Person, Place), carrying(Person, Item), crime_scene(Place)
my $person = variable('person');
my $place  = variable('place');
my $item   = variable('item');

$program->rule(
    head => call( suspect => $person ),
    body => all(
        call( located_at  => $person, $place ),
        call( carrying    => $person, $item ),
        call( crime_scene => $place )
    )
);

# Permanent Facts
$program->fact( crime_scene => 'castle' );
$program->fact( located_at  => 'goodguy', 'castle' );
$program->fact( carrying    => 'goodguy', 'shield' );

say "=== Permanent suspect query (before temporary facts) ===";
my $suspect_var = variable('Suspect');
my $q1          = $program->query( call( suspect => $suspect_var ) );
if ( my $sol = $q1->next ) {
    say "Suspect: " . $sol->value($suspect_var);
}
else {
    say "No suspect found.";
}

# 3. Scoped Temporary Facts using with_facts
say "\n=== Entering temporary facts scope (with_facts) ===";
$program->with_facts(
    [ [ located_at => 'badguy', 'castle' ], [ carrying => 'badguy', 'rope' ], ],
    sub {
        my $q = $program->query( call( suspect => $suspect_var ) );
        while ( my $sol = $q->next ) {
            say "   [Scope suspect] Found suspect: "
              . $sol->value($suspect_var);
        }
    }
);
say "=== Exited temporary facts scope ===";

# Verify suspect query outside the scope
say "\n=== suspect query (after temporary facts) ===";
my $q2 = $program->query( call( suspect => $suspect_var ) );
if ( my $sol = $q2->next ) {
    say "Suspect: " . $sol->value($suspect_var);
}
else {
    say "No suspect found.";
}

# 4. Expiring Facts with assert_fact
say "\n=== Expiring Facts (assert_fact) ===";

# Set up an observer to watch retractions when facts expire
$program->on_change(
    sub ($event) {
        if ( $event->operation eq 'retract' ) {
            say "   [Observer Notification] Expired fact pruned: "
              . $event->clause->head->as_string;
        }
    }
);

say "Asserting that badguy was seen_at the station, expiring in 2 seconds...";
$program->assert_fact(
    term       => [ seen_at => 'badguy', 'station' ],
    expires_in => 2,
);

# Query immediately
my $loc_var = variable('Loc');
my $q3      = $program->query( call( seen_at => 'badguy', $loc_var ) );
if ( my $sol = $q3->next ) {
    say "Current Observation: badguy was seen_at " . $sol->value($loc_var);
}
else {
    say "Observation not found or expired.";
}

# Wait for expiration
say "Sleeping for 3 seconds...";
sleep 3;

# Query again
my $q4 = $program->query( call( seen_at => 'badguy', $loc_var ) );
if ( my $sol = $q4->next ) {
    say "Current Observation: badguy was seen_at " . $sol->value($loc_var);
}
else {
    say "Observation not found or expired (expected).";
}

say "\n=== Done ===";
1;

