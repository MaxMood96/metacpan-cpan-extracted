#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use lib './t/lib';
use lib './lib';

use Yote::SQLObjectStore;
use SQLite::SomeThing;

use File::Temp qw/ :mktemp tempdir /;
use Test::Exception;
use Test::More;

my $factory = Factory->new;

$factory->setup;

sub make_all_tables {
    my $object_store = shift;
    local @INC = qw( ./lib ./t/lib );
    $object_store->make_all_tables( @INC );
}

subtest 'find_by tests' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    # Create some test objects
    my $alice = $object_store->new_obj( 'SQLite::SomeThing', name => 'alice', tagline => 'first' );
    my $bob   = $object_store->new_obj( 'SQLite::SomeThing', name => 'bob', tagline => 'second' );
    my $carol = $object_store->new_obj( 'SQLite::SomeThing', name => 'carol', tagline => 'first' );

    $object_store->save;

    # Test find_by via store method
    my $found = $object_store->find_by( 'SQLite::SomeThing', 'name', 'bob' );
    ok( $found, 'find_by found an object' );
    is( $found->get_name, 'bob', 'find_by found the correct object' );

    # Test find_by returns undef for non-existent value
    my $not_found = $object_store->find_by( 'SQLite::SomeThing', 'name', 'nobody' );
    is( $not_found, undef, 'find_by returns undef for non-existent value' );

    # Test find_by via class method (AUTOLOAD)
    my $found_class = SQLite::SomeThing->find_by_name( $object_store, 'alice' );
    ok( $found_class, 'find_by_name class method found an object' );
    is( $found_class->get_name, 'alice', 'find_by_name found the correct object' );

    # Test find_by_tagline
    my $first_tagged = SQLite::SomeThing->find_by_tagline( $object_store, 'first' );
    ok( $first_tagged, 'find_by_tagline found an object' );
    ok( $first_tagged->get_tagline eq 'first', 'find_by_tagline found correct tagline' );
};

subtest 'find_all_by tests' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    # Create test objects with shared taglines
    my $alice = $object_store->new_obj( 'SQLite::SomeThing', name => 'alice', tagline => 'admin' );
    my $bob   = $object_store->new_obj( 'SQLite::SomeThing', name => 'bob', tagline => 'user' );
    my $carol = $object_store->new_obj( 'SQLite::SomeThing', name => 'carol', tagline => 'admin' );
    my $dave  = $object_store->new_obj( 'SQLite::SomeThing', name => 'dave', tagline => 'admin' );

    $object_store->save;

    # Test find_all_by via store method
    my @admins = $object_store->find_all_by( 'SQLite::SomeThing', 'tagline', 'admin' );
    is( scalar @admins, 3, 'find_all_by found 3 admins' );

    # Test find_all_by returns empty list for no matches
    my @none = $object_store->find_all_by( 'SQLite::SomeThing', 'tagline', 'superuser' );
    is( scalar @none, 0, 'find_all_by returns empty list for no matches' );

    # Test find_all_by via class method (AUTOLOAD)
    my @users = SQLite::SomeThing->find_all_by_tagline( $object_store, 'user' );
    is( scalar @users, 1, 'find_all_by_tagline found 1 user' );
    is( $users[0]->get_name, 'bob', 'find_all_by_tagline found bob' );

    # Test with limit option
    my @limited = $object_store->find_all_by( 'SQLite::SomeThing', 'tagline', 'admin', limit => 2 );
    is( scalar @limited, 2, 'find_all_by with limit returns limited results' );

    # Test with order_by option
    my @ordered = $object_store->find_all_by( 'SQLite::SomeThing', 'tagline', 'admin', order_by => 'name ASC' );
    is( scalar @ordered, 3, 'find_all_by with order_by returns all results' );
    is( $ordered[0]->get_name, 'alice', 'first result is alice (ordered by name ASC)' );
    is( $ordered[2]->get_name, 'dave', 'last result is dave (ordered by name ASC)' );

    # Test with order_by DESC
    my @desc = $object_store->find_all_by( 'SQLite::SomeThing', 'tagline', 'admin', order_by => 'name DESC' );
    is( $desc[0]->get_name, 'dave', 'first result is dave (ordered by name DESC)' );
    is( $desc[2]->get_name, 'alice', 'last result is alice (ordered by name DESC)' );
};

subtest 'find_first_by tests' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    # Create test objects
    my $alice = $object_store->new_obj( 'SQLite::SomeThing', name => 'alice', tagline => 'team' );
    my $bob   = $object_store->new_obj( 'SQLite::SomeThing', name => 'bob', tagline => 'team' );

    $object_store->save;

    # Test find_first_by via class method
    my $first = SQLite::SomeThing->find_first_by_tagline( $object_store, 'team' );
    ok( $first, 'find_first_by found an object' );
    is( $first->get_tagline, 'team', 'find_first_by found object with correct tagline' );

    # Test find_first_by returns undef for no matches
    my $none = SQLite::SomeThing->find_first_by_tagline( $object_store, 'nonexistent' );
    is( $none, undef, 'find_first_by returns undef for no matches' );
};

