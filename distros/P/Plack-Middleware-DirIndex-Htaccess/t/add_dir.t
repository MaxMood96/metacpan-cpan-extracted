use strict;
use warnings;

use lib "lib";

use Test2::V0;
use Plack::Builder;
use Plack::Test;
use File::Spec;

use Plack::App::Directory;
use Plack::Middleware::DirIndex::Htaccess;
use Plack::Middleware::ErrorDocument;

BEGIN {
    use lib "t";
    require "app_tests.pl";
}

my $root = File::Spec->catdir( "t", "root" );

#
# Note: I couldn't get dzil build to copy the .htaccess file, so we'll
# create it here.
#
open( my $htaccess, '>', File::Spec->catdir( 't', 'root', 'apache', '.htaccess' ) );
print $htaccess "DirectoryIndex test.html\n";
close $htaccess;

my $app = Plack::App::Directory->new( { root => $root } )->to_app;
$app = Plack::Middleware::DirIndex::Htaccess->wrap( $app, root => $root );

app_tests
    app   => $app,
    tests => [
    {   name    => 'Basic request',
        request => [ GET => '/index.html' ],
        content => 'Index',
        headers => { 'Content-Type' => 'text/html; charset=utf-8', },
    },
    {   name    => 'Index request',
        request => [ GET => '/' ],
        content => 'Index',
        headers => { 'Content-Type' => 'text/html; charset=utf-8', },
    },
    {   name    => 'Dir with no index file',
        request => [ GET => '/other/' ],
        content => qr[<title>Index of /other/</title>],
        headers => { 'Content-Type' => 'text/html; charset=utf-8', },
    },
    {   name    => 'Dir with .htaccess',
        request => [ GET => '/apache/' ],
        content => qr[Test],
        headers => { 'Content-Type' => 'text/html; charset=utf-8', },
    },
    {   name    => 'Bad 404 request',
        request => [ GET => '/missing.html' ],
        code => 404,
        content => qr[Not Found]i,
        headers => { 'Content-Type' => 'text/plain', },
    },
    ];

# Now test setting up alternative index (alt.html) file, not default
my $app2 = Plack::App::File->new( { root => $root } )->to_app;
$app2 = Plack::Middleware::DirIndex::Htaccess->wrap( $app2, dir_index => 'alt.html', root => $root );
$app2 = Plack::Middleware::ErrorDocument->wrap( $app2,
    404 => "$root/404.html");

app_tests
    app   => $app2,
    tests => [
    {   name    => 'Dir with no matching index file (now)',
        request => [ GET => '/' ],
        code => 404,
        content => qr[404 page]i,
        headers => { 'Content-Type' => 'text/html', },
    },
    {   name    => 'Basic request for alternative index file',
        request => [ GET => '/other/' ],
        content => 'Alt Index',
        headers => { 'Content-Type' => 'text/html; charset=utf-8', },
    },
    {   name    => 'Bad 404 request',
        request => [ GET => '/missing.html' ],
        code => 404,
        content => qr[404 page]i,
        headers => { 'Content-Type' => 'text/html', },
    },
    ];

done_testing;
