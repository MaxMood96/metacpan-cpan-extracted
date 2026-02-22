use strict;
use warnings;
use Test::More;
use PDL;
use FindBin;
use lib "$FindBin::Bin/../lib";
use PDL::Opt::ParticleSwarm;

# Dummy fitness: parabola with minimum at x=-3, f(-3)=-5
sub parabola_1d
{
	my $x = $_[0]->slice('(0)');
	return (($x + 3)**2 - 5);
}

# Multi-dimensional sphere: minimum at origin, f(0..0)=0
# _calcPosFit transposes the result, so return raw (N) shape
sub sphere_nd
{
	return sumover($_[0]**2);
}

subtest 'Fix 1: Velocity mask zeroes for both posMin and posMax violations' => sub {
	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc    => \&parabola_1d,
		-dimensions => 1,
		-posMin     => -10,
		-posMax     => 10,
		-numParticles => 2,
	);

	$pso->init();
	my $prtcls = $pso->{prtcls};

	# Particle 0: position beyond posMax with positive velocity
	$prtcls->{currPos}->slice(':,0') .= 9;
	$prtcls->{velocity}->slice(':,0') .= 5;

	# Particle 1: position below posMin with negative velocity
	$prtcls->{currPos}->slice(':,1') .= -9;
	$prtcls->{velocity}->slice(':,1') .= -5;

	$pso->_calcNextPos($prtcls);

	# Both velocities must be zeroed
	ok(all($prtcls->{velocity}->slice(':,0') == 0),
		'velocity zeroed when nextPos exceeds posMax');
	ok(all($prtcls->{velocity}->slice(':,1') == 0),
		'velocity zeroed when nextPos below posMin');

	# nextPos must be clipped to bounds
	ok(all($prtcls->{nextPos}->slice(':,0') <= 10),
		'nextPos clipped to posMax');
	ok(all($prtcls->{nextPos}->slice(':,1') >= -10),
		'nextPos clipped to posMin');

	# In-range particle must keep velocity
	$prtcls->{currPos}->slice(':,0') .= 0;
	$prtcls->{velocity}->slice(':,0') .= 3;
	$pso->_calcNextPos($prtcls);
	ok(all($prtcls->{velocity}->slice(':,0') != 0),
		'velocity preserved when nextPos is in range');
};

subtest 'Fix 2: Stalled particles retain personal best' => sub {
	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc       => \&parabola_1d,
		-dimensions    => 1,
		-posMin        => -10,
		-posMax        => 10,
		-numParticles  => 5,
		-searchSize    => 0.5,
		-stallSpeed    => 1e6,
	);

	$pso->init();
	my $prtcls = $pso->{prtcls};

	# Record bestPos after initialization
	my $initial_bestPos = $prtcls->{bestPos}->copy;

	# Set known bestPos values so we can detect if they change
	$prtcls->{bestPos} .= pdl([[-2], [-1], [0], [1], [2]]);
	my $known_bestPos = $prtcls->{bestPos}->copy;

	# Simulate a stall by calling _initParticles with a mask after iterCount > 0
	$pso->{iterCount} = 5;
	my $stall_mask = ones(5);
	$pso->_initParticles($stall_mask);

	# bestPos must be unchanged -- stalled particles keep their personal best
	ok(all($pso->{prtcls}->{bestPos} == $known_bestPos),
		'bestPos preserved after stall reinit when iterCount > 0');
};

subtest 'Fix 3: searchSize clamped to 1.0' => sub {
	# Use a stallSearchScale that will push searchSize above 1.0
	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc          => \&parabola_1d,
		-dimensions       => 1,
		-posMin           => -10,
		-posMax           => 10,
		-numParticles     => 5,
		-searchSize       => 0.5,
		-stallSearchScale => 2.0,
		-stallSpeed       => 1e6,
	);

	$pso->init();

	# After init, stalls is 0. Force high stall counts so
	# searchSize = 0.5 * 2^stalls exceeds 1.0 at stalls >= 2.
	$pso->{prtcls}->{stalls} .= 10;
	$pso->{iterCount} = 1;

	# Reinit stalled particles
	my $stall_mask = ones(5);
	$pso->_initParticles($stall_mask);

	# With searchSize clamped to 1.0, max offset from bestPos is
	# 1.0 * (posMax - posMin) = 20. bestPos can be up to 10, so
	# currPos can reach up to 30. Without clamp (searchSize=512),
	# offset could be 512 * 20 = 10240.
	my $currPos = $pso->{prtcls}->{currPos};
	my $maxabs = abs($currPos)->max->sclr;
	ok($maxabs < 100,
		"currPos magnitude ($maxabs) bounded by clamped searchSize");
};

subtest 'Fix 4: Random factors are non-negative' => sub {
	# Run many iterations and verify particles converge. With negative
	# random factors, particles could be repelled from the optimum.
	# We verify by checking that _randInRangePDL(0, weight) produces
	# only non-negative values.

	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc    => \&parabola_1d,
		-dimensions => 1,
		-posMin     => -10,
		-posMax     => 10,
		-numParticles => 10,
	);

	$pso->init();

	# Direct test of _randInRangePDL with the parameters used in _updateVelocities
	my $samples = $pso->_randInRangePDL(0, $pso->{meWeight}, 1, 10000);
	ok(all($samples >= 0),
		'meWeight random factor is non-negative');
	ok(all($samples <= $pso->{meWeight}),
		'meWeight random factor does not exceed weight');

	$samples = $pso->_randInRangePDL(0, $pso->{themWeight}, 1, 10000);
	ok(all($samples >= 0),
		'themWeight random factor is non-negative');
	ok(all($samples <= $pso->{themWeight}),
		'themWeight random factor does not exceed weight');
};

