use v5.40;
use Test2::V0;
use lib '../lib';
use Acme::Bitfield;
#
subtest 'Basic Operations' => sub {
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
#
done_testing;
