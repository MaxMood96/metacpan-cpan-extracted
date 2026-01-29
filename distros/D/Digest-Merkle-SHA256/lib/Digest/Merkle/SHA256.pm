use v5.40;
use feature 'class';
no warnings 'experimental::class';
#
class Digest::Merkle::SHA256 v1.0.0 {
    use Digest::SHA qw[sha256];
    use Carp qw[croak];
    field $file_size  : param : reader;
    field $block_size : param : reader //= 16384;                   # 16KiB
    field $height     : reader;
    field $node_count : reader;
    field $nodes      : reader(dump_state) : writer(load_state);    # {level}{index} => hash

    #
    my @zero_hashes;                                                # Shared cache for zero hashes across all instances

    sub _zero_hash ($h) {
        $zero_hashes[0] = pack 'H*', '0' x 40 unless @zero_hashes;
        for ( my $i = scalar @zero_hashes; $i <= $h; $i++ ) {
            $zero_hashes[$i] = sha256( $zero_hashes[ $i - 1 ] . $zero_hashes[ $i - 1 ] );
        }
        $zero_hashes[$h];
    }
    ADJUST {
        if ( $file_size > 0 ) {
            my $num_blocks = int( ( $file_size + $block_size - 1 ) / $block_size );
            $height = 0;
            my $p = 1;
            while ( $p < $num_blocks ) {
                $p <<= 1;
                $height++;
            }
            $node_count = $p;
        }
        else {
            $height     = 0;
            $node_count = 0;
        }
    }
    method root () { $self->get_node( 0, 0 ) }

    method set_block ( $index, $hash ) {
        croak "Index $index out of bounds (max " . ( $node_count - 1 ) . ")" if $index >= $node_count;
        $self->_set_node( $height, $index, $hash );
    }

    method get_node ( $level, $index ) {
        return $nodes->{$level}{$index} if exists $nodes->{$level}{$index};
        _zero_hash( $height - $level );
    }

    method _set_node ( $level, $index, $hash ) {
        $nodes->{$level}{$index} = $hash;
        if ( $level > 0 ) {
            my $parent_index  = $index >> 1;
            my $sibling_index = $index ^ 1;
            my $left          = $index % 2 == 0 ? $hash : $self->get_node( $level, $sibling_index );
            my $right         = $index % 2 == 0 ? $self->get_node( $level, $sibling_index ) : $hash;
            $self->_set_node( $level - 1, $parent_index, sha256( $left . $right ) );
        }
    }

    method get_hashes ( $level, $index, $count ) {
        croak "Level $level out of bounds" if $level > $height;
        my $res = '';
        for my $i ( 0 .. $count ) {
            $res .= $self->get_node( $level, $index + $i );
        }
        $res;
    }

    method get_audit_path ($index) {
        croak "Index $index out of bounds" if $index >= $node_count;
        my @path;
        my $current_index = $index;
        for ( my $level = $height; $level > 0; $level-- ) {
            my $sibling_index = $current_index ^ 1;
            push @path, $self->get_node( $level, $sibling_index );
            $current_index >>= 1;
        }
        \@path;
    }

    method get_layer ($layer_height) {
        croak "Layer height $layer_height out of bounds" if $layer_height > $height;
        my $num_nodes = 1 << $layer_height;
        my $layer     = "";
        for ( my $i = 0; $i < $num_nodes; $i++ ) {
            $layer .= $self->get_node( $layer_height, $i );
        }
        $layer;
    }

    method get_piece_layer ($piece_size) {
        my $k   = 0;
        my $tmp = $piece_size / $block_size;
        croak "piece_size must be a power of two and >= block_size" if $tmp < 1 || ( $tmp & ( $tmp - 1 ) ) != 0;
        while ( $tmp > 1 ) {
            $tmp >>= 1;
            $k++;
        }
        $height >= $k ? $self->get_layer( $height - $k ) : $self->root;
    }

    sub verify_hash ( $s, $index, $hash, $audit_path, $expected_root ) {
        my $current_hash  = $hash;
        my $current_index = $index;
        for my $sibling_hash (@$audit_path) {
            $current_hash = $current_index % 2 == 0 ? sha256( $current_hash . $sibling_hash ) : sha256( $sibling_hash . $current_hash );
            $current_index >>= 1;
        }
        $current_hash eq $expected_root;
    }
};
1;
