#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->await($schema->deploy({ add_drop_table => 1 }));

my $sku_counter = 100;
sub unique_sku {
    return 'SKU-' . $sku_counter++;
}

subtest 'Basic copy functionality' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Original Product',
                            sku         => unique_sku(),
                            price       => 10,
                            description => 'Original description',
                            active      => 1,
                          })->get;

    my $copy = $original->copy({ sku => unique_sku() })->get;

    ok(defined $copy, 'Copy was created');
    isa_ok($copy, 'DBIx::Class::Async::Row', 'Copy is correct type');
    isnt($copy->id, $original->id, 'Copy has different ID (auto-increment)');
    is($copy->name, $original->name, 'Name was copied');
    is($copy->price, $original->price, 'Price was copied');
    is($copy->description, $original->description, 'Description was copied');
    is($copy->active, $original->active, 'Active flag was copied');
    isnt($copy->sku, $original->sku, 'SKU is different (unique constraint)');
};

subtest 'Copy with replacement data' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Gadget',
                            sku         => unique_sku(),
                            price       => 49.99,
                            description => 'Original gadget',
                            active      => 1,
                          })->get;

    my $copy = $original->copy({
            name        => 'Gadget Pro',
            sku         => unique_sku(),
            price       => 79.99,
            description => 'Enhanced gadget',
    })->get;

    is($copy->name, 'Gadget Pro', 'Name was replaced');
    is($copy->price, 79.99, 'Price was replaced');
    is($copy->description, 'Enhanced gadget', 'Description was replaced');
    isnt($copy->id, $original->id, 'Copy has different ID');
    is($original->name, 'Gadget', 'Original name unchanged');
    is($original->price, 49.99, 'Original price unchanged');
    is($copy->active, 1, 'Active flag was copied');
};

subtest 'Copy with partial replacement data' => sub {

    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Doohickey',
                            sku         => unique_sku(),
                            price       => 15.50,
                            description => 'A small doohickey',
                            active      => 1,
                          })->get;

    my $copy = $original->copy({
        name => 'Doohickey XL',
        sku  => unique_sku(),
    })->get;

    is($copy->name, 'Doohickey XL', 'Name was replaced');
    is($copy->price, 15.50, 'Price was copied from original');
    is($copy->description, 'A small doohickey', 'Description was copied');
    isnt($copy->id, $original->id, 'Copy has different ID');
};

subtest 'Auto-increment column handling' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name  => 'Test Product',
                            sku   => unique_sku(),
                            price => 9.99,
                          })->get;

    my $original_id = $original->id;
    my $copy = $original->copy({ sku => unique_sku() })->get;

    ok(defined $copy->id, 'Copy has an ID');
    isnt($copy->id, $original_id, 'Copy ID differs from original');
    ok($copy->id > 0, 'Copy has valid positive ID');
};

subtest 'Copy with null values' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Minimal Product',
                            sku         => unique_sku(),
                            price       => undef,
                            description => undef,
                          })->get;
    my $copy = $original->copy({ sku => unique_sku() })->get;

    is($copy->name, 'Minimal Product', 'Name copied');
    ok(!defined $copy->price, 'Null price preserved');
    ok(!defined $copy->description, 'Null description preserved');
    isnt($copy->id, $original->id, 'Different ID');
};

subtest 'Multiple copies from same original' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Template Product',
                            sku         => unique_sku(),
                            price       => 99.99,
                            description => 'Template',
                            active      => 1,
                          })->get;

    # Create multiple copies
    my $copy1 = $original->copy({ name => 'Copy 1', sku => unique_sku() })->get;
    my $copy2 = $original->copy({ name => 'Copy 2', sku => unique_sku() })->get;
    my $copy3 = $original->copy({ name => 'Copy 3', sku => unique_sku() })->get;

    # Verify all copies are distinct
    isnt($copy1->id, $original->id, 'Copy 1 has different ID');
    isnt($copy2->id, $original->id, 'Copy 2 has different ID');
    isnt($copy3->id, $original->id, 'Copy 3 has different ID');

    isnt($copy1->id, $copy2->id, 'Copy 1 and 2 have different IDs');
    isnt($copy1->id, $copy3->id, 'Copy 1 and 3 have different IDs');
    isnt($copy2->id, $copy3->id, 'Copy 2 and 3 have different IDs');

    # Verify names
    is($copy1->name, 'Copy 1', 'Copy 1 name correct');
    is($copy2->name, 'Copy 2', 'Copy 2 name correct');
    is($copy3->name, 'Copy 3', 'Copy 3 name correct');

    # All should have same price as original
    is($copy1->price, $original->price, 'Copy 1 price matches');
    is($copy2->price, $original->price, 'Copy 2 price matches');
    is($copy3->price, $original->price, 'Copy 3 price matches');

    # All should have different SKUs
    isnt($copy1->sku, $original->sku, 'Copy 1 SKU different');
    isnt($copy2->sku, $original->sku, 'Copy 2 SKU different');
    isnt($copy3->sku, $original->sku, 'Copy 3 SKU different');
};

subtest 'Copy returns Future' => sub {
    my $original_future = $schema->resultset('Product')
                                 ->create({
                                    name => 'Future Test Product',
                                    sku  => unique_sku(),
                                    price => 19.99,
                                 });

    my $copy_future = $original_future->then(sub {
        my ($original) = @_;
        return $original->copy({ sku => unique_sku() });
    });

    isa_ok($copy_future, 'Future', 'copy returns a Future');

    my $copy = eval { $copy_future->get };
    if ($@) {
        fail("Future resolution failed: $@");
    } else {
        ok(defined $copy, 'Future resolved to a copy');
        isa_ok($copy, 'DBIx::Class::Async::Row', 'Copy is correct type');
    }
};

subtest 'Copy in_storage flag' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name => 'Storage Test',
                            sku  => unique_sku(),
                            price => 25.00,
                          })->get;

    my $copy = $original->copy({ sku => unique_sku() })->get;

    # Copy should be marked as in_storage since it was inserted
    ok($copy->in_storage, 'Copy is marked as in_storage');

    # Should be able to update it
    $copy->set_column('name', 'Updated Name');
    my $updated = $copy->update->get;
    is($updated->name, 'Updated Name', 'Copy can be updated');
};

subtest 'Copy with all columns replaced' => sub {
    my $original = $schema->resultset('Product')
                          ->create({
                            name        => 'Original',
                            sku         => unique_sku(),
                            price       => 10.00,
                            description => 'Original desc',
                            active      => 1,
                          })->get;

    # Replace all non-PK columns
    my $copy = $original->copy({
        name        => 'Completely New',
        sku         => unique_sku(),
        price       => 99.99,
        description => 'New description',
        active      => 0,
    })->get;

    is($copy->name, 'Completely New', 'Name replaced');
    is($copy->price, 99.99, 'Price replaced');
    is($copy->description, 'New description', 'Description replaced');
    is($copy->active, 0, 'Active flag replaced');
    isnt($copy->id, $original->id, 'ID still different');
};

$schema->disconnect;

done_testing;
