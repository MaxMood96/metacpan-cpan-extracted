#!/usr/bin/env perl

use strict;
use warnings;
use JSON;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use File::Spec::Functions qw(catfile);

use DBI;
use Plack::Test;
use HTTP::Request::Common qw(GET POST PUT DELETE);

my $dir     = tempdir(CLEANUP => 1);
my $db_file = catfile($dir, 'test.db');
my $lib_dir = catfile($dir, 'lib');

make_path($lib_dir);
unshift @INC, $lib_dir;

my $schema_file = catfile($lib_dir, 'Test', 'Schema.pm');
make_path(catfile($lib_dir, 'Test'));

open my $fh, '>', $schema_file or die "Cannot create $schema_file: $!";
print $fh <<'END_SCHEMA';
package Test::Schema;
use base 'DBIx::Class::Schema';

__PACKAGE__->load_namespaces;

1;
END_SCHEMA
close $fh;

my $user_file = catfile($lib_dir, 'Test', 'Schema', 'Result', 'User.pm');
make_path(catfile($lib_dir, 'Test', 'Schema', 'Result'));

open $fh, '>', $user_file or die "Cannot create $user_file: $!";
print $fh <<'END_USER';
package Test::Schema::Result::User;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components('Core');
__PACKAGE__->table('users');
__PACKAGE__->add_columns(
    id => {
        data_type => 'integer',
        is_auto_increment => 1,
        is_nullable => 0,
    },
    name => {
        data_type => 'text',
        is_nullable => 0,
    },
);
__PACKAGE__->set_primary_key('id');

1;
END_USER
close $fh;

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
    RaiseError => 1,
    AutoCommit => 1,
});

$dbh->do(q{
    CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
    )
});

for my $i (1..10) {
    $dbh->do(qq{ INSERT INTO users (name) VALUES ('User$i') });
}

$dbh->disconnect;

{
    package TestApp;
    use Dancer2;
    use Dancer2::Plugin::DBIC::Async;

    set serializer  => 'JSON';
    set show_errors => 1;

    set('plugins' => {
        'DBIC::Async' => {
            default => {
                schema_class => 'Test::Schema',
                dsn          => "dbi:SQLite:dbname=$db_file",
                user         => '',
                password     => '',
                async        => { workers => 2 },
            },
        }
    });

    get '/count' => sub {
        my $future = async_count('User');
        my $count  = $future->get;
        return { count => $count };
    };

    get '/find/:id' => sub {
        my $future = async_find('User', route_parameters->get('id'));
        my $user   = $future->get;
        return $user || { error => 'User not found' };
    };

    get '/search' => sub {
        my $future = async_search('User', { name => { -like => 'User%' } });
        my $users  = $future->get;
        return { count => scalar(@$users) };
    };

    post '/create' => sub {
        my $data   = from_json(request->body);
        my $future = async_create('User', { name => $data->{name} });
        my $user   = $future->get;
        return $user;
    };

    put '/update/:id' => sub {
        my $data   = from_json(request->body);
        my $future = async_update(
            'User',
            route_parameters->get('id'),
            { name => $data->{name} }
        );
        my $result = $future->get;
        return { success => $result };
    };

    del '/delete/:id' => sub {
        my $future = async_delete('User', route_parameters->get('id'));
        my $result = $future->get;
        return { success => $result };
    };
}

my $app = Plack::Test->create(TestApp->to_app);

subtest 'Count operation' => sub {
    my $res = $app->request(GET '/count');
    ok($res->is_success, 'Count request successful');

    my $data = decode_json($res->content);
    is($data->{count}, 10, 'Found all 10 users');
};

subtest 'Search operation' => sub {
    my $res = $app->request(GET '/search');
    ok($res->is_success, 'Search request successful');

    my $data = decode_json($res->content);
    is($data->{count}, 10, 'Search found all matching users');
};

subtest 'Find operation' => sub {
    my $res = $app->request(GET '/find/1');
    ok($res->is_success, 'Find request successful');

    my $data = decode_json($res->content);
    is($data->{id}, 1, 'Found user with id 1');
    is($data->{name}, 'User1', 'User has correct name');
};

subtest 'Create operation' => sub {
    my $res_before   = $app->request(GET '/count');
    my $data_before  = decode_json($res_before->content);
    my $count_before = $data_before->{count};

    my $res_create = $app->request(POST '/create',
        Content_Type => 'application/json',
        Content      => encode_json({ name => 'NewUser' })
    );
    ok($res_create->is_success, 'Create request successful');

    my $data_create = decode_json($res_create->content);
    like($data_create->{name}, qr/NewUser/, 'Created user has correct name');

    my $res_after   = $app->request(GET '/count');
    my $data_after  = decode_json($res_after->content);
    my $count_after = $data_after->{count};

    is($count_after, $count_before + 1, "Count incremented correctly from $count_before");
};

subtest 'Update operation' => sub {
    my $res_update = $app->request(PUT '/update/1',
        Content_Type => 'application/json',
        Content      => encode_json({ name => 'UpdatedName' })
    );

    ok($res_update->is_success, 'Update request successful');

    my $data_update = decode_json($res_update->content);
    is($data_update->{success}, 1, 'One row updated');

    my $res_find  = $app->request(GET '/find/1');
    my $data_find = decode_json($res_find->content);
    is($data_find->{name}, 'UpdatedName', 'User name was updated');
};

subtest 'Delete operation' => sub {
    my $res_create = $app->request(POST '/create',
        Content_Type => 'application/json',
        Content      => encode_json({ name => 'UserToDelete' })
    );

    my $data_create  = decode_json($res_create->content);
    my $id_to_delete = $data_create->{id};

    my $res_delete = $app->request(DELETE "/delete/$id_to_delete");
    ok($res_delete->is_success, 'Delete request successful');

    my $data_delete = decode_json($res_delete->content);
    is($data_delete->{success}, 1, 'Delete succeeded');

    my $res_find  = $app->request(GET "/find/$id_to_delete");
    my $data_find = decode_json($res_find->content);
    ok(exists $data_find->{error}, 'User no longer exists after deletion');
};

done_testing;
