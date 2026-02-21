#!/usr/bin/env perl

use feature ':5.16';

use strict;
use warnings;
use utf8;

use Test2::V0;

use HTTP::Request::Common;
use Path::Tiny;
use Plack::Builder;
use Plack::Test;

use lib 'lib';
use Plack::Middleware::DirListing;

# Setup a dummy directory structure for testing
my $temp_dir = Path::Tiny->tempdir;
my $subdir = $temp_dir->child( 'subdir' )->mkdir();
$subdir->child( 'testfile.txt' )->spew_utf8( 'Hello world' );

# Define the app with this middleware
my $app = builder {
    enable "DirListing", root => $temp_dir->stringify;
    sub { [404, ['Content-Type' => 'text/plain'], ['Not Found']] };
};

test_psgi $app, sub {
    my $cb = shift;

    subtest "Directory without trailing slash" => sub {
        # Request 'subdir' instead of 'subdir/'
        my $res = $cb->( GET "/subdir" );

        is $res->code, 301, "Response is 301 Redirect";
        like $res->header('Location'), qr#/subdir/$#, "Redirects to version with trailing slash";
    };

    subtest "Directory with trailing slash (baseline)" => sub {
        my $res = $cb->( GET "/subdir/" );
        is $res->code, 200, "Response is 200 OK";
        like $res->content, qr/testfile\.txt/, "File name is visible in listing";
        like $res->content, qr/href="\/subdir\/testfile\.txt"/, "Link is correct with trailing slash";
    };

    subtest "Test with query strings" => sub {
        my $res = $cb->( GET "subdir?foo=bar" );
        is $res->code, 301, "Response is 301 Redirect";
        like $res->header('Location'), qr#/subdir/\?foo=bar$#, "Redirects to version with trailing slash";
    };
};

done_testing;
