#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::HashId 2.155;

use Mouse;
use 5.20.0;

use Config::Model::Exception;
use Carp;

use Mouse::Util::TypeConstraints;
use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;


subtype 'HaskKeyArray' => as 'ArrayRef' ;
coerce 'HaskKeyArray' => from 'Str' => via { [$_] } ;

use Log::Log4perl qw(get_logger :levels);

my $logger = get_logger("Tree::Element::Id::Hash");

extends qw/Config::Model::AnyId/;

with "Config::Model::Role::Grab";
with "Config::Model::Role::ComputeFunction";

has data => ( is => 'rw', isa => 'HashRef',  default => sub { {}; } );
has list => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    traits     => ['Array'],
    default => sub { []; },
    handles => {
        _sort => 'sort_in_place',
    }
);

has [qw/default_keys auto_create_keys/] => (
    is => 'rw',
    isa => 'HaskKeyArray',
    coerce => 1,
    default => sub { []; }
);
has [qw/ordered write_empty_value/] => ( is => 'ro', isa => 'Bool', default => 0 );

sub BUILD ($self,$) {

    # foreach my $wrong (qw/migrate_values_from/) {
    # Config::Model::Exception::Model->throw (
    # object => $self,
    # error =>  "Cannot use $wrong with ".$self->get_type." element"
    # ) if defined $self->{$wrong};
    # }

    # could use "required", but we'd get a Moose error instead of a Config::Model
    # error
    Config::Model::Exception::Model->throw(
        object => $self,
        error  => "Undefined index_type"
    ) unless defined $self->index_type;

    return $self;
}

sub set_properties ($self, @args) {
    $self->SUPER::set_properties(@args);

    my $idx_type = $self->{index_type};

    # remove unwanted items
    my $data = $self->{data};

    my $idx   = 1;
    my $wrong = sub {
        my $k = shift;
        if ( $idx_type eq 'integer' ) {
            return 1 if defined $self->{max_index} and $k > $self->{max_index};
            return 1 if defined $self->{min_index} and $k < $self->{min_index};
        }
        return 1 if defined $self->{max_nb} and $idx++ > $self->{max_nb};
        return 0;
    };

    # delete entries that no longer fit the constraints imposed by the
    # warp mechanism
    foreach my $k ( sort keys %$data ) {
        next unless $wrong->($k);
        $logger->trace( "set_properties: ", $self->name, " deleting id $k" );
        delete $data->{$k};
    }
    return;
}

sub _migrate ($self) {
    return if $self->{migration_done};

    # migration must be done *after* initial load to make sure that all data
    # were retrieved from the file before migration.
    return if $self->instance->initial_load;
    $self->{migration_done} = 1;

    if ( $self->{migrate_keys_from} ) {
        my $followed = $self->safe_typed_grab( param => 'migrate_keys_from', check => 'no' );
        if ( $logger->is_debug ) {
            $logger->debug( $self->name, " migrate keys from ", $followed->name );
        }

        for my $idx ($followed->fetch_all_indexes) {
            $self->_store( $idx, undef ) unless $self->_defined($idx);
        }
    }
    elsif ( $self->{migrate_values_from} ) {
        my $followed = $self->safe_typed_grab( param => 'migrate_values_from', check => 'no' );
        $logger->debug( $self->name, " migrate values from ", $followed->name )
            if $logger->is_debug;
        foreach my $item ( $followed->fetch_all_indexes ) {
            next if $self->exists($item);    # don't clobber existing entries
            my $data = $followed->fetch_with_id($item)->dump_as_data( check => 'no' );
            $self->fetch_with_id($item)->load_data($data);
        }
    }
    return;
}

sub get_type ($self) {
    return 'hash';
}

sub get_info ($self) {
    my @items = (
        'type: ' . $self->get_type . ( $self->ordered ? '(ordered)' : '' ),
        'index: ' . $self->index_type,
        'cargo: ' . $self->cargo_type,
    );

    if ( $self->cargo_type eq 'node' ) {
        push @items, "cargo class: " . $self->config_class_name;
    }

    foreach my $what (qw/min_index max_index max_nb warn_if_key_match warn_unless_key_match/) {
        my $v   = $self->$what();
        my $str = $what;
        $str =~ s/_/ /g;
        push @items, "$str: $v" if defined $v;
    }

    return @items;
}

# important: return the actual size (not taking into account auto-created stuff)
sub fetch_size ($self) {
    return scalar keys %{ $self->{data} };
}

sub _fetch_all_indexes ($self) {
    return $self->{ordered}
        ? @{ $self->{list} }
        : sort keys %{ $self->{data} };
}

