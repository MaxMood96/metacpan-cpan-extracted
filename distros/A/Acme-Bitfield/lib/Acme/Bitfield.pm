use v5.42;
use feature 'class';
no warnings 'experimental::class';
#
class Acme::Bitfield v1.0.0 {
    field $size : reader : param;
    field $data : reader : writer = "\0" x int( ( $size + 7 ) / 8 );

    # Internal helper to map BitTorrent bit index to vec index
    # BT: bit 0 is 0x80, bit 7 is 0x01
    # vec: bit 0 is 0x01, bit 7 is 0x80
    sub _map ($index) { ( $index & ~7 ) | ( 7 - ( $index & 7 ) ) }

    method get ($index) {
        return 0 if $index < 0 || $index >= $size;
        vec $data, _map($index), 1;
    }

    method set ($index) {
        return if $index < 0 || $index >= $size;
        vec( $data, _map($index), 1 ) = 1;
    }

    method clear ($index) {
        return if $index < 0 || $index >= $size;
        vec( $data, _map($index), 1 ) = 0;
    }

    method count () {
        my $c = 0;
        for my $i ( 0 .. $size ) {
            $c++ if $self->get($i);
        }
        $c;
    }

    method fill () {
        $data = "\xFF" x length($data);

        # Zero out excess bits at the end
        for ( my $i = $size; $i < length($data) * 8; $i++ ) {
            vec( $data, _map($i), 1 ) = 0;
        }
    }

    method find_missing () {
        for ( my $i = 0; $i < $size; $i++ ) {
            return $i if !$self->get($i);
        }
        ();
    }
};
#
1;
