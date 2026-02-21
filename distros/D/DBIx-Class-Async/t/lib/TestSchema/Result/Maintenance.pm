package TestSchema::Result::Maintenance;
use base 'DBIx::Class::Core';

__PACKAGE__->table('maintenance');
__PACKAGE__->add_columns(
    id             => { data_type => 'integer' },
    fk_interface   => { data_type => 'integer' },
    label          => { data_type => 'varchar', size => 64 },
    datetime_start => { data_type => 'datetime' },
    datetime_end   => { data_type => 'datetime' },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('interface', 'TestSchema::Result::Interface', 'fk_interface');

1;
