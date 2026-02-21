package Yote::SQLObjectStore::TiedArray;

use 5.16.0;
use warnings;

use Tie::Array;

sub tie {
    my( $pkg, $store, $id, $handle ) = @_;

    my ($value_type) = ($handle =~ /^\*ARRAY_(.*)/);
    
    my $table = $store->get_table_manager->label_to_table($handle);

    my @data;
    $store->apply_query_array(
        "SELECT idx,val FROM $table WHERE id=?",
        [$id],
        sub {
            my ($i, $v) = @_;
            $data[$i] = $v;
        } );
    
    my $array = [];
    tie @$array, 'Yote::SQLObjectStore::TiedArray', $store, $id, $handle, $table, $value_type, $array, @data;
    return $array;
}

sub value_type {
    return shift->{value_type};
}

sub is_type {
    my ($self, $expected_type) = @_;
    my $type = $self->{type};

    # if an anything reference, any reference type matches
    return 1 if $expected_type eq '*';

    return $type eq $expected_type;
}

sub save_sql {
    my $self = shift;
    my $id = $self->id;

    #
    # just going to remove the old values and enter the new ones in
    # but may optimize in the future. using the tied array assumes that
    # there is not a great amount of data here
    #
    my @ret_sql;

    my $table = $self->{table};
    
    my $del_sql = "DELETE FROM $table WHERE id=?";
    push @ret_sql, [ $del_sql, $id ];

    my $data = $self->{data};

    my @insert_qparams = map { [$id, $_, $data->[$_]] } (0..$#$data);

    if (@insert_qparams) {
        my $store = $self->{store};
        my $sql = 
            $store->insert_or_replace." INTO $table (id,idx,val) VALUES " 
            .join( ',', ("(?,?,?)") x @insert_qparams);
        push @ret_sql, [$sql, map { @$_ } @insert_qparams];
    }
    return @ret_sql;
    
}



sub TIEARRAY {
    my( $pkg, $store, $id, $handle, $table, $value_type, $tied_ref, @data ) = @_;
    my $tied = bless { 
        id         => $id,
        data       => [@data],
        store      => $store,
        table      => $table,
        tied_ref   => $tied_ref,
        type       => $handle,
        value_type => $value_type,
    }, $pkg;

    return $tied;
} #TIEARRAY

sub id {
    return shift->{id};
}

# returns tied data structure for caching
sub cache_obj {
    return shift->{tied_ref};
}

sub _dirty {
    my $self = shift;
    $self->{store}->dirty( $self );
} #_dirty

sub EXTEND {}

sub get {
    &FETCH;
}

sub set {
    &STORE;
}

sub FETCH {
    my( $self, $idx ) = @_;
    if ($idx !~ /^[0-9]+$/) {
        die "array access expects index";
    }
    $self->{store}->xform_out( $self->{data}[$idx], $self->{value_type} );
} #FETCH

sub FETCHSIZE {
    scalar @{shift->{data}};
}

sub STORE {
    my( $self, $idx, $val ) = @_;
    my $inval = $self->{store}->xform_in( $val, $self->{value_type} );
    no warnings 'uninitialized';
    if ($inval ne $self->{data}[$idx]) {
        $self->_dirty;
        $self->{data}[$idx] = $inval;
    }
} #STORE

sub STORESIZE {
    my( $self, $size ) = @_;
    my $data = $self->{data};
    $#$data = $size - 1;

} #STORESIZE

sub EXISTS {
    my( $self, $idx ) = @_;
    return exists $self->{data}[$idx];
} #EXISTS

sub DELETE {
    my( $self, $idx ) = @_;
    my $data = $self->{data};
    if (exists $data->[$idx]) {
        my $outval = $self->{store}->xform_out( $data->[$idx], $self->{value_type} );
        delete $data->[$idx];
        $self->_dirty;
        return $outval;
    }
} #DELETE

sub CLEAR {
    my $self = shift;
    my $data = $self->{data};
    $self->_dirty if @$data;
    @$data = ();
}

sub PUSH {
    my( $self, @vals ) = @_;
    my $data = $self->{data};
    if (@vals) {
        my $store = $self->{store};
        push @$data, map { $store->xform_in($_,$self->{value_type}) } @vals;
        $self->_dirty;
    }
    return scalar(@$data);
}
sub POP {
    my $self = shift;
    my $data = $self->{data};
    return undef unless @$data;
    $self->_dirty;
    return $self->{store}->xform_out( pop @$data, $self->{value_type} );
}
sub SHIFT {
    my $self = shift;
    my $data = $self->{data};
    return undef unless @$data;
    $self->_dirty;
    return $self->{store}->xform_out( shift @$data, $self->{value_type} );
}

sub UNSHIFT {
    my( $self, @vals ) = @_;
    my $data = $self->{data};
    if (@vals) {
        my $store = $self->{store};
        unshift @$data, map { $store->xform_in($_,$self->{value_type}) } @vals;
        $self->_dirty;
    }
    return scalar(@$data);
}

sub SPLICE {
    my( $self, $offset, $remove_length, @vals ) = @_;
    
    my $data = $self->{data};
    my $store = $self->{store};
    $self->_dirty;

    my @out = map { $store->xform_out($_,$self->{value_type}) } splice (@$data, $offset, $remove_length, map { $store->xform_in($_,$self->{value_type}) } @vals);

    return @out;
} #SPLICE

1;
