package MySchema::Result::Item;
use base 'DBIx::Class::Core';

__PACKAGE__->load_components(qw/InflateColumn::DateTime/);

__PACKAGE__->table('item');
__PACKAGE__->add_columns(
    id         => {
        data_type         => 'integer',
        is_auto_increment => 1
    },
    name       => {
        data_type         => 'varchar',
        size              => 255
    },
    created_at => {
        data_type         => 'timestamp with time zone',
        is_nullable       => 1,
        timezone          => 'Europe/London',
    },
);

__PACKAGE__->set_primary_key('id');

1;
