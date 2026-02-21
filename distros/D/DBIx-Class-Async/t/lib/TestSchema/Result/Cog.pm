package TestSchema::Result::Cog;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('cog');
__PACKAGE__->add_columns(
    sprocketLength => {
        data_type   => 'decimal',
        size        => [10, 2],
        is_nullable => 0,
    },
    thingWidth => {
        data_type   => 'decimal',
        size        => [10, 2],
        is_nullable => 0,
    },
    cogPartNum => {
        data_type   => 'varchar',
        size        => 100,
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key(qw/ sprocketLength thingWidth /);

1;
