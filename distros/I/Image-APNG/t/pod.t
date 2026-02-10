#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

plan skip_all => 'Test::Pod required for testing POD' unless eval { require Test::Pod; 1 } ;

Test::Pod->import() ;

all_pod_files_ok() ;
