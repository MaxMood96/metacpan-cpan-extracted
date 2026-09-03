use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::RequireQwForLiteralLists;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for quoting.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'RequireQwForLiteralLists', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'a plain list'      => q{my @cmd = ( 'sudo', 'rm', '-f' );},
    'call arguments'    => q{system( 'git', 'rev-parse', 'HEAD' );},
    'a trailing scalar' => q{$hv->system_hv( 'sudo', 'rm', '-f', $conf );},
    'a leading scalar'  => q{run( $bin, '--one', '--two', '--three' );},
    'no parens at all'  => q{push @args, '--a', '--b', '--c';},
    'q{} quoted'        => q{my @x = ( q{a}, q{b}, q{c} );},
    'double quoted'     => q{my @x = ( "a", "b", "c" );},
    'more than three'   => q{my @x = ( 'a', 'b', 'c', 'd', 'e' );},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'already qw'          => q{my @cmd = qw{sudo rm -f};},
    'under the threshold' => q{my @two = ( 'a', 'b' );},
    'fat commas'          => q{my %h = ( a => 'b', c => 'd' );},
    'whitespace inside'   => q{my @x = ( 'a b', 'c d', 'e f' );},
    'interpolation'       => q{my @x = ( "$dir", "$file", "$other" );},
    'an embedded quote'   => q{my @x = ( 'it\\'s', 'a', 'b' );},
    'a backslash'         => q{my @x = ( 'a\\\\b', 'c', 'd' );},
    'an empty string'     => q{my @x = ( '', 'b', 'c' );},
    'scalars throughout'  => q{my @x = ( $a, $b, $c );},
    'broken up by one'    => q{my @x = ( 'a', $b, 'c', $d, 'e' );},
    'a hash slice'        => q{my @v = @h{ 'a', 'b' };},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

# One complaint per run, anchored on the literal that starts it.
is( violations(q{my @x = ( 'a', 'b', 'c', 'd', 'e', 'f' );}), 1, 'a long run is one violation, not six' );
is( violations(q{f( 'a', 'b', 'c' ); g( 'd', 'e', 'f' );}),   2, 'two runs are two violations' );

is( violations(q{my @x = ( 'a', 'b', 'c' );  ## no critic (RequireQwForLiteralLists)}), 0, "an explicit no-critic is what signs it off" );

# The threshold is configurable, for a shop that wants it tighter or looser.
{
    my $strict = Perl::Critic->new(
        -profile         => \"[RequireQwForLiteralLists]\nmin_run_length = 2\n",
        '-single-policy' => 'RequireQwForLiteralLists',
        -severity        => 1,
    );

    is( scalar $strict->critique( \"use strict;\nmy \@x = ( 'a', 'b' );\n" ),
        1, 'a pair is a violation once the threshold says so' );
}

{
    my $loose = Perl::Critic->new(
        -profile         => \"[RequireQwForLiteralLists]\nmin_run_length = 4\n",
        '-single-policy' => 'RequireQwForLiteralLists',
        -severity        => 1,
    );

    is( scalar $loose->critique( \"use strict;\nmy \@x = ( 'a', 'b', 'c' );\n" ),
        0, 'and three is not once it says that' );
}

done_testing();
