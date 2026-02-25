package SQLite::Library;

use 5.16.0;
use warnings;

use base 'Yote::SQLObjectStore::SQLite::Obj';

use SQLite::Library::Book;
use SQLite::Library::Author;

our %cols = (
    name    => 'TEXT',
    books   => '*ARRAY_*SQLite::Library::Book',
    authors => '*HASH<128>_*SQLite::Library::Author',
);

1;