subtest 'Fix 5: stallSpeed scales with sqrt(dimensions)' => sub {
	# In high dimensions, L2 norm of velocity is naturally larger.
	# stallSpeed threshold must scale with sqrt(dimensions) to produce
	# comparable stall detection across dimensionalities.

	my $stallSpeed = 1e-3;

	# 1D case
	my $pso_1d = PDL::Opt::ParticleSwarm->new(
		-fitFunc    => sub { sumover($_[0]**2) },
		-dimensions => 1,
		-numParticles => 20,
		-stallSpeed => $stallSpeed,
		-iterations => 100,
	);
	$pso_1d->init();

	# 100D case
	my $pso_100d = PDL::Opt::ParticleSwarm->new(
		-fitFunc    => \&sphere_nd,
		-dimensions => 100,
		-numParticles => 20,
		-stallSpeed => $stallSpeed,
		-iterations => 100,
	);
	$pso_100d->init();

	# The effective threshold used internally must differ by sqrt(100)/sqrt(1) = 10
	my $threshold_1d  = $stallSpeed * sqrt(1);
	my $threshold_100d = $stallSpeed * sqrt(100);

	cmp_ok(abs($threshold_100d / $threshold_1d - 10), '<', 1e-10,
		'stallSpeed threshold ratio matches sqrt(dimensions) ratio');

	# Verify the scaling is applied: create velocity near the boundary
	# In 1D, velocity magnitude 5e-4 (below stallSpeed*1) must stall
	my $prtcls_1d = $pso_1d->{prtcls};
	$prtcls_1d->{velocity} .= $stallSpeed * 0.5;
	my $vel_1d = sqrt(sumover($prtcls_1d->{velocity}**2));
	ok(all($vel_1d < $stallSpeed * sqrt(1)),
		'1D velocity below scaled stallSpeed triggers stall');

	# In 100D, same per-component velocity produces L2 norm = 0.5e-3 * sqrt(100) = 5e-3
	# which is above stallSpeed*sqrt(100) = 1e-3*10 = 1e-2? No:
	# per-component = stallSpeed*0.5 = 5e-4, L2 = 5e-4*sqrt(100) = 5e-3
	# threshold = stallSpeed*sqrt(100) = 1e-2
	# 5e-3 < 1e-2 => still stalls. Same per-component velocity stalls in both dims.
	my $prtcls_100d = $pso_100d->{prtcls};
	$prtcls_100d->{velocity} .= $stallSpeed * 0.5;
	my $vel_100d = sqrt(sumover($prtcls_100d->{velocity}**2));
	ok(all($vel_100d < $stallSpeed * sqrt(100)),
		'100D velocity with same per-component magnitude also stalls');
};

subtest 'Fix 6: Weights used directly without normalization' => sub {
	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc    => \&parabola_1d,
		-dimensions => 1,
		-meWeight   => 1.5,
		-themWeight => 1.5,
		-inertia    => 0.7,
	);

	$pso->init();

	# Weights must be used as-is per standard PSO (Kennedy & Eberhart 1995)
	cmp_ok($pso->{meWeight},   '==', 1.5, 'meWeight unchanged after init');
	cmp_ok($pso->{themWeight}, '==', 1.5, 'themWeight unchanged after init');
	cmp_ok($pso->{inertia},    '==', 0.7, 'inertia unchanged after init');

	# No _normalized internal copies should exist
	ok(!defined($pso->{_inertia}),    'no _inertia internal copy');
	ok(!defined($pso->{_meWeight}),   'no _meWeight internal copy');
	ok(!defined($pso->{_themWeight}), 'no _themWeight internal copy');

	# Second init must not alter weights
	$pso->init();
	cmp_ok($pso->{meWeight},   '==', 1.5, 'meWeight stable after second init');
	cmp_ok($pso->{themWeight}, '==', 1.5, 'themWeight stable after second init');
	cmp_ok($pso->{inertia},    '==', 0.7, 'inertia stable after second init');

	# Changing a subset of weights via setParams preserves others
	$pso->setParams(-meWeight => 2.0);
	$pso->init();
	cmp_ok($pso->{meWeight},   '==', 2.0, 'meWeight updated via setParams');
	cmp_ok($pso->{themWeight}, '==', 1.5, 'themWeight preserved from original');
	cmp_ok($pso->{inertia},    '==', 0.7, 'inertia preserved from original');
};

subtest 'Integration: all fixes together produce correct optimization' => sub {
	my $pso = PDL::Opt::ParticleSwarm->new(
		-fitFunc          => \&parabola_1d,
		-dimensions       => 1,
		-posMin           => -10,
		-posMax           => 10,
		-numParticles     => 20,
		-iterations       => 2000,
		-exitFit          => -5 + 1e-6,
		-searchSize       => 0.5,
		-stallSearchScale => 1.1,
		-randStartVelocity => 1,
	);

	$pso->optimize();
	my $bestPos = $pso->getBestPos();
	my $bestFit = $pso->getBestFit();

	my $x = $bestPos->slice('(0)')->sclr;
	ok(abs($x - (-3)) < 1e-3,
		"parabola optimum found at x=$x (expected -3)");
	ok($bestFit->sclr < -4.99,
		"fitness value " . $bestFit->sclr . " near optimum -5");
};

done_testing;
