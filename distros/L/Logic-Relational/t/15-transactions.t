use v5.38;
use lib ('../lib', 'lib');
use Test2::V0;
use Logic::Relational::Program;
BEGIN { no strict 'refs'; delete $main::{call}; }
use Logic::Relational qw(variable call);
use feature 'try';
no warnings 'experimental::try';

my $program = Logic::Relational::Program->new;
$program->fact( colour => 'red' );

# 1. Success case: transaction commits
$program->transaction(
    sub {
        $program->fact( colour => 'green' );
        $program->fact( colour => 'blue' );
    }
);

my $x  = variable('X');
my $q1 = $program->query( call( colour => $x ) );
my @c1;
while ( my $sol = $q1->next ) {
    push @c1, $sol->value($x);
}
is( \@c1, [ 'red', 'green', 'blue' ], 'Transaction successfully committed' );

# 2. Failure case: transaction rolls back
try {
    $program->transaction(
        sub {
            $program->fact( colour => 'yellow' );
            die "Abort transaction!\n";
        }
    );
}
catch ($e) {
    like(
        $e,
        qr/Abort transaction/,
        'Transaction failed and exception propagated'
    );
}

my $q2 = $program->query( call( colour => $x ) );
my @c2;
while ( my $sol = $q2->next ) {
    push @c2, $sol->value($x);
}
is(
    \@c2,
    [ 'red', 'green', 'blue' ],
    'Changes inside failed transaction were rolled back'
);

done_testing;
