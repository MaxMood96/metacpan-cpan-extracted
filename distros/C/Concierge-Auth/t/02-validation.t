#!/usr/bin/env perl

use v5.36;

use strict;
use warnings;
use Test2::V0;
use File::Temp qw/tempfile tempdir/;

use Concierge::Auth;

my $dir  = tempdir( CLEANUP => 1 );
my $file = "$dir/auth.pwd";
my $auth = Concierge::Auth->new({ file => $file });

# ========== validateID ==========

subtest 'validateID - valid IDs' => sub {
    for my $id ( 'ab', 'alice', 'user_name', 'user.name', 'user@host.com',
                 'user-name', 'A1', 'x' x 32 ) {
        my ($ok, $msg) = $auth->validateID($id);
        ok( $ok, "valid ID: '$id'" );
    }
};

subtest 'validateID - empty' => sub {
    my ($ok, $msg) = $auth->validateID('');
    ok( !$ok, 'empty ID rejected' );
    like( $msg, qr/empty/i, 'message mentions empty' );

    ($ok, $msg) = $auth->validateID(undef);
    ok( !$ok, 'undef ID rejected' );
};

subtest 'validateID - too short' => sub {
    my ($ok, $msg) = $auth->validateID('a');
    ok( !$ok, 'single-char ID rejected' );
    like( $msg, qr/between/i, 'message mentions length requirement' );
};

subtest 'validateID - too long' => sub {
    my ($ok, $msg) = $auth->validateID('x' x 33);
    ok( !$ok, '33-char ID rejected' );
    like( $msg, qr/between/i, 'message mentions length requirement' );
};

subtest 'validateID - invalid chars' => sub {
    for my $id ( 'user name', 'user!name', 'user#name', 'user$name' ) {
        my ($ok, $msg) = $auth->validateID($id);
        ok( !$ok, "invalid ID: '$id'" );
        like( $msg, qr/invalid/i, 'message mentions invalid characters' );
    }
};

subtest 'validateID - scalar context' => sub {
    my $ok = $auth->validateID('alice');
    ok( $ok, 'scalar context returns true for valid ID' );

    $ok = $auth->validateID('');
    ok( !$ok, 'scalar context returns false for invalid ID' );
};

# ========== validatePwd ==========

subtest 'validatePwd - valid passwords' => sub {
    for my $pwd ( 'password', 'x' x 8, 'x' x 72, 'P@ssw0rd!123' ) {
        my ($ok, $msg) = $auth->validatePwd($pwd);
        ok( $ok, "valid password (length " . length($pwd) . ")" );
    }
};

subtest 'validatePwd - empty' => sub {
    my ($ok, $msg) = $auth->validatePwd('');
    ok( !$ok, 'empty password rejected' );
    like( $msg, qr/empty/i, 'message mentions empty' );

    ($ok, $msg) = $auth->validatePwd(undef);
    ok( !$ok, 'undef password rejected' );
};

subtest 'validatePwd - too short' => sub {
    my ($ok, $msg) = $auth->validatePwd('short');
    ok( !$ok, '5-char password rejected' );
    like( $msg, qr/between/i, 'message mentions length requirement' );
};

subtest 'validatePwd - too long' => sub {
    my ($ok, $msg) = $auth->validatePwd('x' x 73);
    ok( !$ok, '73-char password rejected' );
    like( $msg, qr/between/i, 'message mentions length requirement' );
};

subtest 'validatePwd - scalar context' => sub {
    my $ok = $auth->validatePwd('password');
    ok( $ok, 'scalar context returns true for valid password' );

    $ok = $auth->validatePwd('');
    ok( !$ok, 'scalar context returns false for invalid password' );
};

# ========== validateFile ==========

subtest 'validateFile - existing file' => sub {
    my ($ok, $msg) = $auth->validateFile($file);
    ok( $ok, 'existing file validates' );
    like( $msg, qr/OK/i, 'message confirms OK' );
};

subtest 'validateFile - missing file' => sub {
    my ($ok, $msg) = $auth->validateFile('/nonexistent/file.pwd');
    ok( !$ok, 'missing file rejected' );
    like( $msg, qr/Not OK/i, 'message indicates not OK' );
};

subtest 'validateFile - no file set' => sub {
    my $nofile_auth;
    my $w = warnings { $nofile_auth = Concierge::Auth->new({ no_file => 1 }) };
    my ($ok, $msg) = $nofile_auth->validateFile();
    ok( !$ok, 'no file set rejected' );
};

subtest 'validateFile - scalar context' => sub {
    my $ok = $auth->validateFile($file);
    ok( $ok, 'scalar context returns true for valid file' );

    $ok = $auth->validateFile('/nonexistent/file.pwd');
    ok( !$ok, 'scalar context returns false for invalid file' );
};

done_testing;
