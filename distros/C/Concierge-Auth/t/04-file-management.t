#!/usr/bin/env perl

use v5.36;

use strict;
use warnings;
use Test2::V0;
use File::Temp qw/tempdir/;

use Concierge::Auth;

my $dir  = tempdir( CLEANUP => 1 );
my $file = "$dir/auth.pwd";
my $auth = Concierge::Auth->new({ file => $file });

# ========== pfile ==========

subtest 'pfile - returns path when set' => sub {
    my ($path, $msg) = $auth->pfile();
    ok( $path, 'pfile returns truthy value' );
    is( $path, $file, 'pfile returns correct path' );
};

subtest 'pfile - rejects when unset' => sub {
    my $nofile_auth;
    my $w = warnings { $nofile_auth = Concierge::Auth->new({ no_file => 1 }) };
    my ($path, $msg) = $nofile_auth->pfile();
    ok( !$path, 'pfile returns false when no file set' );
    like( $msg, qr/No auth file/i, 'message mentions no auth file' );
};

# ========== setFile ==========

subtest 'setFile - set new file' => sub {
    my $newfile = "$dir/new_auth.pwd";
    my ($ok, $msg) = $auth->setFile($newfile);
    ok( $ok, 'setFile succeeds' );
    ok( -e $newfile, 'new file was created' );

    my ($path) = $auth->pfile();
    is( $path, $newfile, 'pfile reflects new file' );

    # Switch back for remaining tests
    $auth->setFile($file);
};

# ========== rmFile ==========

subtest 'rmFile - remove file' => sub {
    # Create a temporary file to remove
    my $rmfile = "$dir/rm_test.pwd";
    my $rm_auth = Concierge::Auth->new({ file => $rmfile });

    ok( -e $rmfile, 'file exists before rmFile' );

    my ($result, $msg) = $rm_auth->rmFile();
    ok( $result, 'rmFile returns truthy' );
    ok( !-e $rmfile, 'file is gone after rmFile' );
};

# ========== clearFile ==========

subtest 'clearFile - clear and recreate' => sub {
    # Create a file with a user in it
    my $clrfile = "$dir/clear_test.pwd";
    my $clr_auth = Concierge::Auth->new({ file => $clrfile });
    $clr_auth->setPwd('testuser', 'password123');

    # Confirm user exists
    my ($found) = $clr_auth->checkID('testuser');
    ok( $found, 'user exists before clearFile' );

    # Clear the file
    my ($ok, $msg) = $clr_auth->clearFile();
    ok( $ok, 'clearFile succeeds' );
    like( $msg, qr/cleared/i, 'message mentions cleared' );

    # File should still exist but be empty
    ok( -e $clrfile, 'file still exists after clearFile' );

    # User should be gone
    my ($gone) = $clr_auth->checkID('testuser');
    ok( !$gone, 'user is gone after clearFile' );
};

done_testing;
