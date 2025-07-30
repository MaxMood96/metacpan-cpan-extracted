##----------------------------------------------------------------------------
## Database Object Interface - ~/lib/DB/Object/Query/Element.pm
## Version v0.2.0
## Copyright(c) 2023 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2023/07/08
## Modified 2024/03/22
## All rights reserved
## 
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
package DB::Object::Query::Element;
BEGIN
{
    use strict;
    use common::sense;
    use parent qw( Module::Generic );
    use vars qw( $VERSION );
    use Wanted;
    our $VERSION = 'v0.2.0';
};

use strict;
use warnings;

sub init
{
    my $self = shift( @_ );
    $self->{as_is}          = undef;
    $self->{field}          = undef;
    $self->{format}         = undef;
    $self->{index}          = undef;
    $self->{is_numbered}    = 0;
    $self->{placeholder}    = undef;
    $self->{query_object}   = undef;
    $self->{type}           = undef;
    $self->{value}          = undef;
    $self->{_init_strict_use_sub} = 1;
    $self->{_init_params_order} = [qw( query_object field placeholder format type value index )];
    $self->SUPER::init( @_ ) || return( $self->pass_error );
    return( $self );
}

sub as_is { return( shift->_set_get_boolean( 'as_is', @_ ) ); }

sub elements { return( shift->_set_get_object_without_init( 'elements', 'DB::Object::Query::Elements', @_ ) ); }

# The field name
sub field { return( shift->_set_get_scalar_or_object( 'field', 'DB::Object::Fields::Field', @_ ) ); }

