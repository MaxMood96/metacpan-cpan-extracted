# Test case for HDF5 extensible datasets
use strict;
use warnings;
use PDL;
use PDL::IO::HDF5;
use Test::More;
use File::Spec::Functions;

my $filename = "xData.hdf5";
unlink $filename if -e $filename; # get rid of file if it already exists

my $hdf5 = new PDL::IO::HDF5($filename);

my $group=$hdf5->group('group1');

# Store an extensible dataset
my $dataset=$group->dataset('xdata');
my $data1 = pdl [ 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0 ];
$dataset->set($data1, unlimited => 1);

# read the dataset
my $xdata = $group->dataset("xdata")->get();
my $expected = '[2 3 4 5 6 7 8 9 10 11 12]';
is( "$xdata", $expected);

# write more data
my $data2 = pdl [ 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0 ];
$dataset->set($data2, unlimited => 1);

# read the dataset
$xdata = $group->dataset("xdata")->get();
$expected = '[2 3 4 5 6 7 8 9 10 11 12 13 14]';
is( "$xdata", $expected);
unlink $filename if -e $filename; # clean up file

$hdf5 = PDL::IO::HDF5->new(catfile(qw(t sbyte.hdf5)));
$dataset = $hdf5->dataset('data2');
my $got = $dataset->get;
$expected = pdl(-127, 127); # deliberately type double
ok +(($got - $expected)->sum) < .001 or diag "got=$got\nexpected=$expected";
unlink $filename if -e $filename; # clean up file

$hdf5 = PDL::IO::HDF5->new($filename);
$dataset = $hdf5->dataset('data');
$dataset->set(pdl(42), unlimited => 1);
$got = $dataset->get;
ok +(($got - 42)->sum) < .001 or diag "got=$got\nexpected=$expected";
unlink $filename if -e $filename; # clean up file

done_testing;
