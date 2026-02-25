package SQLite::Library::Author;

use 5.16.0;
use warnings;

use base 'Yote::SQLObjectStore::SQLite::Obj';

use SQLite::Library::Book;

our %cols = (
    name  => 'TEXT',
    books => '*ARRAY_*SQLite::Library::Book',
);

1;
