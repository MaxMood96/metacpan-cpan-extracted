use Test2::V0 -target => 'DBIx::QuickORM', '!meta', '!pass';
use DBIx::QuickORM;
use Carp::Always;
use Scalar::Util qw/blessed/;
use Time::HiRes qw/sleep/;

use lib 't/lib';
use DBIx::QuickORM::Test;

sub SCHEMA_DIR { 't/handle/schema' }

do_for_all_dbs {
    my $db = shift;

    db mydb => sub {
        dialect curdialect();
        db_name 'quickdb';
        connect sub { $db->connect };
    };

    orm my_orm => sub {
        db 'mydb';
        autofill;
    };

    ok(my $orm = orm('my_orm')->connect, "Got a connection");
    my $h = $orm->handle('example');
    ok($h->insert({name => 'a'}), "Inserted a row");
    ok($h->insert({name => 'b'}), "Inserted a row");
    ok($h->insert({name => 'c'}), "Inserted a row");
    ok($h->insert({name => 'd'}), "Inserted a row");
    ok($h->insert({name => 'e'}), "Inserted a row");

    is($h->count, 5, "Counted 5 rows");

    is($h->count({name => {-in => ['c', 'd']}}), 2, "Counted 2 rows");
};

done_testing;

