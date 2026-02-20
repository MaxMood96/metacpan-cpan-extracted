#!/usr/bin/env perl

use strict;
use warnings;

use lib "lib";

use Test2::V0;
use Plack::Test;
use HTTP::Request::Common; # Provides GET, POST, etc.
use File::Spec;

use Plack::App::File;
use Plack::Middleware::DirIndex::Htaccess;
use Plack::Middleware::ErrorDocument;

my $root = File::Spec->catdir( "t", "root" );

# Setup .htaccess for testing
my $htaccess_path = File::Spec->catfile( $root, 'apache', '.htaccess' );
open( my $fh, '>', $htaccess_path ) or die "Can't create .htaccess: $!";
print $fh "DirectoryIndex test.html\n";
close $fh;

# --- Test Set 1: Default Configuration ---
subtest 'Default Configuration' => sub {
    my $app = Plack::App::File->new( { root => $root } )->to_app;
    $app = Plack::Middleware::DirIndex::Htaccess->wrap( $app, root => $root );
    $app = Plack::Middleware::ErrorDocument->wrap( $app, 404 => "$root/404.html" );

    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Basic request' => sub {
            my $res = $cb->( GET '/index.html' );
            is $res->code, 200;
            is $res->content, 'Index', 'Got content as expected';
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };

        subtest 'Index request' => sub {
            my $res = $cb->( GET '/' );
            is $res->content, 'Index';
        };

        subtest 'Dir with no index file' => sub {
            my $res = $cb->( GET '/other/' );
            is $res->code, 404;
            is $res->content, '404 page';
        };

        subtest 'Dir with .htaccess' => sub {
            my $res = $cb->( GET '/apache/' );
            like $res->content, qr[Test];
        };
    };
};

# --- Test Set 2: Alternative Index ---
subtest 'Alternative Index (alt.html)' => sub {
    my $app = Plack::App::File->new( { root => $root } )->to_app;
    $app = Plack::Middleware::DirIndex::Htaccess->wrap( $app, dir_index => 'alt.html', root => $root );
    $app = Plack::Middleware::ErrorDocument->wrap( $app, 404 => "$root/404.html" );

    test_psgi $app, sub {
        my $cb = shift;

        subtest 'Dir with no matching index file' => sub {
            my $res = $cb->( GET '/' );
            is $res->code, 404;
            is $res->content, '404 page';
        };

        subtest 'Basic request for alternative index file' => sub {
            my $res = $cb->( GET '/other/' );
            is $res->content, 'Alt Index';
            is $res->header('Content-Type'), 'text/html; charset=utf-8';
        };
    };
};

done_testing;