# fetch without any check
sub _fetch_with_id ($self, $key) {
    return $self->{data}{$key};
}

# store without any check
sub _store ($self, $key, $value) {
    push @{ $self->{list} }, $key
        unless exists $self->{data}{$key};
    $self->notify_change(note => "added entry $key") if $self->write_empty_value;
    return $self->{data}{$key} = $value;
}

sub _exists ($self, $key) {
    return exists $self->{data}{$key};
}

sub _defined {
    my ( $self, $key ) = @_;
    return defined $self->{data}{$key} ? 1 : 0;
}

#internal
sub auto_create_elements ($self) {
    my $auto_p = $self->auto_create_keys;
    return unless defined $auto_p;

    # create empty slots
    foreach my $slot ( ref $auto_p ? @$auto_p : ($auto_p) ) {
        $self->_store( $slot, undef ) unless exists $self->{data}{$slot};
    }

    return;
}

# internal
sub create_default ($self) {
    my @temp = keys %{ $self->{data} };

    return if @temp;

    # hash is empty so create empty element for default keys
    my $def = $self->get_default_keys;
    map { $self->_store( $_, undef ) } @$def;
    $self->create_default_with_init;
    return;
}

sub _delete ( $self, $key ) {
    # remove key in ordered list
    @{ $self->{list} } = grep { $_ ne $key } @{ $self->{list} };

    return delete $self->{data}{$key};
}

sub remove ($self, @args) {
    return $self->delete(@args);
}

sub _clear ($self) {
    $self->{list} = [];
    $self->{data} = {};
    return;
}

## no critic (Subroutines::ProhibitBuiltinHomonyms)
sub sort ($self) {
    if ($self->ordered) {
        $self->_sort;
    }
    else {
        Config::Model::Exception::User->throw(
            object  => $self,
            message => "cannot call sort on non ordered hash"
        );
    }
    return;
}

sub insort ($self, $id) {
    if ($self->ordered) {
        my $elt = $self->fetch_with_id($id);
        $self->_sort;
        return $elt;
    }
    else {
        Config::Model::Exception::User->throw(
            object  => $self,
            message => "cannot call insort on non ordered hash"
        );
    }
    return;
}

# hash only method
sub firstkey ($self) {
    $self->warp
        if ( $self->{warp} and @{ $self->{warp_info}{computed_master} } );

    $self->create_default if defined $self->{default};

    # reset "each" iterator (to be sure, map is also an iterator)
    my @list = $self->_fetch_all_indexes;
    $self->{each_list} = \@list;
    return shift @list;
}

# hash only method
sub nextkey ($self) {
    $self->warp
        if ( $self->{warp} and @{ $self->{warp_info}{computed_master} } );

    my $res = shift @{ $self->{each_list} };

    return $res if defined $res;

    # reset list for next call to next_keys
    $self->{each_list} = [ $self->_fetch_all_indexes ];

    return;
}

sub swap ($self, $key1, $key2 ) {
    foreach my $k ($key1, $key2) {
        Config::Model::Exception::User->throw(
            object  => $self,
            message => "swap: unknow key $k"
        ) unless exists $self->{data}{$k};
    }

    my @copy = @{ $self->{list} };
    for ( my $idx = 0 ; $idx <= $#copy ; $idx++ ) {
        if ( $copy[$idx] eq $key1 ) {
            $self->{list}[$idx] = $key2;
        }
        if ( $copy[$idx] eq $key2 ) {
            $self->{list}[$idx] = $key1;
        }
    }

    $self->notify_change( note => "swap ordered hash keys '$key1' and '$key2'" );
    return;
}

sub move ($self, $from, $to, %args) {
    $logger->trace("moving item from $from to $to");

    Config::Model::Exception::User->throw(
        object  => $self,
        message => "move: unknow from key $from"
    ) unless exists $self->{data}{$from};

    my $ok = $self->check_idx($to);

    my $check = $args{check};
    if ($ok or $check eq 'no') {
        # this places $to at the end of the ordered list (for ordered hash)
        $self->copy($from, $to);

        $self->notify_change( note => "rename key from '$from' to '$to'" );

        # data_mode is preset or layered or user. Actually only user
        # mode makes sense here
        my $imode = $self->instance->get_data_mode;
        $self->set_data_mode( $to, $imode );

        # find where are $to and $from keys
        my ( $to_idx, $from_idx );
        my $list = $self->{list};
        for (my $idx = 0; $idx <= $#$list; $idx++) {
            $to_idx   = $idx if $list->[$idx] eq $to;
            $from_idx = $idx if $list->[$idx] eq $from;
        }

        # replace $from with $to in the order list of the ordered hash
        # Since $to is clobbered, $from takes its place in the list
        $list->[$from_idx] = $to;

        # and the obsolete place for $to entry is removed from the list
        splice @$list, $to_idx, 1;

        $self->_delete($from);
        delete $self->{warning_hash}{$from};

    }
    elsif ($check eq 'yes') {
        Config::Model::Exception::WrongValue->throw(
            error  => join( "\n\t", @{ $self->{error} } ),
            object => $self
        );
    }
    $logger->debug("Skipped move $from -> $to");
    return $ok;
}

