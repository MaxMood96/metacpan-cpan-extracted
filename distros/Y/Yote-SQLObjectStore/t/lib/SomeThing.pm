package SomeThing;

use base 'Yote::SQLObjectStore::SQLite::Obj';

# simply has a reference hash and a value hash
our %cols = (
    name => 'VALUE',
    tagline => 'VALUE',
    brother => 'REF',
    sister => 'REF',
    something => 'SomeThing',
    some_ref_array => 'ARRAY_REF',
    some_val_array => 'ARRAY_VALUE',
    some_ref_hash => 'HASH_REF',
    some_val_hash => 'HASH_VALUE',
    
);

1;
