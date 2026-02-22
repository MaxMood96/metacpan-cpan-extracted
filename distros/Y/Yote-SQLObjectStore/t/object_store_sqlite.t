#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use lib './t/lib';
use lib './lib';

use Yote::SQLObjectStore;

use Data::Dumper;
use File::Temp qw/ :mktemp tempdir /;
use Test::Exception;
use Test::More;

my $factory = Factory->new;

$factory->setup;
# -------------------------------------------------------------

sub sqlstr {
    my $pair = shift;
    my ($sql, @qparams) = @$pair;
    while (my $qp = shift @qparams) {
        $sql =~ s/\?/'$qp'/s;
    }
    print STDERR "$sql\n\n";
}

# bootstrappy clause
# to check if table creation is working at all
if(0){
    my $dir = $factory->new_db_name;
    my $object_store = Yote::SQLObjectStore->new( 'SQLite',
        BASE_DIRECTORY => $dir,
        );
    my @sql = $object_store->make_all_tables_sql;
    for my $sql (@sql) {
        sqlstr( $sql );
    }
    pass "barf";
    done_testing;
    exit;
}

sub make_all_tables {
    my $object_store = shift;
    local @INC = qw( ./lib ./t/lib );
    $object_store->make_all_tables( @INC );
}

subtest 'reference and reopen test' => sub {
    my $dir = $factory->new_db_name;


    {
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        make_all_tables( $object_store );
        $object_store->open;
        is ($object_store->record_count, 3, 'root record and its hashes in store');

        my $r1 = $object_store->fetch_root;
        ok ($r1, 'got a root');
        my $r2 = $object_store->fetch_root;
        is ($r1, $r2, "single reference for fetch root" );
        ok ($r1 == $r2, "same reference compared numerically" );
        ok (!($r1 != $r2), "same reference compared as not equal numerically" );
        ok (!($r1 == 1), "reference does not equal to a number" );
        ok ($r1 != 1, "reference is not equal to a number" );
        ok ($r1 eq $r2, "same reference compared as strings" );
        ok (!($r1 ne $r2), "same reference compared as not equal strings" );
        ok ($r1 != 1, "not equal to a number" );
        ok (! ($r1 eq 1), "not equal to a string" );
        ok ($r1 ne 1, "not the same as a number" );

        my $root_vals_hash = $r1->get_val_hash;
        is (ref $root_vals_hash, 'HASH', 'get_val_hash returns actual (tied) hash');
        is (ref tied %$root_vals_hash, 'Yote::SQLObjectStore::TiedHash', 'tied hash reference for vals hash' );
        is_deeply( $root_vals_hash, {}, 'val hash starts empty' );

        $root_vals_hash->{foo} = 'bar';
        $root_vals_hash->{bar} = 'gaz';
        $root_vals_hash->{fit} = "to be tied";

        my $tied = tied %$root_vals_hash;

        is_deeply( $tied->{data}, { foo => 'bar',
                                    fit => 'to be tied',
                                    bar => 'gaz'}, 'val hash with stuff in it' );

        # now gotta get stuff in the ref, like a [], {} and obj
        my $root_refs = $r1->get_ref_hash;
        is (ref $root_refs, 'HASH', 'get_ref_hash returns actual (tied) hash');
        is (ref tied %$root_refs, 'Yote::SQLObjectStore::TiedHash', 'tied hash reference for ref hash' );
        is_deeply( $root_refs, {}, 'ref hash starts empty' );

        # make some object too
        my $wilma = $object_store->new_obj( 'SQLite::SomeThing', name => 'wilma' );
        is (ref $wilma, 'SQLite::SomeThing', 'correct package for wilma' );
        my $brad = $object_store->new_obj( 'SQLite::SomeThing', name => 'brad', sister => $wilma  );

        throws_ok
            { $brad->set( 'not appearing', 122 ) }
            qr/No field/, 'throws when try to set a nonexistant field of an object';


        # make some data structures to put in root ref hash
        my $val_arry = $object_store->new_array( '*ARRAY_TEXT', 1,2,3 );
        is (ref $val_arry, 'ARRAY', 'get array ref for tied array');
        is (ref tied @$val_arry, 'Yote::SQLObjectStore::TiedArray', 'tied array reference for val array' );
        is_deeply( $val_arry, [1,2,3], 'val array values' );
        $root_refs->{val_array} = $val_arry;

        my $ref_arry =
            $object_store->new_array( '*ARRAY_*', $r1, $wilma, $brad );
        $root_refs->{ref_array} = $ref_arry;

        my $val_hash =
            $object_store->new_hash( '*HASH<256>_TEXT', a => 1, b => 2, c => 3 );
        $root_refs->{val_hash} = $val_hash;

        my $ref_hash =
            $object_store->new_hash( '*HASH<256>_*', root => $r1);
        $root_refs->{ref_hash} = $ref_hash;

        throws_ok
            { $object_store->new_hash( '*HASH<123>_' ) }
            qr/Cannot create hash/, 'new hash throws when called with bad argument';

        throws_ok
            { $object_store->new_array( '*ARRAY_' ) }
            qr/Cannot create array/, 'new array throws when called with bad argument';


        my $mty =
            $object_store->new_hash( '*HASH<256>_TEXT' );
        $root_refs->{empty_hash} = $mty;

        $mty->{fooz} = 'barz';
        my $tiedmty = tied %$mty;
        is_deeply( $tiedmty->{data}, { fooz => 'barz' }, 'added fooz barz' );
        delete $mty->{fooz};
        is_deeply( $tiedmty->{data}, {}, 'deleted fooz barz' );

        is ($brad->get_name, 'brad', 'brad name' );
        is ($brad->get_sister, $wilma, 'brad sister is wilma' );
        is_deeply( $val_hash, { a => 1, b => 2, c => 3 }, 'val hash' );
        is_deeply( $ref_hash, { root => $r1 }, 'ref hash' );

        is_deeply( $val_arry, [1,2,3], 'val array' );
        is_deeply( $ref_arry, [$r1, $wilma, $brad ], 'ref array' );

        # data now looks like this
        #   /val_hash/foo -> bar
        #   /val_hash/bar -> gaz
        #   /ref_hash/val_array -> [1,2,3]
        #   /ref_hash/ref_array -> [root,wilma,brad]
        #   /ref_hash/val_hash/ {a =>1,b => 2, c => 3 }
        #   /ref_hash/ref_hash/root -> root
        #   /ref_hash/empty_hash -> {}

        $object_store->save;
    }

    {
        # reopen and make sure its the same stuff
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        $object_store->open;


        throws_ok
            { $object_store->fetch_string_path( "/val_hash/zoo/2" ) }
            qr~invalid path '2', 'zoo' is not a reference~, 'throws when nonexisting key is used for array ref';

        is ($object_store->fetch_string_path( "/val_hash/foo" ), 'bar', 'fetched value' );
        is ($object_store->fetch_string_path( "/val_hash/bar" ), 'gaz', 'fetched value' );



        is_deeply ($object_store->fetch_string_path( "/ref_hash/val_array" ), [1,2,3], 'fetched array ref' );
        is ($object_store->fetch_string_path( "/ref_hash/val_array/1" ), 2, 'fetched array ref val element' );
        throws_ok
            { $object_store->fetch_string_path( "/ref_hash/val_array/2/snicker" ) }
            qr/invalid path.*is not a reference/, 'throws when path tries to go past a value leaf of a reference array';


        my $root = $object_store->fetch_root;
        my $root_vals_hash = $root->get_val_hash;
        is_deeply( $root_vals_hash, { foo => 'bar',
                                 fit => 'to be tied',
                                 bar => 'gaz'}, 'val hash with stuff in it after reopen' );
        is ($object_store->fetch_string_path( "/val_hash/bar" ), 'gaz', 'fetched value when obj in cache' );
        $root_vals_hash->{zork} = 'money';

        is ($object_store->fetch_string_path("/ref_hash/ref_array/1/name"), 'wilma', 'wilma on path');
        throws_ok
            { $object_store->fetch_string_path( "/ref_hash/ref_array/2/in^alid" ) }
            qr/Invalid Column Name/, 'throws when attempting a weird field name';


        my $root_refs = $root->get_ref_hash;
        my @refs = @{$root_refs->{ref_array}};
        is (@refs, 3, '3 refs' );
        my ($loaded_root, $wilma, $brad) = @refs;
        is( $loaded_root, $root, 'roots are roots' );
        is ($brad->get_sister, $wilma, 'brad sister is wilma' );
        is ($brad->get_name, 'brad', 'brad name' );
        is_deeply( $root_refs->{val_array}, [1,2,3], 'val array' );
        is_deeply( $root_refs->{ref_array}, [$root, $wilma, $brad ], 'ref array' );
        is_deeply( $root_refs->{val_hash}, { a => 1, b => 2, c => 3 }, 'val hash' );
        is_deeply( $root_refs->{ref_hash}, { root => $root }, 'ref hash' );
        is_deeply( $root_refs->{empty_hash}, {}, 'empty ref hash' );

        is ($object_store->fetch_string_path( "/ref_hash/ref_array" ), $root_refs->{ref_array}, 'fetched path containing array' );
        is ($object_store->fetch_string_path( "/ref_hash/ref_array/2" ), $brad, 'fetched path containing array' );
        is ($object_store->fetch_string_path( "/ref_hash/ref_array/2/sister" ), $wilma, 'fetched path containing array and reference' );
        is ($object_store->fetch_string_path( "/ref_hash/ref_array/2/name" ), 'brad', 'fetched path containing array and value' );

        throws_ok
            { $object_store->fetch_string_path( "/ref_hash/ref_array/2/name/namenotobj" ) }
            qr/invalid path.*is not a reference/, 'throws when path tries to go past a value leaf';

        $brad->set_name( 'new brad' );
        is ($brad->get_name, 'new brad', 'brad new name' );
        my $mth = $object_store->fetch_string_path( "/ref_hash/empty_hash" );
        ok (! $object_store->is_dirty( $mth ), 'empty hash starts out not dirty' );
        my $mtth = $mth;
        ok (! $object_store->is_dirty( $mth ), 'empty hash not dirty' );
        ok (! $object_store->is_dirty( $mtth ), 'empty hash clone also not dirty' );
        is_deeply ($mtth, {}, 'fetched path containing empty hash' );
        $mth->{NOTEMPTY} = 'anymore';
        is_deeply( $mtth, { NOTEMPTY => 'anymore' }, 'newly filled formly empty hash' );
        ok ( $object_store->is_dirty( $mth ), 'no longer empty hash is dirty' );

        $mth->{NOTEMPTY} = undef;
        is_deeply( $mtth, { NOTEMPTY => undef }, 'sorta empty formly empty hash' );
        delete $mtth->{NOTEMPTY};
        is_deeply( $mtth, {}, 'sorta empty formly empty hash was deleted again' );
        $object_store->save;

        ok ( !$object_store->is_dirty( $mth ), 'empty hash no longer dirty after save' );
        is_deeply( $mtth, {}, 'back to empty hash' );

        throws_ok { $object_store->new_obj( 'SQLite::SomeThing', name => 'bad', sistery => $wilma  ) } qr/'sistery' does not exist/;
        my $bad = $object_store->new_obj( 'SQLite::SomeThing', name => 'bad' );
        is ($bad->get_sister, undef, 'bad has no sister' );
        $bad->set_something( $bad );
        is ($bad->get_something, $bad, 'bad is its own something' );


        # give bad a "sister" that is an array ref and "brother" that is array vals
        $bad->set_sister( $object_store->new_array('*ARRAY_*') );
        $bad->set_brother( $object_store->new_array('*ARRAY_TEXT') );
        $bad->set_some_ref_array( $bad->get_sister );
        $bad->set_some_val_array( $bad->get_brother );
        my $bad_ref_hash = $bad->set_some_ref_hash( $object_store->new_hash('*HASH<256>_*') );
        my $bad_val_hash_obj = $bad->set_some_val_hash( $object_store->new_hash('*HASH<256>_TEXT') );
        my $bad_val_hash = $bad_val_hash_obj;
        $bad_val_hash->{LEEROY} = 'brown';
        is( $bad->get_tagline( "TAGGY" ), "TAGGY", 'set via default get' );
        is_deeply ($bad->get_some_ref_array, [], 'bad ref array is empty array' );
        is_deeply ($bad->get_some_val_array, [], 'bad ref array is empty array' );

        is_deeply( $bad->fields, [sort qw(
                                      brother
                                      name
                                      lolov
                                      sister
                                      sisters
                                      sisters_hash
                                      some_ref_array
                                      some_ref_hash
                                      some_val_array
                                      some_val_hash
                                      something
                                      tagline
                                  )],
                   'fields for bad and all SomeThing refs' );
        is( $bad->table_name, 'SomeThing_SQLite', 'table name for SomeThing refs' );

        push @{$root_refs->{ref_array}}, $bad;
        push @{$root_refs->{ref_array}}, undef;
        $root_refs->{ref_hash}{wilma} = $wilma;

        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3" ), $bad, 'fetched path containing bad guy' );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/name" ), 'bad', 'fetched path containing bad guy name' );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_ref_hash" ), {}, 'fetched path containing hash ref in obj' );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array" ), [], 'fetched path containing array ref in obj' );
        is_deeply( $bad_val_hash, { LEEROY => 'brown' }, 'bad val hash' );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_hash" ), { LEEROY => 'brown' }, 'fetched path containing value hash' );
        is( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array/1" ), undef, 'fetched path to non extant index in array' );

        is ($object_store->fetch_string_path( "/ref_hash/ref_array/3/some_ref_hash/nothere" ), undef, 'nothing to see here is undef' );

        is ($object_store->fetch_string_path( "/ref_hash/ref_array/4" ), undef, 'last entry in ref array is undef' );

        $object_store->save;

        $wilma->set_tagline( "its gonna get hotter" );
        $object_store->save( $wilma );

        ok (! $object_store->is_dirty( $bad_val_hash_obj ), 'bad val hash is not dirty here' );
        $bad_val_hash->{LEEROY} = 'brown';
        ok (! $object_store->is_dirty( $bad_val_hash_obj ), 'bad val hash is still not dirty here' );
        delete $bad_val_hash->{NOTHERE};
        ok (! $object_store->is_dirty( $bad_val_hash_obj ), 'bad val hash is still not dirty after deleting nothing there' );

        ok (! $object_store->is_dirty( $bad_ref_hash ), 'bad ref hash is not dirty here' );
        %{$bad_ref_hash} = (); #clear it
        ok (! $object_store->is_dirty( $bad_ref_hash ), 'bad ref hash still not dirty here after clearing it remains the same' );

        ok (! $object_store->is_dirty( $bad_val_hash_obj ), 'bad val hash is not dirty here' );
        %$bad_val_hash = (); #clear it
        ok ($object_store->is_dirty( $bad_val_hash_obj ), 'bad val hash is dirty after clearing it' );

        # not saving it though, so the clearing wont show up next load



    }

    {
        # reopen and make sure its the same stuff
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        $object_store->open;
        my $root = $object_store->fetch_root;
        is ($object_store->has_id($root), 1, 'root has id 1');
        is ($object_store->has_id($root), $root->id, 'root still has id 1');
        my $root_vals_hash = $root->get_val_hash;
        ok ($object_store->has_id($root_vals_hash), 'root vals hash has id');
        is_deeply( $root_vals_hash, { foo  => 'bar',
                                 zork => 'money',
                                 fit => 'to be tied',
                                 bar  => 'gaz'}, 'val hash with stuff in it after reopen' );

        my $root_refs = $root->get_ref_hash;

        my $refs = $root_refs->{ref_array};
        ok ($object_store->has_id($refs), 'root refs array has id');
        is (@$refs, 5, '5 refs with bad and undef' );

        my ($loaded_root, $wilma, $brad, $bad, $undef) = @$refs;
        ok ($undef == 0, 'null  reference stored' );
        is ($brad->get_name, 'new brad', 'brad name still new brad' );
        is ($bad->get_name, 'bad', 'bad name' );
        is_deeply ($bad->get_sister, [], 'bad sister is empty array' );
        is_deeply ($bad->get_brother, [], 'bad brother is empty array' );
        is_deeply ($bad->get_some_ref_array, [], 'bad ref array is empty array' );
        is_deeply ($bad->get_some_val_array, [], 'bad value array is empty array' );
        is_deeply ($bad->get_some_ref_hash, {}, 'bad ref hash is empty' );
        is_deeply ($bad->get_some_val_hash, { LEEROY => 'brown' }, 'bad value hash same values' );
        is ($bad->get_tagline, "TAGGY", 'tag set via default get' );
        is ($bad->get_something, $bad, 'bad is its own something' );
        is ($wilma->get_name, 'wilma', 'wilma name' );
        is ($wilma->get_tagline, 'its gonna get hotter', 'wilma was saved with new tagline' );
        is ($loaded_root, $root, 'roots are roots' );
        is_deeply( $root_refs->{ref_hash}, { root => $root, wilma => $wilma }, 'ref hash' );

        ok (! $object_store->is_dirty( $bad ), 'bad is not dirty here' );
        $bad->set_tagline( "TAGGY" );
        ok (! $object_store->is_dirty( $bad ), 'bad is *still* not dirty here after setting the tagline to what it already was' );


        throws_ok { $bad->set_SDFSDFSDF } qr/No field 'SDFSDFSDF'/, 'bad cannot set a field it does not have';
        ok (! $object_store->is_dirty( $bad ), 'bad is *still* not dirty here after trying to set nonexistant field' );
        throws_ok { $bad->get_SDFSDFSDF } qr/No field 'SDFSDFSDF'/, 'bad cannot set a field it does not have';
        ok (! $object_store->is_dirty( $bad ), 'bad is *still* not dirty here after trying to get nonexistant field' );


        my $bad_val_array = $bad->get_some_val_array;
        throws_ok { $bad->set_some_ref_array( $bad->get_some_ref_hash ) } qr/incorrect type '\*HASH<256>_\*' for '\*ARRAY_\*'/, 'cannot set a ref hash to a ref array';
        throws_ok { $bad->set_some_ref_hash( $bad->get_some_ref_array ) } qr/incorrect type '\*ARRAY_\*' for '\*HASH<256>_\*'/, 'cannot set a ref hash to a ref array';
        throws_ok { $bad->set_some_val_hash( $bad_val_array ) } qr/incorrect type '\*ARRAY_TEXT' for '\*HASH<256>_TEXT'/, 'cannot set a val array to a val array';
        throws_ok { $bad->PLUGH } qr/unknown function 'SQLite::SomeThing::PLUGH'/, 'object autoload does not know PLUGH';
        throws_ok { $bad->set_some_val_hash( "SPOOKEY" ) } qr/incorrect type 'scalar value' for '\*HASH<256>_TEXT'/, 'cannot set a val array to a val array';

        throws_ok { $bad->set_some_val_hash( $bad->get_some_ref_hash ) } qr/incorrect type '\*HASH<256>_\*' for '\*HASH<256>_TEXT'/, 'cannot set a val array to a val array';

        my $root_val_array = $root_refs->{val_array};

        $bad_val_array->[100] = "ONEHUND";
        $object_store->save;

        ok (! $object_store->is_dirty( $bad_val_array ), 'bad val array just saved, is not dirty' );
        $bad_val_array->[100] = "ONEHUND";
        ok (! $object_store->is_dirty( $bad_val_array ), 'bad val array still not dirty after setting index to value it already had' );
        is (@{$bad_val_array}, 101, '101 entries for bad val array' );

        ok (! exists $bad_val_array->[99], 'nothing at index 99 inp bad val array' );

        ok (! $object_store->is_dirty( $bad_val_array ), 'bad val array still not dirty after checking exists' );
        delete $bad_val_array->[98];
        ok (! $object_store->is_dirty( $bad_val_array ), 'bad val array still not dirty after deleting something that was already undefined' );
        is (@{$bad_val_array}, 101, 'still 101 entries for bad val array' );

        delete $bad_val_array->[100];
        is (@{$bad_val_array}, 0, 'bad val array now empty after deleting only entry' );
        ok ($object_store->is_dirty( $bad_val_array ), 'bad val array now dirty after deleting only entry' );
        $object_store->save;
        ok (!$object_store->is_dirty( $bad_val_array ), 'bad val array now not dirty after save' );
        @{$bad_val_array} = ();
        ok (!$object_store->is_dirty( $bad_val_array ), 'bad val array now not dirty after clearing it when it was empty' );

        $bad_val_array->[100] = 'ONEHUND'; #setting this back
        is (@{$bad_val_array}, 101, 'back to 101 entries for bad val array' );
        $object_store->save;
        ok (!$object_store->is_dirty( $bad_val_array ), 'bad val array now not dirty after save' );
        @{$bad_val_array} = ();
        is (@{$bad_val_array}, 0, 'back to no entries for bad val array' );
        ok ($object_store->is_dirty( $bad_val_array ), 'bad val array now dirty after clearing while empty' );
        # do not save, so ONEHUND is still there
    }

    {
        # reopen and make sure its the same stuff
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        $object_store->open;

        throws_ok
            { $object_store->fetch_string_path( "/ref_hash/ref_array/2/in^alid" ) }
            qr/Invalid Column Name/, 'throws when attempting a weird field name but when not in cache';

        $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array" );

        my $bad = $object_store->fetch_string_path( "/ref_hash/ref_array/3" );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array/100" ), "ONEHUND", 'fetched path containing indexes array value' );

        my $bad_val_hash_obj = $bad->get_some_val_array;
        my $bad_val_array = $bad_val_hash_obj;
        is (@$bad_val_array, 101, '101 entries for bad val array' );
        my $undef = shift @$bad_val_array;
        is ($undef, undef, 'shifted undef value');


        is (@$bad_val_array, 100, '100 entries for bad val array after shift' );
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array/99" ), "ONEHUND", 'fetched path containing indexes array value shifted down one' );
        is ($#$bad_val_array, 99, 'last index 99 for bad val array');
        is ($bad_val_array->[$#$bad_val_array], 'ONEHUND', 'at last');
        is (pop @$bad_val_array, 'ONEHUND', 'ONEHUND POPPED OFF');
        is (@$bad_val_array, 99, 'bad val array now down to 99 size' );
        is ($bad_val_array->[$#$bad_val_array], undef, 'last bad val array entry undef now');

        unshift @$bad_val_array, 'BEGINNING';
        is_deeply( $object_store->fetch_string_path( "/ref_hash/ref_array/3/some_val_array/0" ), "BEGINNING", 'NOW UNSHIFTED bad val array value' );
        is (@$bad_val_array, 100, 'bad val array now at 100 size after unshift' );

        $object_store->save;
        ok (!$object_store->is_dirty( $bad_val_hash_obj ), 'bad val array now not dirty after save' );
        no warnings 'syntax';
        unshift @$bad_val_array;
        ok (!$object_store->is_dirty( $bad_val_hash_obj ), 'bad val array now not dirty after useless unshift' );

        my $val_array = $object_store->fetch_string_path( "/ref_hash/val_array" );
        is_deeply ($val_array, [1,2,3], 'val array from fetch path' );
        my (@gone) = splice @$val_array, 1, 1, 'two';
        is_deeply( \@gone, [2], 'spliced away the 2' );
        is_deeply ($val_array, [1,'two',3], 'val array from fetch path' );

        $#$val_array = 100;
        is (@$val_array, 101, 'val array is now 101 long' );
    }

    {
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        $object_store->open;
        my ($sql) = $object_store->query_line( "SELECT sql FROM sqlite_schema WHERE name='SomeThing_SQLite'" );

        is ($sql,'CREATE TABLE SomeThing_SQLite (id BIGINT UNSIGNED PRIMARY KEY,brother BIGINT UNSIGNED,lolov BIGINT UNSIGNED,name TEXT,sister BIGINT UNSIGNED,sisters BIGINT UNSIGNED,sisters_hash BIGINT UNSIGNED,some_ref_array BIGINT UNSIGNED,some_ref_hash BIGINT UNSIGNED,some_val_array BIGINT UNSIGNED,some_val_hash BIGINT UNSIGNED,something BIGINT UNSIGNED,tagline TEXT)', 'initial something table' );
    }
    {

        $SQLite::SomeThing::cols{newname} = 'TEXT';
        delete $SQLite::SomeThing::cols{brother};
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        make_all_tables( $object_store );

        $object_store->open;
        my ($sql) = $object_store->query_line( "SELECT sql FROM sqlite_schema WHERE name='SomeThing_SQLite'" );
        like ($sql, qr/CREATE TABLE SomeThing_SQLite \(id BIGINT UNSIGNED PRIMARY KEY,brother_DELETED BIGINT UNSIGNED,lolov BIGINT UNSIGNED,name TEXT,sister BIGINT UNSIGNED,sisters BIGINT UNSIGNED,sisters_hash BIGINT UNSIGNED,some_ref_array BIGINT UNSIGNED,some_ref_hash BIGINT UNSIGNED,some_val_array BIGINT UNSIGNED,some_val_hash BIGINT UNSIGNED,something BIGINT UNSIGNED,tagline TEXT, newname TEXT\)/i, 'something table after columns changed' );

        ok (! $object_store->dirty( "ima string" ), 'strings cannot be made dirty' );
        ok (! $object_store->is_dirty( "not a thing here" ), 'strings are never dirty' );
    }

};

subtest 'paths test' => sub {

    my $dir = $factory->new_db_name;

    {
        my $object_store = Yote::SQLObjectStore->new( 'SQLite',
            BASE_DIRECTORY => $dir,
            );
        make_all_tables( $object_store );
        $object_store->open;

        is ( $object_store->fetch_string_path( '/val_hash/word' ), undef, 'nothing yet in val_hash' );

        is ( ref $object_store->ensure_path( [ 'val_hash' ] ), 'HASH', 'starts with hash' );

        throws_ok
            { $object_store->ensure_path( 'val_hash',
                                          [],
                                          [ 'word', 'VALUE' ],
                  ) }
            qr/invalid path. missing key/,
            'ensure_path throws when a key is missing';

        throws_ok
            { $object_store->ensure_path( 'val_hash',
                                          [ 'word', 'VALUE' ],
                                          'beep'  ) }
            qr/invalid path. non-reference encountered before the end/,
            'ensure_path throws when there is a non-reference in the middle of the path';

        is ($object_store->fetch_string_path( '/val_hash/word' ), undef, 'check that bird is not yetthe word' );

        is ($object_store->ensure_path( 'val_hash',
                                        [ 'word', 'bird' ]
            ), 'bird', 'ensure bird is the word' );

        is ($object_store->fetch_string_path( '/val_hash/word' ), 'bird', 'check that bird is the word' );

        is ($object_store->fetch_string_path( '/ref_hash/plugh' ), undef, 'ref hash has no plugh' );

        throws_ok
            { $object_store->ensure_path( qw( ref_hash plugh )) }
            qr/requires an object type be given/, 'plugh type not defined';

        throws_ok
            { $object_store->ensure_path( 'ref_hash',
                                          [ 'plugh', 'SQLite::NotInINC' ] );
            }
            qr/invalid path.*not found in/,
            'plugh cant be set to something not found in @INC';

        throws_ok
            { $object_store->ensure_path( 'ref_hash',
                                          [ 'plugh', 'SQLite::NotAThing' ] );
            }
            qr/.*is not a Yote::SQLObjectStore::BaseObj/,
            'plugh cant be set to something not a yote obj';


        my $something = $object_store->ensure_path( 'ref_hash',
                                                    [ 'plugh', 'SQLite::SomeThing' ] );
        ok ($something, 'ensure path returns something' );

        $something = $object_store->ensure_path( '/ref_hash/plugh|SQLite::SomeThing' );
        ok ($something, 'ensure path returns something' );

        throws_ok
        { $something = $object_store->ensure_path( '/ref_hash/plugh|SQLite::SomeThingElse' );
        }
        qr/path exists but got type 'SQLite::SomeThingElse' and expected type 'SQLite::SomeThing'/,
            'ensure path contains an object whos expected class differs';

        throws_ok
        { $object_store->ensure_path( '/val_hash/word|notBird' ); }
        qr/path ends in different value/,
            'ensure path contains a value that differs from the expected value';

        is ($object_store->ensure_path( '/val_hash/word' ), 'bird', 'ensure returns last value as long as its present');
        is ($object_store->ensure_path( '/val_hash/word|bird' ), 'bird', 'ensure returns last value if last value exists');

        my $val_array = $object_store->ensure_path( '/ref_hash/array|*ARRAY_TEXT' );
        ok (ref $val_array eq 'ARRAY', 'created value array' );

        throws_ok
        { $object_store->ensure_path( '/ref_hash/array/notanindex|nope' ); }
        qr/array access expects index/,
            'should throw when a non numeric index is used in array';

        $val_array->[0] = "THE FIRST";
        is ($object_store->fetch_string_path( '/ref_hash/array/0' ), 'THE FIRST', 'fetched value from array' );

        throws_ok
        { $object_store->ensure_path( '/ref_hash/wildcard|*' ); }
        qr/invalid path. wildcard slot requires an object type be given/,
            'should throw when given a wildcard type to instantiate';
        

        my $tiny_hash = $object_store->ensure_path( '/ref_hash/tinyhash|*HASH<3>_TEXT' );

        is (ref $tiny_hash, 'HASH', 'made a tiny hash' );
        
        is ($object_store->ensure_path( '/ref_hash/tinyhash/foo|BAR' ), 'BAR', 'made a tiny entry' );
        $object_store->save;

        throws_ok
        { $object_store->ensure_path( '/ref_hash/tinyhash/fooLong|NOWAY' ); }
        qr/key is too large for hash/,
            'should throw when key length exceeds max';

        throws_ok
        { $object_store->ensure_path( '/ref_hash/tinyhash2|*HASH<3>_TEXT/fooLonger|STILLNOWAY' ); }
        qr/key is too large/,
            'should throw when key length exceeds max';


        $object_store->ensure_path( '/ref_hash/someobjagain|*SQLite::SomeThing' );
        

        $object_store->ensure_path( '/ref_hash/somethingHash|*HASH<256>_*SQLite::SomeThing' );

        my $thing = $object_store->ensure_path( '/ref_hash/somethingHash/afirst|*SQLite::SomeThing' );
        is (ref $thing, 'SQLite::SomeThing', 'made something obj' );

        throws_ok
        { $something = $object_store->ensure_path( '/ref_hash/somethingHash/nothere|*SQLite::SomeThingElse' );
        }
        qr/invalid path. incorrect type '\*SQLite::SomeThingElse', expected '\*SQLite::SomeThing'/,
            'type checked hash throws when wrong type added to it';
        

        $object_store->ensure_paths( qw( 
                                         /ref_hash/tinyhash/fuu|BUR
                                         /ref_hash/tinyhash/boo|FAR
                                     ) );
        is ( $object_store->fetch_string_path( '/ref_hash/tinyhash/boo' ), 'FAR', 'ensure paths worked 1' );
        is ( $object_store->fetch_string_path( '/ref_hash/tinyhash/fuu' ), 'BUR', 'ensure paths worked 2' );

        eval {
$object_store->ensure_paths( qw( 
                                         /ref_hash/tinyhash/fu1|GLACK
                                         /ref_hash/tinyhash/bo1|NOOOO
                                         /ref_hash/tinyhash/noway|FAR/gah
                                     ) );
        };

        throws_ok
        { $something = $object_store->ensure_paths( qw( 
                                         /ref_hash/tinyhash/fu1|GLACK
                                         /ref_hash/tinyhash/bo1|NOOOO
                                         /ref_hash/tinyhash/noway|FAR/gah
                                     ) )
        }
        qr/invalid path. non-reference encountered before the end/,
            'ensure_paths fail for transaction check';
        
        is ( $object_store->fetch_string_path( '/ref_hash/tinyhash/fu1' ), undef, 'bath paths did nothing 1' );
        is ( $object_store->fetch_string_path( '/ref_hash/tinyhash/bo1' ), undef, 'bath paths did nothing 2' );
        
    }
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
} #new_db_name

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
