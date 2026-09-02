use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# Declare a logic database
logic Family {
	# Single fact assertion
	fact parent('Alice', 'Bob');

	# Grouped facts block assertion
	facts {
	    parent('Alice', 'Charlie');
	    parent('Bob', 'Diana');
	    parent('Bob', 'Edward');
	    parent('Edward', 'Fran');
	    parent('Fran', 'George');
	    parent('Heather', 'Edward');
	}

    # Rule: $g is grandparent of $c IF $g is parent of $p AND $p is parent of $c
    rule grandparent($g, $c) {
        fresh my $p;
        parent($g, $p);
        parent($p, $c);
    }
    
    # "Ancestor" rule
    # Base case: A parent is an ancestor
    rule ancestor($c, $d) {
        parent($c, $d);
    }

    # Recursive case: $c is ancestor of $d if $c is parent of $p AND $p is ancestor of $d
    rule ancestor($c, $d) {
        fresh my $p;
        parent($c, $p);
        ancestor($p, $d);
    }
}

# Query: "Who are the children of Alice?"
query Family::parent('Alice', fresh my $child) -> my $q1;

while (my $sol = $q1->next) {
	say "Alice is parent of: " . $sol->value($child);
}

# Query: "Who are the grandchildren of Alice?"
query Family::grandparent('Alice', fresh my $grandchild) -> my $q2;

while ( my $sol = $q2->next ) {
	say "Alice is grandparent of: " . $sol->value($grandchild);
}

# Query: "Who are the parents of Edward?"
query Family::parent(fresh my $parent, 'Edward') -> my $q3;

while (my $sol = $q3->next) {
	say "A parent of Edward is: " . $sol->value($parent);
}

# Query: "Who are the ancestors of George?"
query Family::ancestor(fresh my $ancestor, 'George') -> my $q4;

while (my $sol = $q4->next) {
	say "An ancestor of George is: " . $sol->value($ancestor);
}

