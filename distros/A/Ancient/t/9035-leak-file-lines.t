#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use_ok('file');

my $tmpdir = tempdir(CLEANUP => 1);

# Create test file with multiple lines
my $test_file = "$tmpdir/lines.txt";
file::spew($test_file, join("\n", map { "line $_" } 1..100));

# Warmup
for (1..10) {
    my $lines = file::lines($test_file);
    file::each_line($test_file, sub { });
}

subtest 'lines no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $lines = file::lines($test_file);
        }
    } 'lines does not leak';
};

subtest 'each_line with shift no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            file::each_line($test_file, sub {
                my $line = shift;
            });
        }
    } 'each_line with shift does not leak';
};

subtest 'each_line with $_ no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            file::each_line($test_file, sub {
                my $len = length($_);
            });
        }
    } 'each_line with $_ does not leak';
};

subtest 'lines_iter no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $iter = file::lines_iter($test_file);
            while (!$iter->eof) {
                my $line = $iter->next;
            }
            $iter->close;
        }
    } 'lines_iter does not leak';
};

subtest 'lines_iter early close no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($test_file);
            my $line = $iter->next;  # Read just one
            $iter->close;
        }
    } 'lines_iter early close does not leak';
};

subtest 'head no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $lines = file::head($test_file, 10);
        }
    } 'head does not leak';
};

subtest 'tail no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $lines = file::tail($test_file, 10);
        }
    } 'tail does not leak';
};

done_testing();
