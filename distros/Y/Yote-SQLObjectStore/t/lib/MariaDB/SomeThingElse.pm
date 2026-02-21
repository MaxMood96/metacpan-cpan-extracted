package SQLite::SomeThingElse;

use 5.16.0;
use warnings; 

use base 'Yote::SQLObjectStore::SQLite::Obj';

our %cols = (
    sneak  => 'VARCHAR(256)'
);

1;
