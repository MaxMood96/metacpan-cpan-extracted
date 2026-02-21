package Yote::SQLObjectStore::TiedHash;

use 5.16.0;
use warnings;

use Tie::Hash;

sub tie {
    my( $pkg, $store, $id, $handle ) = @_;

    my ($key_size, $value_type) = ($handle =~ /^\*HASH<(\d+)>_(.*)/);
    
    my $table = $store->get_table_manager->label_to_table($handle);
      
    my %data;
    $store->apply_query_array(
        "SELECT hashkey,val FROM $table WHERE id=?",
        [$id],
        sub {
            my ($k, $v) = @_;
            $data{$k} = $v;
        } );
    
    my $hash = {};
    tie %$hash, 'Yote::SQLObjectStore::TiedHash', $store, $id, $key_size, $handle, $table, $value_type, $hash, %data;
    return $hash;
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
    # but may optimize in the future. using the tied hash assumes that
    # there is not a great amount of data here
    #

    my @ret_sql;

    my $table = $self->{table};
    
    my $del_sql = "DELETE FROM $table WHERE id=?";
    push @ret_sql, [ $del_sql, $id ];

    my $data = $self->{data};
    my @fields = keys %$data;
    my @insert_qparams = map { [$id, $_, $data->{$_}] } @fields;
    if (@insert_qparams) {
        my $store = $self->{store};
        my $sql = 
            $store->insert_or_replace." INTO $table (id,hashkey,val) VALUES " 
            .join( ',', ("(?,?,?)") x @insert_qparams);
        push @ret_sql, [$sql, map { @$_ } @insert_qparams];
    }
    return @ret_sql;
}

sub TIEHASH {
    my( $pkg, $store, $id, $key_size, $handle, $table, $value_type, $tied_ref, %data ) = @_;
    my $tied = bless { 
        id         => $id,
        data       => {%data},
        key_size   => $key_size,
        store      => $store,
        table      => $table,
        type       => $handle,
        tied_ref   => $tied_ref,
        value_type => $value_type,
    }, $pkg;

    return $tied;
} #TIEHASH

sub id {
    return shift->{id};
}

sub key_size {
    return shift->{key_size};
}

# returns tied data structure for caching
sub cache_obj {
    return shift->{tied_ref};
}


sub _dirty {
    my $self = shift;
    $self->{store}->dirty( $self );
} #_dirty


sub CLEAR {
    my $self = shift;
    my $data = $self->{data};
    $self->_dirty if scalar( keys %$data );
    %$data = ();
} #CLEAR

sub DELETE {
    my( $self, $key ) = @_;
    my $data = $self->{data};
    return undef unless exists $data->{$key};
    $self->_dirty;
    my $oldval = delete $data->{$key};
    return $self->{store}->xform_out( $oldval, $self->{value_type} );
} #DELETE


sub EXISTS {
    my( $self, $key ) = @_;
    return exists $self->{data}{$key};
} #EXISTS

sub get {
    &FETCH;
}

sub set {
    &STORE;
}

sub FETCH {
    my( $self, $key ) = @_;
    return $self->{store}->xform_out( $self->{data}{$key}, $self->{value_type} );
} #FETCH

sub STORE {
    my( $self, $key, $val ) = @_;

    if (length($key) > $self->{key_size}) {
        die "key is too large for hash. given length of ".length($key)." and max is $self->{key_size}";
    }

    my $data = $self->{data};
    my $inval = $self->{store}->xform_in( $val, $self->{value_type} );
    no warnings 'uninitialized';
    if ( !exists $data->{$key} or $data->{$key} ne $inval) {
        $self->_dirty;
        $data->{$key} = $inval;
    }
    return $val;
} #STORE

sub FIRSTKEY {
    my $self = shift;

    my $data = $self->{data};
    my $a = scalar keys %$data; #reset the each
    my( $k, $val ) = each %$data;
    return $k;
} #FIRSTKEY

sub NEXTKEY  {
    my $self = shift;
    my $data = $self->{data};
    my( $k, $val ) = each %$data;
    return $k;
} #NEXTKEY

1;
