# -*- perl -*-
use strict;
use warnings;
use lib './lib';
use Test::More qw( no_plan );
use Nice::Try;

# Credits to Steve Scaffidi for his test suit

# try can apply loop controls
{
    no warnings 'exiting';
    my $count = 0;
    LOOP: {
        try {
            $count++;
            redo LOOP if $count < 2;
        }
        catch { }
    }

    is( $count, 2, 'try{redo} works' );

    $count = 0;

    LOOP2: {
        try {
            last LOOP2;
        }
        catch { }
        $count++;
    }

    is( $count, 0, 'try{last} works' );
}

# catch can apply loop controls
{
    no warnings 'exiting';
    my $count = 0;
    LOOP: {
        try {
            die "oopsie";
        }
        catch {
            $count++;
            redo LOOP if $count < 2;
        }
    }

    is( $count, 2, 'catch{redo} works' );

    $count = 0;

    LOOP2: {
        try {
            die "oopsie";
        }
        catch {
            last LOOP2;
        }
        $count++;
    }

    is( $count, 0, 'catch{last} works' );
}

done_testing;
