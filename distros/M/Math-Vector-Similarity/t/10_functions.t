use Test2::V0;
use Math::Vector::Similarity qw( :all );

# --- dot_product ---

is dot_product([1,0,0], [1,0,0]), 1, 'dot product: identical unit vectors';
is dot_product([1,0,0], [0,1,0]), 0, 'dot product: orthogonal';
is dot_product([2,3], [4,5]), 23, 'dot product: 2d';
is dot_product([1,2,3], [4,5,6]), 32, 'dot product: 3d';

# --- normalize ---

my $unit = normalize([3, 4]);
ok abs($unit->[0] - 0.6) < 1e-9, 'normalize: x component';
ok abs($unit->[1] - 0.8) < 1e-9, 'normalize: y component';

my $unit3 = normalize([1, 1, 1]);
my $expected = 1 / sqrt(3);
ok abs($unit3->[0] - $expected) < 1e-9, 'normalize: 3d uniform';

my $zero = normalize([0, 0, 0]);
is $zero, [0, 0, 0], 'normalize: zero vector unchanged';

# Verify unit length
my $mag = 0;
$mag += $_ * $_ for @$unit;
ok abs($mag - 1.0) < 1e-9, 'normalize: result has unit length';

# --- cosine_similarity ---

my $sim_same = cosine_similarity([1,0,0], [1,0,0]);
ok abs($sim_same - 1.0) < 1e-9, 'cosine sim: identical = 1';

my $sim_orth = cosine_similarity([1,0,0], [0,1,0]);
ok abs($sim_orth) < 1e-9, 'cosine sim: orthogonal = 0';

my $sim_opp = cosine_similarity([1,0], [-1,0]);
ok abs($sim_opp - (-1.0)) < 1e-9, 'cosine sim: opposite = -1';

my $sim_close = cosine_similarity([0.9, 0.1, 0.0], [1.0, 0.0, 0.0]);
ok $sim_close > 0.99, 'cosine sim: close vectors > 0.99';

# Scaled vectors have same similarity
my $sim_scaled = cosine_similarity([2, 4, 6], [1, 2, 3]);
ok abs($sim_scaled - 1.0) < 1e-9, 'cosine sim: scale invariant';

# Zero vector
is cosine_similarity([0,0,0], [1,2,3]), 0, 'cosine sim: zero vector = 0';

# --- cosine_distance ---

my $dist_same = cosine_distance([1,0,0], [1,0,0]);
ok abs($dist_same) < 1e-9, 'cosine dist: identical = 0';

my $dist_orth = cosine_distance([1,0,0], [0,1,0]);
ok abs($dist_orth - 1.0) < 1e-9, 'cosine dist: orthogonal = 1';

my $dist_opp = cosine_distance([1,0], [-1,0]);
ok abs($dist_opp - 2.0) < 1e-9, 'cosine dist: opposite = 2';

# --- euclidean_distance ---

my $ed = euclidean_distance([0,0], [3,4]);
ok abs($ed - 5.0) < 1e-9, 'euclidean: 3-4-5 triangle';

my $ed_same = euclidean_distance([1,2,3], [1,2,3]);
ok abs($ed_same) < 1e-9, 'euclidean: identical = 0';

my $ed_1d = euclidean_distance([0], [7]);
ok abs($ed_1d - 7.0) < 1e-9, 'euclidean: 1d';

# --- dimension mismatch ---

like dies { dot_product([1,2], [1,2,3]) },
  qr/same dimensions/, 'dot_product: dimension mismatch croaks';

like dies { cosine_similarity([1,2], [1]) },
  qr/same dimensions/, 'cosine_similarity: dimension mismatch croaks';

like dies { euclidean_distance([1], [1,2]) },
  qr/same dimensions/, 'euclidean_distance: dimension mismatch croaks';

# --- high dimensions (embedding-like) ---

my @big_a = map { sin($_) } 1..768;
my @big_b = map { cos($_) } 1..768;
my $sim_big = cosine_similarity(\@big_a, \@big_b);
ok defined $sim_big, 'cosine sim: works on 768-dim vectors';
ok $sim_big >= -1 && $sim_big <= 1, 'cosine sim: 768-dim in valid range';

done_testing;
