use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Physics::CPD::Stellarator;

# Plotting needs PDL + PDL::Graphics::Gnuplot + a gnuplot binary. Skip cleanly
# if any part of that toolchain is unavailable on the test machine.
my $have_plot = eval {
    require PDL;
    require PDL::Graphics::Gnuplot;
    1;
};
plan skip_all => 'PDL / PDL::Graphics::Gnuplot not available' unless $have_plot;

my $dir = tempdir( CLEANUP => 1 );
my $w   = Physics::CPD::Stellarator->new(
    electron_density     => 8e19,
    electron_temperature => 4000,
    ion_temperature      => 2000,
    magnetic_field       => 2.5,
    heating_power        => 10,
);

my @cases = (
    [ 'plot_3d',               'w7x_3d.png' ],
    [ 'plot_cross_sections',   'w7x_cross.png' ],
    [ 'plot_profiles',         'w7x_profiles.png' ],
    [ 'plot_confinement_scan', 'w7x_conf.png' ],
);

for my $c (@cases) {
    my ( $method, $file ) = @$c;
    my $path = File::Spec->catfile( $dir, $file );
    my $ret  = eval { $w->$method( output => $path ); 1 };
    ok( $ret, "$method ran without error" ) or diag($@);
  SKIP: {
        skip "$method did not run", 2 unless $ret;
        ok( -e $path,        "$method produced $file" );
        ok( -s $path > 1000, "$file is a non-trivial image" );
    }
}

done_testing;
