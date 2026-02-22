package Yote::SQLObjectStore::MariaDB::Root;

use 5.16.0;

use warnings;

use base 'Yote::SQLObjectStore::MariaDB::Obj';

# simply has a reference hash and a value hash
our %cols = (
    ref_hash => '*HASH<256>_*',
    val_hash => '*HASH<256>_TEXT',
);
