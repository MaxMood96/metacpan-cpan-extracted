#!perl -w

use strict;
use warnings;

use Test::DescribeMe qw(author);
use Test::Most;
use Test::Needs { 'Test::Pod' => '1.22' };
use Test::Warnings;

Test::Pod->import();

all_pod_files_ok();
