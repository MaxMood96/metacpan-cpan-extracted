package SecondSchemaWith;

use strict;
use warnings;
use base qw(DBIx::Class::Schema);
use DBIx::Class::Schema::ResultSetNames;

__PACKAGE__->load_components('Schema::ResultSetNames');

__PACKAGE__->load_namespaces;

1;
