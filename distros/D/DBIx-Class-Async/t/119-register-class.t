#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use lib 't/lib';

use IO::Async::Loop;
use DBIx::Class::Async::Schema;

{
    package My::Manual::User;
    use base 'DBIx::Class::Core';
    __PACKAGE__->table('manual_users');
    __PACKAGE__->add_columns(
        id   => { data_type => 'integer', is_auto_increment => 1 },
        name => { data_type => 'varchar', size => 100 },
    );
    __PACKAGE__->set_primary_key('id');
}

my $loop = IO::Async::Loop->new;
my $schema = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite::memory:", undef, undef,
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

subtest "Manual Class Registration" => sub {
    eval { $schema->register_class('ManualUser', 'My::Manual::User') };
    ok(!$@, "register_class executed without error") or diag $@;

    is($schema->class('ManualUser'), 'My::Manual::User',
       "Schema correctly mapped 'ManualUser' to the class string");

    my $rs = eval { $schema->resultset('ManualUser') };
    ok($rs, "Created ResultSet for the manually registered class");
    isa_ok($rs, 'DBIx::Class::Async::ResultSet');

    my $source = $rs->result_source;
    is($source->from, 'manual_users', "ResultSource correctly identifies table name");
    ok($source->has_column('name'), "ResultSource has the correct columns");
};

$schema->disconnect;

done_testing;
