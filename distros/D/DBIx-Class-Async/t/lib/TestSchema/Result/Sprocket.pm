package TestSchema::Result::Sprocket;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('sprocket');
__PACKAGE__->add_columns(
    sprocketID => {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    sprocketLength => {
        data_type   => 'decimal',
        size        => [10, 2],
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('sprocketID');

__PACKAGE__->has_many(
    things => 'TestSchema::Result::Thing', 'sprocketID'
);

1;
