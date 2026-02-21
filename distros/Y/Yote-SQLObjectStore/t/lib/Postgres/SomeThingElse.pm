package Postgres::SomeThingElse;

use 5.16.0;
use warnings;

use base 'Yote::SQLObjectStore::Postgres::Obj';

our %cols = (
    sneak  => 'VARCHAR(256)'
);

1;
