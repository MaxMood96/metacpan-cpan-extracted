# NAME

MooX::Tag::TO\_HASH - Controlled translation of Moo objects into Hashes

# VERSION

version 0.08

# SYNOPSIS

    package My::Farm;
    
    use Moo;
    with 'MooX::Tag::TO_HASH';
    
    has cow            => ( is => 'ro', to_hash => 1 );
    has duck           => ( is => 'ro', to_hash => 'goose,if_exists', );
    has horse          => ( is => 'ro', to_hash => ',if_defined', );
    has hen            => ( is => 'ro', to_hash => 1, );
    has secret_admirer => ( is => 'ro', );
    
    # and somewhere else...
    
    use Data::Dumper;
    my $farm = My::Farm->new(
        cow            => 'Daisy',
        duck           => 'Frank',
        secret_admirer => 'Fluffy',
    );
    
    print Dumper $farm->TO_HASH;

\# resulting in

    $VAR1 = {
              'cow' => 'Daisy',
              'goose' => 'Frank',
              'hen' => undef
            };

# DESCRIPTION

`MooX::Tag::TO_HASH` is a [Moo::Role](https://metacpan.org/pod/Moo%3A%3ARole) which provides a controlled method of converting your
[Moo](https://metacpan.org/pod/Moo) based object into a hash.

Simply mark each field that should be output with the special option
`to_hash` when declaring it:

    has field => ( is => 'ro', to_hash => 1 );

and call the ["TO\_HASH"](#to_hash) method on your instantiated object.

    my %hash = $obj->TO_HASH;

Fields inherited from superclasses or consumed from roles which use
`MooX::Tag::TO_HASH` are automatically handled.

If a field's value is a plain scalar, ["TO\_HASH"](#to_hash) leaves it unchanged.
If it is a reference, ["TO\_HASH"](#to_hash) recursively walks plain array and
hash references, and converts objects via their own `TO_HASH` method
when available. You can prevent that processing with the
`no_recurse` option.

## Modifying the generated hash

\[Originally, this module recommended using a method modifier to the
[TO\_HASH](https://metacpan.org/pod/TO_HASH) method, this is no longer recommended. See discussion
under ["DEPRECATED BEHAVIOR"](#deprecated-behavior) below.\].

If the class provides a `_modify_hashr` method (or for backwards
compatibility, `modify_hashr`), it will be called as

    $self->_modify_hashr( \%hash );

and should modify the passed hash in place.

## Usage

Add the `to_hash` option to each field which should be
included in the hash.  `to_hash` can either take a value of `1`,
e.g.

    has field => ( is => 'ro', to_hash => 1 );

or a string which looks like one of these:

    alternate_name
    alternate_name,option_flag,option_flag,...
    ,option_flag,option_flag,...

If `alternate_name` is specified, that'll be the key used in the
output hash.

`option_flag` may be one of the following:

- `if_exists`

    Only output the field if it was set. This uses ["Moo"](#moo)'s attribute
    predicate (one will be added to the field if it not already
    specified).

    It _will_ be output if the field is set to `undef`.

    A synonym for this is `omit_if_empty`, for compatibility with
    [MooX::TO\_JSON](https://metacpan.org/pod/MooX%3A%3ATO_JSON).

- `if_defined`

    Only output the field if it was set and its value is defined.

- `no_recurse`

    Do not recursively process the field value. Objects are left as-is
    instead of being converted via `TO_HASH`, and plain array and hash
    references are not walked for nested objects or other nested
    containers.

    (Yes, this name is backwards, but eventually a separate `recurse`
    option may become available which limits the recursion depth).

# METHODS

## TO\_HASH

    %hash = $obj->TO_HASH

This method is added to the consuming class or role.

# EXAMPLES

## Modifying the generated hash

    package My::Test::C4;
    
    use Moo;
    with 'MooX::Tag::TO_HASH';
    
    has cow            => ( is => 'ro', to_hash => 1 );
    has duck           => ( is => 'ro', to_hash => 'goose,if_exists', );
    has horse          => ( is => 'ro', to_hash => ',if_defined', );
    has hen            => ( is => 'ro', to_hash => 1, );
    has secret_admirer => ( is => 'ro', );
    
    # upper case the hash keys
    sub modify_hashr {
        my ( $self, $hashr ) = @_;
        $hashr->{ uc $_ } = delete $hashr->{$_} for keys %$hashr;
    };
    
    # and elsewhere:
    use Data::Dumper;
    
    print Dumper(
        My::Test::C4->new(
            cow            => 'Daisy',
            hen            => 'Ruby',
            duck           => 'Donald',
            horse          => 'Ed',
            secret_admirer => 'Nemo'
        )->TO_HASH
    );

\# resulting in

    $VAR1 = {
              'HORSE' => 'Ed',
              'HEN' => 'Ruby',
              'GOOSE' => 'Donald',
              'COW' => 'Daisy'
            };

# DEPRECATED BEHAVIOR

## Using method modifiers to modify the results

Previously it was suggested that the `around` method modifier be used
to modify the resultant hash. However, if both a child and parent
class consume the `MooX::Tag::TO_HASH` role and the parent has
modified `TO_HASH`, the parent's modified `TO_HASH` will not be run;
instead the original `TO_HASH` will. For example

    package Role {
        use Moo::Role;
        sub foo { print "Role\n" }
    }
    
    package Parent {
        use Moo;
        with 'Role';
        before 'foo' => sub { print "Parent\n" };
    }
    
    package Child {
        use Moo;
        extends 'Parent';
        with 'Role';
        before 'foo' => sub { print "Child\n" };
    }
    
    Child->new->foo;

results in

    Child
    Role

Note it does not output `Parent`.

# SUPPORT

## Bugs

Please report any bugs or feature requests to bug-moox-tag-to\_hash@rt.cpan.org  or through the web interface at: [https://rt.cpan.org/Public/Dist/Display.html?Name=MooX-Tag-TO\_HASH](https://rt.cpan.org/Public/Dist/Display.html?Name=MooX-Tag-TO_HASH)

## Source

Source is available at

    https://codeberg.org/djerius/p5-MooX-Tag-TO_HASH

and may be cloned from

    https://codeberg.org/djerius/p5-MooX-Tag-TO_HASH.git

# SEE ALSO

Please see those modules/websites for more information related to this module.

- [MooX::Tag::TO\_JSON - the sibling class to this one.](https://metacpan.org/pod/MooX%3A%3ATag%3A%3ATO_JSON%20-%20the%20sibling%20class%20to%20this%20one.)
- [MooX::TO\_JSON - this is similar, but doesn't handle fields inherited from super classes or consumed from roles.](https://metacpan.org/pod/MooX%3A%3ATO_JSON%20-%20this%20is%20similar%2C%20but%20doesn%27t%20handle%20fields%20inherited%20from%20super%20classes%20or%20consumed%20from%20roles.)

# AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

    The GNU General Public License, Version 3, June 2007
