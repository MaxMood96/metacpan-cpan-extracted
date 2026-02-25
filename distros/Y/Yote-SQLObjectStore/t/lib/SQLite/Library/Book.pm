package SQLite::Library::Book;

use 5.16.0;
use warnings;

use base 'Yote::SQLObjectStore::SQLite::Obj';

our %cols = (
    title     => 'TEXT',
    author    => '*SQLite::Library::Author',
    chapters  => '*ARRAY_TEXT',
    metadata  => '*HASH<64>_TEXT',
);

1;
