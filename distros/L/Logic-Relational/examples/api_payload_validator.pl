#!/usr/bin/env perl

use v5.38;
use lib ( '../lib', 'lib' );
use Logic::Relational::Syntax;

# ==============================================================================
# API PAYLOAD VALIDATOR & STRUCTURAL DESTRUCTURING
# Demonstrates pattern matching, destructuring, and validation over complex
# nested Perl data structures (JSON API Payloads) using Relational Logic.
# ==============================================================================

logic Validator {
    # Helper: Check if customer tier is VIP (gold or platinum)
    rule is_vip_tier($tier) { $tier := 'gold'; }
    rule is_vip_tier($tier) { $tier := 'platinum'; }

    # Rule 1: VIP Fast-Track Orders
    # Matches VIP customers with authorized payment status
    rule vip_fast_track($order_id, $cust_id, $tier) {
        fresh my ($order, $r1, $r2, $r3);
        raw_order($order);
        $order := {
            id       => $order_id,
            customer => { id => $cust_id, tier => $tier, _ => rest($r1) },
            payment  => { status => 'authorized', _ => rest($r2) },
            _        => rest($r3),
        };
        is_vip_tier($tier);
    }

    # Rule 2a: Flagged Risk - High Value Item ($1000+) with Unverified Crypto Payment
    rule flagged_risk($order_id, $reason) {
        fresh my ($order, $items, $item, $price, $r1, $r2, $r3);
        raw_order($order);
        $order := {
            id      => $order_id,
            payment => { method => 'crypto', status => 'unverified', _ => rest($r1) },
            items   => $items,
            _       => rest($r2),
        };
        member($item, $items);
        $item := { price => $price, _ => rest($r3) };
        $price #>= 1000;
        $reason := 'Unverified crypto payment on high-value item ($1000+)';
    }

    # Rule 2b: Flagged Risk - Bulk Order (5+ units) from non-VIP Account
    rule flagged_risk($order_id, $reason) {
        fresh my ($order, $tier, $items, $item, $qty, $r1, $r2, $r3);
        raw_order($order);
        $order := {
            id       => $order_id,
            customer => { tier => $tier, _ => rest($r1) },
            items    => $items,
            _        => rest($r2),
        };
        $tier !:= 'gold';
        $tier !:= 'platinum';
        member($item, $items);
        $item := { qty => $qty, _ => rest($r3) };
        $qty #>= 5;
        $reason := 'Bulk order (5+ units of item) from non-VIP account';
    }

    # Rule 3: Standard Compliant Orders
    rule standard_order($order_id, $cust_id) {
        fresh my ($order, $tier, $status, $r1, $r2, $r3);
        raw_order($order);
        $order := {
            id       => $order_id,
            customer => { id => $cust_id, tier => $tier, _ => rest($r1) },
            payment  => { status => $status, _ => rest($r2) },
            _        => rest($r3),
        };
        $status := 'authorized';
        $tier !:= 'gold';
        $tier !:= 'platinum';
    }
}

# 1. Perl Data Input: Raw API JSON Order Payloads
my @api_orders = (
    {
        id       => 'ORD-1001',
        customer => { id     => 'CUST-88', tier => 'gold', country => 'UK' },
        payment  => { method => 'credit_card', status => 'authorized' },
        items    => [
            {
                id       => 'ITEM-A',
                category => 'electronics',
                price    => 450,
                qty      => 1
            },
            {
                id       => 'ITEM-B',
                category => 'accessories',
                price    => 25,
                qty      => 2
            },
        ],
    },
    {
        id       => 'ORD-1002',
        customer => { id => 'CUST-12',    tier => 'standard', country => 'FR' },
        payment  => { method => 'paypal', status => 'authorized' },
        items    =>
          [ { id => 'ITEM-C', category => 'books', price => 15, qty => 3 }, ],
    },
    {
        id       => 'ORD-1003',
        customer => { id => 'CUST-99', tier => 'platinum', country => 'US' },
        payment  => { method => 'credit_card', status => 'authorized' },
        items    => [
            { id => 'ITEM-D', category => 'laptops', price => 1200, qty => 1 },
        ],
    },
    {
        id       => 'ORD-1004',
        customer => { id => 'CUST-55',    tier => 'standard', country => 'DE' },
        payment  => { method => 'crypto', status => 'unverified' },
        items    => [
            {
                id       => 'ITEM-E',
                category => 'crypto_hardware',
                price    => 1500,
                qty      => 2
            },
        ],
    },
    {
        id       => 'ORD-1005',
        customer => { id => 'CUST-44', tier => 'standard', country => 'US' },
        payment  => { method => 'credit_card', status => 'authorized' },
        items    =>
          [ { id => 'ITEM-F', category => 'phones', price => 800, qty => 6 }, ],
    },
);

# 2. Ingest API Payloads into Relational Engine
for my $o (@api_orders) {
    $Validator::PROGRAM->fact( raw_order => $o );
}

say "=" x 60;
say "   API PAYLOAD VALIDATOR & STRUCTURAL DESTRUCTURING";
say "=" x 60;

# Demo 1: VIP Fast-Track Processing
say "\n--- 1. VIP Fast-Track Orders ---";
query Validator::vip_fast_track( fresh my $oid1, fresh my $cid1,
    fresh my $tier1 )->my $q1;
while ( my $sol = $q1->next ) {
    say sprintf( "  [FAST-TRACK] Order %s (Customer: %s, Tier: %s)",
        $sol->value($oid1), $sol->value($cid1), $sol->value($tier1) );
}

# Demo 2: Flagged Fraud & Risk Orders
say "\n--- 2. Flagged Risk Orders ---";
query Validator::flagged_risk( fresh my $oid2, fresh my $reason2 )->my $q2;
while ( my $sol = $q2->next ) {
    say sprintf( "  [FLAGGED RISK] Order %s -> Reason: %s",
        $sol->value($oid2), $sol->value($reason2) );
}

# Demo 3: Standard Compliant Orders
say "\n--- 3. Standard Compliant Orders ---";
query Validator::standard_order( fresh my $oid3, fresh my $cid3 )->my $q3;
while ( my $sol = $q3->next ) {
    say sprintf( "  [STANDARD ORDER] Order %s (Customer: %s)",
        $sol->value($oid3), $sol->value($cid3) );
}
say "";

