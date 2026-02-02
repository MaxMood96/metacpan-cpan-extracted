use v5.42;
use feature 'class';
no warnings 'experimental::class';
#
class Acme::Bitfield v1.1.0 {
    field $size : reader : param;
    field $data : reader : param = "\0" x int( ( $size + 7 ) / 8 );
    ADJUST {
        $self->_clean;
    }

    method set_data ($val) {
        $data = $val;
        $self->_clean;    # We can't use the :writer because we must call this
    }

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
        return unpack( '%32b*', $data );
    }

    method is_full () {
        return $self->count == $size;
    }

    method is_empty () {
        return $data =~ tr/\0//c ? 0 : 1;
    }

    method union ($other) {
        my $new = __CLASS__->new( size => $size );
        $new->set_data( $data|.$other->data );
        return $new;
    }

    method intersection ($other) {
        my $new = __CLASS__->new( size => $size );
        $new->set_data( $data&.$other->data );
        return $new;
    }

    method difference ($other) {

        # Bits set in self but NOT in other
        my $new = __CLASS__->new( size => $size );
        $new->set_data( $data&.~.$other->data );
        return $new;
    }

    method _clean () {

        # internal method to automatically handle data truncation, padding, and bit masking
        my $expected_len = int( ( $size + 7 ) / 8 );
        if ( length($data) > $expected_len ) {
            substr( $data, $expected_len ) = "";
        }
        elsif ( length($data) < $expected_len ) {
            $data .= "\0" x ( $expected_len - length($data) );
        }
        my $bits_in_last_byte = $size % 8;
        if ( $bits_in_last_byte != 0 && $expected_len > 0 ) {
            my $mask = ( 0xFF << ( 8 - $bits_in_last_byte ) ) & 0xFF;
            substr( $data, -1, 1 ) &.= chr($mask);
        }
    }

    method fill () {
        $data = "\xFF" x length($data);
        $self->_clean;
    }

    method find_missing () {
        my $index = index( unpack( 'B*', $data ), '0' );
        return ( $index >= 0 && $index < $size ) ? $index : ();
    }

    method inverse () {
        my $inverted = __CLASS__->new( size => $size );
        $inverted->set_data( ~.$data );
        return $inverted;
    }
};
#
1;
