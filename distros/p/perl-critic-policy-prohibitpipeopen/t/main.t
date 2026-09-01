use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::ProhibitPipeOpen;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for piping.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'ProhibitPipeOpen', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'three-arg read'    => q{open( my $fh, '-|', 'ls', '-l' );},
    'three-arg write'   => q{open( my $fh, '|-', 'mail', $to );},
    'bare two-arg fork' => q{open( my $fh, '-|' );},
    'two-arg trailing'  => q{open( FH, 'ls -l |' );},
    'two-arg leading'   => q{open( FH, '| mail bob' );},
    'q{} quoted mode'   => q{open( my $fh, q{-|}, 'ls' );},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'read'                 => q{open( my $fh, '<', $path );},
    'write'                => q{open( my $fh, '>', $path );},
    'append'               => q{open( my $fh, '>>', $path );},
    'interpolated path'    => q{open( my $fh, '>', "$dir/thing" );},
    'in-memory'            => q{open( my $fh, '<', \$scalar );},
    'opendir'              => q{opendir( my $dh, $dir );},
    'bitwise or'           => q{my $x = $a | $b;},
    'a method named open'  => q{$obj->open( '-|', 'ls' );},
    'a mode in a variable' => q{open( my $fh, $mode, $cmd );},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

is( violations(q{open( my $fh, '-|', 'ls' );  ## no critic (ProhibitPipeOpen)}), 0, "an explicit no-critic is what signs it off" );

done_testing();
