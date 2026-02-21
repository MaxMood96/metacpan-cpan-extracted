package TestSchema::Result::Interface;

use base 'DBIx::Class::Core';

__PACKAGE__->table('interface');
__PACKAGE__->add_columns(
    id   => { data_type => 'integer' },
    name => { data_type => 'varchar', size => 64 },
);
__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many('currently_in_maintenance',
    'TestSchema::Result::Maintenance',
    'fk_interface',
    {
        where => {
            datetime_start => { '<=' => \'datetime("now")' },
            datetime_end   => { '>=' => \'datetime("now")' },
        },
    }
);

1;
