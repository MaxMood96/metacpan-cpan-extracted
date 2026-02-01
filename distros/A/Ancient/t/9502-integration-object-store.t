#!/usr/bin/env perl
# Integration test: object + lru + const for cached object storage
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use object;
use lru;
use const;

object::define('Product', qw(id name price));
object::define('Customer', qw(id email));

subtest 'cache products' => sub {
    my $cache = lru::new(5);
    
    my $p1 = new Product 'SKU001', 'Widget', 19.99;
    my $p2 = new Product 'SKU002', 'Gadget', 29.99;
    my $p3 = new Product 'SKU003', 'Doodad', 9.99;
    
    $cache->set($p1->id, $p1);
    $cache->set($p2->id, $p2);
    $cache->set($p3->id, $p3);
    
    is($cache->size, 3, 'cache has 3 products');
    
    my $retrieved = $cache->get('SKU002');
    is($retrieved->name, 'Gadget', 'retrieved correct product');
    is($retrieved->price, 29.99, 'product price preserved');
};

subtest 'freeze cached objects' => sub {
    my $cache = lru::new(3);
    
    my $customer = new Customer 'C001', 'alice@example.com';
    $cache->set($customer->id, $customer);
    
    my $frozen_customer = const::c({ id => $customer->id, email => $customer->email });
    
    ok(const::is_readonly(%{$frozen_customer}), 'customer data frozen');
    is($frozen_customer->{id}, 'C001', 'frozen id correct');
    is($frozen_customer->{email}, 'alice@example.com', 'frozen email correct');
};

subtest 'LRU eviction with objects' => sub {
    my $cache = lru::new(2);
    
    my $p1 = new Product 'A', 'First', 10;
    my $p2 = new Product 'B', 'Second', 20;
    my $p3 = new Product 'C', 'Third', 30;
    
    $cache->set('A', $p1);
    $cache->set('B', $p2);
    $cache->get('A');  # Promote A
    $cache->set('C', $p3);  # Should evict B
    
    ok($cache->exists('A'), 'recently accessed A exists');
    ok(!$cache->exists('B'), 'B was evicted');
    ok($cache->exists('C'), 'newly added C exists');
};

subtest 'peek preserves LRU order' => sub {
    my $cache = lru::new(2);
    
    my $c1 = new Customer 'X', 'x@example.com';
    my $c2 = new Customer 'Y', 'y@example.com';
    
    $cache->set('X', $c1);
    $cache->set('Y', $c2);
    
    my $peeked = $cache->peek('X');
    is($peeked->email, 'x@example.com', 'peek returns correct object');
    
    my $c3 = new Customer 'Z', 'z@example.com';
    $cache->set('Z', $c3);
    
    ok(!$cache->exists('X'), 'X evicted after peek (not promoted)');
    ok($cache->exists('Y'), 'Y still exists');
};

done_testing();
