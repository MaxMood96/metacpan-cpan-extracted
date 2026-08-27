use strict;
use warnings;
use Test::More;

plan skip_all => 'author test: set AUTHOR_TESTING=1' unless $ENV{AUTHOR_TESTING};

eval { require Test::Pod; Test::Pod->VERSION('1.22'); 1 }
    or plan skip_all => 'Test::Pod 1.22 required';

Test::Pod::all_pod_files_ok(Test::Pod::all_pod_files('lib'));
