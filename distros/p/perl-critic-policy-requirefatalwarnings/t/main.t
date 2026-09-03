use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::RequireFatalWarnings;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for warnings.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'RequireFatalWarnings', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \$source );
}

my %prohibited = (
    'plain use warnings' => qq{use strict;\nuse warnings;\n1;\n},
    'warnings all'       => qq{use strict;\nuse warnings 'all';\n1;\n},
    'a category list'    => qq{use strict;\nuse warnings qw{uninitialized};\n1;\n},
    'no warnings at all' => qq{use strict;\n1;\n},
    'FATAL but not all'  => qq{use strict;\nuse warnings FATAL => 'uninitialized';\n1;\n},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'fat comma'   => qq{use strict;\nuse warnings FATAL => 'all';\n1;\n},
    'qw spelling' => qq{use strict;\nuse warnings qw{FATAL all};\n1;\n},
    'after other' => qq{use strict;\nuse warnings;\nuse warnings FATAL => 'all';\n1;\n},
    'Test2::V0'   => qq{use Test2::V0;\n1;\n},
    'strictures'  => qq{use strictures 2;\n1;\n},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

# One complaint per document, not one per statement.
is( violations(qq{use strict;\nuse warnings;\nuse warnings;\n1;\n}), 1, 'reported once per file' );

is( violations(qq{use strict;\nuse warnings;  ## no critic (RequireFatalWarnings)\n1;\n}),
    0, 'an explicit no-critic is what signs it off' );

# The list of modules that do it for you is configurable.
{
    my $configured = Perl::Critic->new(
        -profile         => \"[RequireFatalWarnings]\nequivalent_modules = My::Bootstrap\n",
        '-single-policy' => 'RequireFatalWarnings',
        -severity        => 1,
    );

    is( scalar $configured->critique( \qq{use My::Bootstrap;\n1;\n} ),
        0, 'a configured module counts as having done it' );
    is( scalar $configured->critique( \qq{use Moose;\n1;\n} ),
        1, 'and one left out of the list does not' );
}

done_testing();
