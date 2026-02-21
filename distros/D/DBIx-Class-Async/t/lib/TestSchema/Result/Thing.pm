package TestSchema::Result::Thing;

use strict;
use warnings;
use base 'DBIx::Class::Core';

__PACKAGE__->table('thing');
__PACKAGE__->add_columns(
    thingID => {
        data_type         => 'integer',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    sprocketID => {
        data_type   => 'integer',
        is_nullable => 0,
    },
    thingWidth => {
        data_type   => 'decimal',
        size        => [10, 2],
        is_nullable => 0,
    },
);

__PACKAGE__->set_primary_key('thingID');

# Direct FK relationship to sprocket
__PACKAGE__->belongs_to(
    sprocket => 'TestSchema::Result::Sprocket', 'sprocketID'
);

# Approach A: cog via join/prefetch (pure DBIC relationship style).
# The join condition spans two tables -- thingWidth lives on self,
# sprocketLength lives on the related sprocket -- so we use a coderef
# condition. DBIC calls this during SQL generation (no live object),
# hence we use -ident for both sides and rely on the join to sprocket
# being declared in the search attrs.
__PACKAGE__->has_one(
    cog => 'TestSchema::Result::Cog',
    sub {
        my $args = shift;
        return {
            "$args->{foreign_alias}.thingWidth"     => { -ident => "$args->{self_alias}.thingWidth"           },
            "$args->{foreign_alias}.sprocketLength" => { -ident => "sprocket.sprocketLength" },
        };
    }
);

# Approach B: helper method on Thing.
# Two-step lookup: fetch sprocket first, then find the cog.
# Simpler, no coderef complexity, works identically for the caller.
sub find_cog {
    my ($self, $async_schema) = @_;

    # sprocketLength is not on self directly - fetch it via sprocket first,
    # then use both values to find the cog
    return $async_schema->resultset('Sprocket')->find(
        $self->sprocketID
    )->then(sub {
        my $sprocket_row = shift;
        return Future->done(undef) unless defined $sprocket_row;

        return $async_schema->resultset('Cog')->find({
            sprocketLength => $sprocket_row->sprocketLength + 0,
            thingWidth     => $self->thingWidth + 0,
        });
    });
}

1;
