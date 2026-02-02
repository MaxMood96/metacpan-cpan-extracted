use v5.40;
use Test2::V0;
use lib '../lib';
use Acme::Bitfield;
#
subtest Basics => sub {
    subtest Operations => sub {
        my $bf = Acme::Bitfield->new( size => 10 );
        is $bf->size,  10, 'Correct size';
        is $bf->count, 0,  'Initially empty';
        $bf->set(0);
        $bf->set(9);
        ok $bf->get(0),  'Bit 0 set';
        ok $bf->get(9),  'Bit 9 set';
        ok !$bf->get(5), 'Bit 5 not set';
        is $bf->count, 2, 'Count is 2';
        $bf->clear(0);
        ok !$bf->get(0), 'Bit 0 cleared';
        is $bf->count, 1, 'Count is 1';
    };
    subtest 'Bit Ordering (BEP 03)' => sub {
        my $bf = Acme::Bitfield->new( size => 8 );
        $bf->set(0);    # Should be 0x80 in the first byte
        is unpack( 'H*', $bf->data ), '80', 'Index 0 is high bit of first byte';
        $bf->clear(0);
        $bf->set(7);    # Should be 0x01
        is unpack( 'H*', $bf->data ), '01', 'Index 7 is low bit of first byte';
    };
    subtest 'Fill and Find Missing' => sub {
        my $bf = Acme::Bitfield->new( size => 5 );
        $bf->fill();
        is $bf->count,          5,     'All 5 bits set';
        is $bf->find_missing(), undef, 'No missing bits';
        $bf->clear(2);
        is $bf->find_missing(), 2, 'Found missing bit at index 2';
    };
};
subtest Inverse => sub {
    subtest 'Inverse Method' => sub {
        my $bf = Acme::Bitfield->new( size => 10 );
        $bf->set(0);
        $bf->set(5);
        $bf->set(9);
        is $bf->count, 3, 'Initial count is 3';
        my $inv = $bf->inverse();
        isa_ok $inv, ['Acme::Bitfield'], 'inverse() returns a new Acme::Bitfield';
        is $inv->size,  10, 'Inverted bitfield has same size';
        is $inv->count, 7,  'Inverted bitfield has count 7 (10 - 3)';
        ok !$inv->get(0), 'Bit 0 is now 0';
        ok $inv->get(1),  'Bit 1 is now 1';
        ok !$inv->get(5), 'Bit 5 is now 0';
        ok $inv->get(8),  'Bit 8 is now 1';
        ok !$inv->get(9), 'Bit 9 is now 0';
    };
    subtest 'Inverse of Empty' => sub {
        my $bf  = Acme::Bitfield->new( size => 8 );
        my $inv = $bf->inverse();
        is $inv->count,                8,    'Inverse of empty is full';
        is unpack( 'H*', $inv->data ), 'ff', 'Data is 0xFF';
    };
    subtest 'Inverse of Full' => sub {
        my $bf = Acme::Bitfield->new( size => 8 );
        $bf->fill();
        my $inv = $bf->inverse();
        is $inv->count,                0,    'Inverse of full is empty';
        is unpack( 'H*', $inv->data ), '00', 'Data is 0x00';
    };
    subtest 'Excess Bits remain zero' => sub {
        my $bf  = Acme::Bitfield->new( size => 10 );
        my $inv = $bf->inverse();

        # 10 bits means 2 bytes.
        # Inverted should have 10 bits set to 1.
        # Bits 10-15 should remain 0.
        # Byte 1: 11111111 (0xFF)
        # Byte 2: 11000000 (0xC0 in BEP 03 order)
        is unpack( 'H*', $inv->data ), 'ffc0', 'Excess bits are zeroed out in inverted bitfield';
    };
};
subtest 'Bitwise Operations' => sub {
    my $bf1 = Acme::Bitfield->new( size => 10 );
    my $bf2 = Acme::Bitfield->new( size => 10 );
    $bf1->set($_) for ( 0, 1, 2 );
    $bf2->set($_) for ( 2, 3, 4 );
    subtest 'Union' => sub {
        my $union = $bf1->union($bf2);
        is( $union->count, 5, 'Union count is 5' );
        ok( $union->get($_), "Bit $_ set in union" ) for ( 0, 1, 2, 3, 4 );
    };
    subtest 'Intersection' => sub {
        my $inter = $bf1->intersection($bf2);
        is( $inter->count, 1, 'Intersection count is 1' );
        ok( $inter->get(2),  'Bit 2 set in intersection' );
        ok( !$inter->get(0), 'Bit 0 NOT set in intersection' );
    };
    subtest 'Difference' => sub {
        my $diff = $bf1->difference($bf2);
        is( $diff->count, 2, 'Difference count is 2' );
        ok( $diff->get(0),  'Bit 0 set in difference' );
        ok( $diff->get(1),  'Bit 1 set in difference' );
        ok( !$diff->get(2), 'Bit 2 NOT set in difference' );
    };
};
subtest 'Status Checks' => sub {
    my $bf = Acme::Bitfield->new( size => 8 );
    ok( $bf->is_empty, 'Initially empty' );
    ok( !$bf->is_full, 'Not initially full' );
    $bf->fill;
    ok( $bf->is_full,   'Full after fill' );
    ok( !$bf->is_empty, 'Not empty after fill' );
    $bf->clear(0);
    ok( !$bf->is_full, 'Not full after clearing one bit' );
};
subtest 'Edge Cases' => sub {
    subtest 'Zero Size' => sub {
        my $bf = Acme::Bitfield->new( size => 0 );
        is( $bf->data,  '', 'Data is empty string' );
        is( $bf->count, 0,  'Count is 0' );
        ok( $bf->is_full, 'Zero size is technically full' );
    };
    subtest 'Mismatched Data Length' => sub {
        my $bf = Acme::Bitfield->new( size => 8 );
        $bf->set_data("\xFF\xFF\xFF");
        is( length( $bf->data ), 1, 'Data truncated to 1 byte' );
        is( $bf->count,          8, 'Count is 8' );
        $bf->set_data("");
        is( length( $bf->data ), 1, 'Data padded to 1 byte' );
        is( ord( $bf->data ),    0, 'Padded with zeros' );
    };
    subtest 'Last Byte Masking' => sub {
        my $bf = Acme::Bitfield->new( size => 10 );

        # 10 bits = 2 bytes. Last byte should only have 2 bits.
        $bf->set_data("\xFF\xFF");
        is( ord( substr( $bf->data, 1, 1 ) ), 0xC0, 'Last byte masked to 0xC0' );
        is( $bf->count,                       10,   'Count is 10' );
    };
};
#
done_testing;
