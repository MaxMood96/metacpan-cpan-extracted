use strict;
use warnings;
use Test::More;
use PDL;
use PDL::Opt::ParticleSwarm;
use Test::Number::Delta;

# Test velocity initialization characteristics
subtest 'Velocity Initialization' => sub {
    # Create a PSO instance with specific parameters
    my $pso = PDL::Opt::ParticleSwarm->new(
        -fitFunc => sub { pdl(0) },  # Dummy fitness function
        -dimensions => 2,
        -posMin => pdl([-100, -50]),
        -posMax => pdl([100, 50]),
        -randStartVelocity => 1,
        -numParticles => 1000
    );

    # Initialize particles to trigger velocity calculation
    $pso->init();

    # Extract velocity
    my $velocity = $pso->{prtcls}->{velocity};

    # Check velocity dimensions
    is($velocity->getdim(0), 2, 'Velocity has correct number of dimensions');
    is($velocity->getdim(1), 1000, 'Velocity has correct number of particles');

    # Test velocity range for randStartVelocity = 1
    my $searchSpaceSize = pdl([200, 100]);
    my $expectedVelocityRange = $searchSpaceSize / 100;

    for my $dim (0, 1) {
        my $dimVelocity = $velocity->slice("($dim),:");
        my $maxVel = abs($dimVelocity)->max;
        
        cmp_ok($maxVel, '<=', $expectedVelocityRange->slice("($dim)"), 
            "Velocity in dimension $dim does not exceed expected range");
    }
};

# Test different randStartVelocity scenarios
subtest 'Velocity Scaling' => sub {
    my @testCases = (
        { randStartVelocity => 1,   expectedIterations => 100 },
        { randStartVelocity => 10,  expectedIterations => 10 },
        { randStartVelocity => 0.1, expectedIterations => 1000 }
    );

    for my $testCase (@testCases) {
        my $pso = PDL::Opt::ParticleSwarm->new(
            -fitFunc => sub { pdl(0) },
            -dimensions => 1,
            -posMin => -100,
            -posMax => 100,
            -randStartVelocity => $testCase->{randStartVelocity},
            -numParticles => 1000
        );

        $pso->init();

        my $velocity = $pso->{prtcls}->{velocity};
        my $searchSpaceSize = 200;
        my $expectedVelocityRange = $searchSpaceSize / $testCase->{expectedIterations};

        my $maxVel = abs($velocity)->max;
        
        cmp_ok($maxVel, '<=', $expectedVelocityRange, 
            "Velocity scales correctly for randStartVelocity = $testCase->{randStartVelocity}");
    }
};

done_testing;
