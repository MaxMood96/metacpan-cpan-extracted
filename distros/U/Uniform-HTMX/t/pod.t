use strict;
use warnings;
use Test::More;

# Dynamically handle systems that do not have optional POD verification tools installed
unless ( eval "use Test::Pod 1.44; 1" ) {
    plan skip_all => "Test::Pod 1.44 required for checking documentation format";
}

all_pod_files_ok();
