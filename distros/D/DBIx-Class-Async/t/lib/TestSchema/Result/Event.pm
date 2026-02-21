package TestSchema::Result::Event;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('Events');
__PACKAGE__->add_columns(
    EventId   => { data_type => 'char',    size => 36, is_nullable => 0 },
    TapeoutId => { data_type => 'char',    size => 36, is_nullable => 0 },
    Content   => { data_type => 'varchar', size => 255, is_nullable => 0 },
    IpAddr    => { data_type => 'bigint',               is_nullable => 0 },
    Author    => { data_type => 'varchar', size => 255, is_nullable => 0 },
    Created   => { data_type => 'datetime',             is_nullable => 0,
                   default_value => \'current_timestamp' },
    Context   => { data_type => 'varchar', size => 64,  is_nullable => 1 },
);

__PACKAGE__->set_primary_key('EventId');

1;
