#!/usr/bin/env perl

use strict;
use warnings;

use lib "lib";

use Test2::V0;
use Plack::Test;
use HTTP::Request::Common;
use File::Spec;

use Plack::App::Directory;
use Plack::App::File;
use Plack::Middleware::DirIndex::Htaccess;
use Plack::Middleware::ErrorDocument;

my $root = File::Spec->catdir( "t", "root" );

# Setup .htaccess for testing
my $htaccess_path = File::Spec->catfile( $root, 'apache', '.htaccess' );
open( my $fh, '>', $htaccess_path ) or die "Can't create .htaccess: $!";
print $fh "DirectoryIndex test.html\n";
close $fh;

# --- Test Set 1: Plack::App::Directory ---
subtest 'Plack::App::Directory with Defaults' => sub {
    my $app = Plack::App::Directory->new( { root => $root } )->to_app;
    $app = Plack::Middleware::DirIndex::Htaccess->wrap( $app, root => $root );

    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Basic request' => sub {
            my $res = $cb->( GET '/index.html' );
            is $res->code, 200;
            is $res->content, 'Index';
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Index request' => sub {
            my $res = $cb->( GET '/' );
            is $res->code, 200;
            is $res->content, 'Index';
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Dir with no index file (Directory Listing)' => sub {
            my $res = $cb->( GET '/other/' );
            is $res->code, 200;
            like $res->content, qr[<title>Index of /other/</title>];
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Dir with .htaccess' => sub {
            my $res = $cb->( GET '/apache/' );
            is $res->code, 200;
            like $res->content, qr[Test];
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Bad 404 request' => sub {
            my $res = $cb->( GET '/missing.html' );
            is $res->code, 404;
            like $res->content, qr[Not Found]i;
            is $res->header('Content-Type'), 'text/plain';
        };
    };
};

# --- Test Set 2: Plack::App::File with Alt Index ---
subtest 'Plack::App::File with Alternative Index' => sub {
    # Note: Switching to Plack::App::File here as per original test logic
    my $app = Plack::App::File->new( { root => $root } )->to_app;
    $app = Plack::Middleware::DirIndex::Htaccess->wrap( $app, dir_index => 'alt.html', root => $root );
    $app = Plack::Middleware::ErrorDocument->wrap( $app, 404 => "$root/404.html" );

    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Dir with no matching index file (now)' => sub {
            my $res = $cb->( GET '/' );
            is $res->code, 404;
            like $res->content, qr[404 page]i;
            is $res->header('Content-Type'), 'text/html';
        };

        subtest 'Basic request for alternative index file' => sub {
            my $res = $cb->( GET '/other/' );
            is $res->code, 200;
            is $res->content, 'Alt Index';
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Bad 404 request' => sub {
            my $res = $cb->( GET '/missing.html' );
            is $res->code, 404;
            like $res->content, qr[404 page]i;
            is $res->header('Content-Type'), 'text/html';
        };
    };
};

done_testing;