sub move_after ($self, $key_to_move, $ref_key = undef) {
    if ( not $self->ordered ) {
        $logger->warn("called move_after on unordered hash");
        return;
    }

    foreach my $k ($key_to_move, $ref_key) {
        next unless defined $k;
        Config::Model::Exception::User->throw(
            object  => $self,
            message => "swap: unknow key $k"
        ) unless exists $self->{data}{$k};
    }

    # remove the key to move in ordered list
    @{ $self->{list} } = grep { $_ ne $key_to_move } @{ $self->{list} };

    my $list = $self->{list};

    my $msg;
    if ( defined $ref_key ) {
        for ( my $idx = 0 ; $idx <= $#$list ; $idx++ ) {
            if ( $list->[$idx] eq $ref_key ) {
                splice @$list, $idx + 1, 0, $key_to_move;
                last;
            }
        }

        $msg = "moved key '$key_to_move' after '$ref_key'";
    }
    else {
        unshift @$list, $key_to_move;
        $msg = "moved key '$key_to_move' at beginning";
    }

    $self->notify_change( note => $msg );

    return;
}

sub move_up ($self, $key) {
    if ( not $self->ordered ) {
        $logger->warn("called move_up on unordered hash");
        return;
    }

    Config::Model::Exception::User->throw(
        object  => $self,
        message => "move_up: unknow key $key"
    ) unless exists $self->{data}{$key};

    my $list = $self->{list};

    # we start from 1 as we can't move up idx 0
    for ( my $idx = 1 ; $idx < scalar @$list ; $idx++ ) {
        if ( $list->[$idx] eq $key ) {
            $list->[$idx] = $list->[ $idx - 1 ];
            $list->[ $idx - 1 ] = $key;
            $self->notify_change( note => "moved up key '$key'" );
            last;
        }
    }

    # notify_change is placed in the loop so the notification
    # is not sent if the user tries to move up idx 0
    return;
}

sub move_down ($self, $key) {
    if ( not $self->ordered ) {
        $logger->warn("called move_down on unordered hash");
        return;
    }

    Config::Model::Exception::User->throw(
        object  => $self,
        message => "move_down: unknown key $key"
    ) unless exists $self->{data}{$key};

    my $list = $self->{list};

    # we end at $#$list -1  as we can't move down last idx
    for ( my $idx = 0 ; $idx < scalar @$list - 1 ; $idx++ ) {
        if ( $list->[$idx] eq $key ) {
            $list->[$idx] = $list->[ $idx + 1 ];
            $list->[ $idx + 1 ] = $key;
            $self->notify_change( note => "moved down key $key" );
            last;
        }
    }

    # notify_change is placed in the loop so the notification
    # is not sent if the user tries to move past last idx
    return;
}

sub _load_data_from_hash ($self, %args) {
    my $data = $args{data};
    my %backup = %$data ;

    my @ordered_keys;
    my $from = '';

    my $order_key = '__'.$self->element_name.'_order';
    if ( $self->{ordered} and (defined $data->{$order_key} or defined $data->{__order} )) {
        @ordered_keys = @{ delete $data->{$order_key} or delete $data->{__order} };
        $from      = ' with '.$order_key;
    }
    elsif ( $self->{ordered} and (not $data->{__skip_order} and keys %$data > 1)) {
        $logger->warn(
            "HashId " . $self->location . ": loading ordered "
            . "hash from hash ref without special key '__order'. Element "
            . "order is not defined. If needed, this warning can be suppressed by passing "
            . " key '__skip_order' set to 1."
        );
        $from = ' without '.$order_key;
    }
    delete $data->{__skip_order};

    if (@ordered_keys) {
        my %data_keys = map { $_ => 1 ; } keys %$data;
        my @left_keys;
        foreach my $k (@ordered_keys) {
            push @left_keys, $k unless delete $data_keys{$k};
        }
        if ( %data_keys or @left_keys) {
            my @msg ;
            push @msg, "Unlisted keys in __order:", keys %data_keys if %data_keys;
            push @msg, "Extra keys in __order:", @left_keys if @left_keys;
            Config::Model::Exception::LoadData->throw(
                object     => $self,
                message    => "load_data: ordered keys mistmatch: @msg",
                wrong_data => \%backup,
            );
        }
    }
    my @load_keys = @ordered_keys ? @ordered_keys : sort keys %$data;

    $logger->info(
        "HashId load_data (" . $self->location .
            ") will load idx @load_keys from hash ref $from"
    );
    my $res = 0;
    foreach my $elt (@load_keys) {
        my $obj = $self->fetch_with_id($elt);
        $res += $obj->load_data( %args, data => $data->{$elt} ) if defined $data->{$elt};
    }
    return !!$res;
}

