#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);

use DBI;
use Plack::Test;
use HTTP::Request::Common;

my $dir      = tempdir(CLEANUP => 1);
my $db_file1 = catfile($dir, 'test1.db');
my $db_file2 = catfile($dir, 'test2.db');

foreach my $file ($db_file1, $db_file2) {
    my $name = ($file eq $db_file1) ? 'DB1' : 'DB2';
    my $dbh  = DBI->connect("dbi:SQLite:dbname=$file", "", "", { RaiseError => 1 });
    $dbh->do("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)");
    $dbh->do("INSERT INTO users (name) VALUES ('$name-User1')");
    $dbh->do("INSERT INTO users (name) VALUES ('DB1-User2')") if $file eq $db_file1;
    $dbh->disconnect;
}

{
    package TestApp;
    use Dancer2;
    use lib 't/lib';

    set serializer => 'JSON';
    set plugins => {
        'DBIC::Async' => {
            default   => { schema_class => 'Test::Schema', dsn => "dbi:SQLite:dbname=$db_file1" },
            secondary => { schema_class => 'Test::Schema', dsn => "dbi:SQLite:dbname=$db_file2" },
        },
    };
    use Dancer2::Plugin::DBIC::Async;

    get '/db1/count' => sub {
        return { count => async_count('User')->get + 0 };
    };

    get '/db1/find/:id' => sub {
        return async_find('User', route_parameters->get('id'))->get;
    };

    get '/db2/find/:id' => sub {
        return async_find('User', route_parameters->get('id'), 'secondary')->get;
    };
}

my $app = Plack::Test->create(TestApp->to_app);

subtest 'Connection Routing' => sub {
    my $res1 = $app->request(GET '/db1/find/1');
    is($res1->code, 200, 'DB1 OK');
    like($res1->content, qr/DB1-User1/, 'Found DB1-User1 via auto-serialization');

    my $res2 = $app->request(GET '/db2/find/1');
    is($res2->code, 200, 'DB2 OK');
    like($res2->content, qr/DB2-User1/, 'Found DB2-User1 via auto-serialization');
};

done_testing;
