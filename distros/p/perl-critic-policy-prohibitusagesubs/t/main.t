use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::ProhibitUsageSubs;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for usage subs.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'ProhibitUsageSubs', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'usage'             => q{sub usage { return "Usage: $0 DOMAIN\n" }},
    '_usage'            => q{sub _usage { return "Usage: $0 DOMAIN\n" }},
    'print_usage'       => q{sub print_usage { print "Usage: $0\n" }},
    'usage_message'     => q{sub usage_message { return 'usage' }},
    'fully qualified'   => q{sub Trog::Bin::Thing::usage { return 'usage' }},
    'declared with sig' => q{use feature 'signatures'; sub usage ($code) { return 'usage' }},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'calling pod2usage'    => q{pod2usage( -exitval => 2, -verbose => 1 );},
    'importing one'        => q{use Pod::Usage qw{pod2usage};},
    'a forward decl'       => q{sub usage;},
    'an unrelated sub'     => q{sub main { return 0 }},
    'usage in a name'      => q{sub usage_of_the_disk { return 42 }},
    'a method call'        => q{$self->usage();},
    'a hash key'           => q{my %h = ( usage => 'nope' );},
    'an anonymous sub'     => q{my $usage = sub { return 'nope' };},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

is( violations(q{sub usage { return 'x' }  ## no critic (ProhibitUsageSubs)}), 0, "an explicit no-critic is what signs it off" );

# The name list is configurable, for a codebase that spells it differently.
{
    my $configured = Perl::Critic->new(
        -profile         => \"[ProhibitUsageSubs]\nsub_names = help\n",
        '-single-policy' => 'ProhibitUsageSubs',
        -severity        => 1,
    );

    is( scalar $configured->critique( \"use strict;\nsub help { return 'x' }\n" ),
        1, 'a configured name is a violation' );
    is( scalar $configured->critique( \"use strict;\nsub usage { return 'x' }\n" ),
        0, 'and one left out of the list is not' );
}

done_testing();
