use strict;
use warnings;
use Test::More;

eval { require Test::Pod; 1 } or plan skip_all => "Test::Pod not installed";
Test::Pod::all_pod_files_ok();

done_testing;