sub fo
{
    my $self = shift( @_ );
    if( @_ )
    {
        return( $self->error( "Value provided for method fo() in class ", ref( $self ), " is not a DB::Object::Fields::Field object." ) ) if( !$self->_is_a( $_[0] => 'DB::Object::Fields::Field' ) );
        $self->{fo} = shift( @_ );
    }
    return( $self->{fo} ) if( $self->{fo} );
    my $f = $self->field;
    my $fo;
    if( $self->_is_a( $f => 'DB::Object::Fields::Field' ) )
    {
        $fo = $f;
    }
    elsif( defined( $f ) && CORE::length( $f // '' ) )
    {
        $fo = $self->query_object->table_object->fields( $f );
    }
    $self->{fo} = $fo if( defined( $fo ) );
    return( $self->new_null ) if( !defined( $fo ) && Wanted::want( 'OBJECT' ) );
    return( $fo );
}

# The formatting for insert, e.g.: field = value, or possibly field = ?, or even field = $1
sub format { return( shift->_set_get_scalar_as_object( 'format', @_ ) ); }

# The generic representation of this element if we want to bind data to it
sub generic { return( shift->_set_get_scalar_as_object( 'generic', @_ ) ); }

# If this is a numbered placeholder
sub index { return( shift->_set_get_number( { field => 'index', undef_ok => 1 }, @_ ) ); }

# sub is_numbered { return( shift->_set_get_boolean( 'is_numbered', @_ ) ); }
sub is_numbered
{
    my $self = shift( @_ );
    my $placeholder = $self->placeholder;
    return(0) if( !defined( $placeholder ) );
    my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
    if( $placeholder =~ /^$placeholder_re$/ && defined( $+{index} ) )
    {
        return(1);
    }
    return(0);
}

# The placeholder, such as ?, $2, ?2, or others supported by the driver
sub placeholder { return( shift->_set_get_scalar_as_object({
    field => 'placeholder',
    callbacks => 
    {
        set => sub
        {
            # $val is a scalar object (Module::Generic::Scalar)
            my( $self, $val ) = @_;
            my $placeholder_re = $self->query_object->database_object->_placeholder_regexp;
            if( defined( $val ) && "$val" =~ /^(?:$placeholder_re)$/ )
            {
                # Could be undef
                $self->index( $+{index} );
            }
            else
            {
                $self->index( undef );
            }
            return( $val );
        }
    }
}, @_ ) ); }

sub query_object { return( shift->_set_get_object( 'query_object', 'DB::Object::Query', @_ ) ); }

# The field data type to be used when binding parameters
# sub type { return( shift->_set_get_scalar_as_object( 'type', @_ ) ); }
sub type { return( shift->_set_get_scalar_as_object( { field => 'type', callbacks => 
{
    get => sub
    {
        my( $self, $val ) = @_;
        my $field = $self->field;
        if( ( !defined( $val ) || !$val->defined || !CORE::length( $val // '' ) ) &&
            $self->_is_a( $field => 'DB::Object::Fields::Field' ) )
        {
            $val = $field->datatype->constant;
        }
        return( $val );
    }
}}, @_ ) ); }

# The value to bind, if any at all. So could be undef
sub value { return( shift->_set_get_scalar_as_object( 'value', @_ ) ); }

1;
# NOTE: POD
__END__

=encoding utf-8

=head1 NAME

DB::Object::Query::Element - Database Object Interface

=head1 SYNOPSIS

    use DB::Object::Query::Element;
    my $this = DB::Object::Query::Element->new(
        # a scalar, or an DB::Object::Fields::Field object
        field => $some_sql_field,
        # designed to be used for insert statements
        format => $some_format,
        # The position, if any, of this new object
        # This is used for numbered placeholders only, 
        # such as $1, $2, or ?1, ?2 depending on the driver
        index => $integer,
        # Could also be $1, $2, ?1, ?2 depending on the driver
        placeholder => '?',
        # a DB::Object::Query object
        query_object => $object,
        type => $sql_type,
        value => $some_value,
    ) || die( DB::Object::Query::Element->error, "\n" );

=head1 VERSION

    v0.2.0

=head1 DESCRIPTION

This class represent a L<query|DB::Object::Query> element as used throughout this API. It can represent the formatting of some part of an insert query, or some placeholder and its type and field, or just a field and its value, or a combination of those.

It makes it more efficient to build query with their associated binded values and types in the proper order, possibly using numbered placeholder, if the SQL driver (such as L<PostgreSQL|DBD::Pg> or L<SQLite|DBD::sqlite>) support them.

=head1 CONSTRUCTOR

=head2 new

Takes an hash or hash reference of key-value pairs matching any of the methods below.

Returns a newly instantiated object upon success, or sets an L<error|Module::Generic/error> and return C<undef> or an empty list, depending on the caller's context.

=head1 METHODS

=head2 as_is

Sets or gets the boolean value. If true, then the format specified will be used as-is during execution. This is aimed for value representing SQL functions or other values passed through that the user wants no optimisation.

For example:

    my $tbl = $dbh->some_table || die( "No table found" );
    $tbl->where( user_id => '?' );
    my $sth = $tbl->update( updated => \'NOW()' ) || die( $tbl->error );
    my $rv = $sth->exec( $user_id ) || die( $sth->error );

In the example above, when C<NOW()> was specified as a scalar reference, it indicates we want the value to be used I<as-is>. This would translate to something like:

    UPDATE some_table SET updated = NOW() WHERE user_id = 'b9c01f91-8094-462c-9f49-a0340dc9fcec'

=head2 elements

Sets or gets an L<DB::Object::Query::Elements> object. By default this is C<undef> and is used when this element represent a sub-query.

=head2 field

Sets or gets the element SQL field (or column) name. It can also be set to a L<DB::Object::Fields::Field> object.

=head2 fo

    my $field_object = $el->fo;
    $el->fo( $field_object );

Sets or gets a L<table field object|DB::Object::Fields::Field>.

If no field is set, then in accessor mode, this will retrieve the L<table field object|DB::Object::Fields::Field> for the L<field|/field> value currently set by calling L<fields|DB::Object::Tables> and passing it the field name set in L</field>, if any.

If the value set in L</field> is already a L<table field object|DB::Object::Fields::Field>, then this is used instead of course.

If nothing was found, it returns C<undef>, but if this method is called in object context, such as chaining, then a L<null object|Module::Generic::Null> will be returned instead to prevent a hard perl error.

For example, assuming no L<field object|DB::Object::Fields::Field> could be found, the call below would normally return an error that C<name> cannot be called on an undefined value, but here it detects the call is in an object context and returns L<null object|Module::Generic::Null> allowing a fake C<name> method to be called and that will return C<undef>

    $el->fo->name;

Once found the value is cached, so if called many times, there is no performance penalty.

=head2 format

Sets or gets the element formatting. This is used for insert statements.

It returns a L<scalar object|Module::Generic::Scalar>

=head2 generic

Returns a string representing the element with placeholder. This does not mean this element is using a placeholder, but rather provides a generic representation to be used when binding data to it.

The string returned is an object of L<Module::Generic::Scalar>

=head2 index

Sets or gets the placeholder index position.

This is used if this element represents a placeholder and it is a numbered one, such as C<$1>, C<$2>, or C<?1>, C<?2> depending on what the driver supports.

Returns the current value, which is by default C<undef>, or a L<Module::Generic::Number> object.

=head2 is_numbered

Read-only. Returns true (C<1>) if the element represent a placeholder and it is a numbered one, such as C<$1>, C<$2>, or C<?1>, C<?2> depending on what the driver supports, or false (C<0>) otherwise.

=head2 placeholder

Sets or gets the element placeholder, such as C<?>, or C<$1>, C<$2>, or C<?1>, C<?2> depending on what the driver supports.

When a value is set, it will check if this is a numbered placeholder and set the value for L</index> accordingly.

=head2 query_object

Sets or gets the L<DB::Object::Query> object set for this object.

=head2 type

Sets or gets the field SQL type.

Returns a L<scalar object|Module::Generic::Scalar> object.

=head2 value

Sets or gets the element value.

Returns a L<scalar object|Module::Generic::Scalar> object.

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

L<perl>

=head1 COPYRIGHT & LICENSE

Copyright(c) 2023 DEGUEST Pte. Ltd.

All rights reserved
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
