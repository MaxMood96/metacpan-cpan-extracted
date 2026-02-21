package SQLite::SomeThing;

use 5.16.0;
use warnings; 
use Data::Dumper;

use base 'Yote::SQLObjectStore::SQLite::Obj';

sub _init {
    my $self = shift;
    my $store = $self->store;
    $self->set_some_ref_hash( $store->new_hash('*HASH<256>_*') );
    $self->set_some_ref_array( $store->new_array('*ARRAY_*') );
    $self->set_some_val_hash( $store->new_hash('*HASH<256>_VALUE') );
    $self->set_some_val_array( $store->new_array('*ARRAY_VALUE') );
}

# simply has a reference hash and a value hash
our %cols = (
    name           => 'VALUE',
    tagline        => 'VALUE',
    brother        => '*',
    sister         => '*',
    sisters        => '*ARRAY_*SQLite::SomeThing',
    sisters_hash   => '*HASH<256>_*SQLite::SomeThing',
    lolov          => '*ARRAY_*ARRAY_VALUE',
    something      => '*SQLite::SomeThing',
    some_ref_array => '*ARRAY_*',
    some_val_array => '*ARRAY_VALUE',
    some_ref_hash  => '*HASH<256>_*',
    some_val_hash  => '*HASH<256>_VALUE',
);

1;
