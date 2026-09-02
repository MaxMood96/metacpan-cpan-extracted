use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

logic ListRules {
	# Base case: $x is the head of the list
	rule list_member($x, [$x, rest($tail)]) {
	    true_goal;
	}

	# Recursive case: $x is in the tail of the list
	rule list_member($x, [$y, rest($tail)]) {
	    list_member($x, $tail);
	}
}

query ListRules::list_member('C', ['A', 'B', 'C', 'D', 'E']) -> my $q;
if ( $q->next ) {
	say "'C' is a member of list ['A', 'B', 'C', 'D', 'E']";
}
else {
	say "'C' is not a member of list ['A', 'B', 'C', 'D', 'E']";
}