subtest 'find_where tests' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    # Create test objects
    my $alice = $object_store->new_obj( 'SQLite::SomeThing', name => 'alice', tagline => 'admin' );
    my $bob   = $object_store->new_obj( 'SQLite::SomeThing', name => 'bob', tagline => 'user' );
    my $carol = $object_store->new_obj( 'SQLite::SomeThing', name => 'carol', tagline => 'admin' );

    $object_store->save;

    # Test find_where via store method
    my @results = $object_store->find_where( 'SQLite::SomeThing', tagline => 'admin' );
    is( scalar @results, 2, 'find_where found 2 admins' );

    # Test find_where with multiple criteria
    my @specific = $object_store->find_where( 'SQLite::SomeThing',
        name => 'alice',
        tagline => 'admin'
    );
    is( scalar @specific, 1, 'find_where with multiple criteria found 1 result' );
    is( $specific[0]->get_name, 'alice', 'find_where found alice' );

    # Test find_where with _single option
    my $single = $object_store->find_where( 'SQLite::SomeThing',
        tagline => 'admin',
        _single => 1
    );
    ok( $single, 'find_where with _single returns an object' );
    is( $single->get_tagline, 'admin', 'find_where _single returned admin' );

    # Test find_where with _single returns undef for no match
    my $no_match = $object_store->find_where( 'SQLite::SomeThing',
        name => 'nobody',
        _single => 1
    );
    is( $no_match, undef, 'find_where _single returns undef for no match' );

    # Test find_where via class method
    my @class_results = SQLite::SomeThing->find_where( $object_store,
        tagline => 'user'
    );
    is( scalar @class_results, 1, 'class method find_where found 1 user' );
    is( $class_results[0]->get_name, 'bob', 'class method find_where found bob' );

    # Test with _limit
    my @limited = $object_store->find_where( 'SQLite::SomeThing',
        tagline => 'admin',
        _limit => 1
    );
    is( scalar @limited, 1, 'find_where with _limit returns limited results' );

    # Test with _order_by
    my @ordered = $object_store->find_where( 'SQLite::SomeThing',
        tagline => 'admin',
        _order_by => 'name DESC'
    );
    is( $ordered[0]->get_name, 'carol', 'find_where _order_by DESC worked' );
};

subtest 'validation and error handling' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    # Test searching by non-existent field
    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'nonexistent_field', 'value' );
    } qr/Field 'nonexistent_field' does not exist/, 'throws for non-existent field';

    # Test searching by reference field (should fail)
    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'brother', 123 );
    } qr/Cannot search by reference field 'brother'/, 'throws when searching by reference field';

    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'sister', 123 );
    } qr/Cannot search by reference field 'sister'/, 'throws when searching by wildcard reference field';

    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'some_ref_array', 123 );
    } qr/Cannot search by reference field 'some_ref_array'/, 'throws when searching by array reference field';

    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'some_ref_hash', 123 );
    } qr/Cannot search by reference field 'some_ref_hash'/, 'throws when searching by hash reference field';

    # Test SQL injection prevention in field name
    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', 'name; DROP TABLE', 'value' );
    } qr/Invalid field name/, 'throws for invalid field name (SQL injection attempt)';

    throws_ok {
        $object_store->find_by( 'SQLite::SomeThing', "name'--", 'value' );
    } qr/Invalid field name/, 'throws for invalid field name with quote';
};

subtest 'cache integration' => sub {
    my $dir = $factory->new_db_name;

    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
    );
    make_all_tables( $object_store );
    $object_store->open;

    my $alice = $object_store->new_obj( 'SQLite::SomeThing', name => 'alice', tagline => 'test' );
    $object_store->save;

    # Find the object
    my $found1 = $object_store->find_by( 'SQLite::SomeThing', 'name', 'alice' );
    my $found2 = $object_store->find_by( 'SQLite::SomeThing', 'name', 'alice' );

    # Both should be the same reference (from cache)
    is( $found1, $found2, 'multiple finds return same cached reference' );
};

done_testing;

$factory->teardown;
exit;

package Factory;

use File::Temp qw/ :mktemp tempdir /;

sub new_db_name {
    my ( $self ) = @_;
    my $dir = tempdir( CLEANUP => 1 );
    return $dir;
}

sub new {
    my ($pkg, %args) = @_;
    return bless { args => {%args} }, $pkg;
}

sub teardown {
    my $self = shift;
}

sub setup {
    my $self = shift;
}
