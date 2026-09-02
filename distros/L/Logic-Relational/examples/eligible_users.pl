#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

logic System {
    fact user('alice', 28, 'admin');
    fact user('bob',   15, 'editor');
    fact user('charlie', 34, 'suspended');

    rule eligible_user($name) {
    	# declare logical variables
        fresh my $age;
        fresh my $role;

		# bind those variables
        user($name, $age, $role);

        # Disjunction: Role must be admin OR editor
        either {
            unify($role, 'admin');
        }
        or {
            unify($role, 'editor');
        }

        # Ensure user role is NOT suspended
        $role !:= 'suspended';

        # Procedural guard checking age >= 18
        guard([$age], sub ($a) { $a >= 18 });
    }
}

say "=== Eligible Users ===";
query System::eligible_user(fresh my $user) -> my $q;
while (my $sol = $q->next) {
    say "Eligible: " . $sol->value($user);
}