sub load_data ($self, @args) {
    my %args = @args > 1 ? @args : ( data => $args[0] );
    my $data  = delete $args{data};
    my $check = $self->_check_check( $args{check} );

    if ( ref($data) eq 'HASH' ) {
        return $self->_load_data_from_hash(data => $data, %args);
    }
    elsif ( ref($data) eq 'ARRAY' ) {
        my $res = 0;
        $logger->info(
            "HashId load_data (" . $self->location . ") will load idx 0..$#$data from array ref" );
        $self->notify_change( note => "Converted ordered data to non ordered", really => 1) unless $self->ordered;
        my $idx = 0;
        while ( $idx < @$data ) {
            my $elt = $data->[ $idx++ ];
            my $obj = $self->fetch_with_id($elt);
            $res += $obj->load_data( %args, data => $data->[ $idx++ ] );
        }
        return !!$res;
    }
    elsif ( defined $data ) {

        # we can skip undefined data
        my $expected = $self->{ordered} ? 'array' : 'hash';
        Config::Model::Exception::LoadData->throw(
            object     => $self,
            message    => "load_data called with non $expected ref arg",
            wrong_data => $data,
        );
    }
    return;
}

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Handle hash element for configuration model

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::HashId - Handle hash element for configuration model

=head1 VERSION

version 2.155

=head1 SYNOPSIS

See L<Config::Model::AnyId/SYNOPSIS>

=head1 DESCRIPTION

This class provides hash elements for a L<Config::Model::Node>.

The hash index can either be en enumerated type, a boolean, an integer
or a string.

=head1 CONSTRUCTOR

HashId object should not be created directly.

=head1 Hash model declaration

See
L<model declaration section|Config::Model::AnyId/"Hash or list model declaration">
from L<Config::Model::AnyId>.

=head1 Methods

=head2 get_type

Returns C<hash>.

=head2 fetch_size

Returns the number of elements of the hash.

=head2 sort

Sort an ordered hash. Throws an error if called on a non ordered hash.

=head2 insort

Parameters: key

Create a new element in the ordered hash while keeping alphabetical order of the keys

Returns the newly created element.

Throws an error if called on a non ordered hash.

=head2 firstkey

Returns the first key of the hash. Behaves like C<each> core perl
function.

=head2 nextkey

Returns the next key of the hash. Behaves like C<each> core perl
function.

=head2 swap

Parameters: C<< ( key1 , key2 ) >>

Swap the order of the 2 keys. Ignored for non ordered hash.

=head2 move

Parameters: C<< ( key1 , key2 ) >>

Rename key1 in key2. 

Also also optional check parameter to disable warning:

 move ('foo','bar', check => 'no')

=head2 move_after

Parameters: C<< ( key_to_move [ , after_this_key ] ) >>

Move the first key after the second one. If the second parameter is
omitted, the first key is placed in first position. Ignored for non
ordered hash.

=head2 move_up

Parameters: C<< ( key ) >>

Move the key up in a ordered hash. Attempt to move up the first key of
an ordered hash is ignored. Ignored for non ordered hash.

=head2 move_down

Parameters: C<< ( key ) >>

Move the key down in a ordered hash. Attempt to move up the last key of
an ordered hash is ignored. Ignored for non ordered hash.

=head2 load_data

Parameters: C<< ( data => ( hash_ref | array_ref ) [ , check => ... , ... ]) >>

Load data as a hash ref for standard hash.

Ordered hash should be loaded with an array ref or with a hash
containing a special C<__order> element. E.g. loaded with either:

  [ a => 'foo', b => 'bar' ]

or

  { __order => ['a','b'], b => 'bar', a => 'foo' }

C<__skip_order> parameter can be used if loading order is not
important:

  { __skip_order => 1, b => 'bar', a => 'foo'}

load_data can also be called with a single ref parameter.

Return 1 of some data was loaded.

=head2 get_info

Returns a list of information related to the hash. See
L<Config::Model::Value/get_info> for more details.

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model>, 
L<Config::Model::Instance>, 
L<Config::Model::AnyId>,
L<Config::Model::ListId>,
L<Config::Model::Value>

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
