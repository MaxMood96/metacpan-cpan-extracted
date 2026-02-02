package
    object;
use strict;
use warnings;
our $VERSION = '0.14';
require XSLoader;
XSLoader::load('object', $VERSION);
1;

__END__

=head1 NAME

object - objects with prototype chains

=head1 SYNOPSIS

    use object;
    
    # Define class properties (compile time)
    object::define('Cat', qw(name age));
    
    # Positional constructor - fastest
    my $cat = new Cat 'Whiskers', 3;
    
    # Named pairs constructor
    my $cat = new Cat name => 'Whiskers', age => 3;
    
    # Accessors - compiled to custom ops
    print $cat->name;        # getter
    $cat->age(4);            # setter
    
    # Package methods work normally
    package Cat;
    sub speak { my $self = shift; "Meow! I am " . $self->name }
    
    package main;
    print $cat->speak;       # "Meow! I am Whiskers"
    print $cat->isa('Cat');  # true
    
    # Prototype chain
    my $proto = $cat->prototype;
    $cat->set_prototype($other);
    
    # Mutability controls
    $cat->lock;              # Prevent new properties
    $cat->unlock;            # Allow new properties again  
    $cat->freeze;            # Permanent immutability
    $cat->is_frozen;         # Check frozen state

=head1 DESCRIPTION

C<object> provides an alternative to C<bless> with prototype chains. 
Objects are stored as arrays (not hashes) for speed, with property names 
mapped to slot indices at compile time.

Objects are properly blessed into their class, so C<isa>, C<can>, and
custom package methods all work as expected.

=head1 FUNCTIONS

=head2 object::define($class, @properties)

Define properties for a class at compile time. This assigns slot indices
and installs accessor methods. Must be called before using C<new>.

    object::define('Cat', qw(name age color));

Property names can include type constraints, defaults, and modifiers
using the colon-separated format:

    object::define('Person',
        'name:Str:required',           # Must provide name in new()
        'age:Int:default(0)',          # Integer with default 0
        'email:Str',                   # Optional string
        'id:Str:required:readonly',    # Required, immutable after new()
        'tags:ArrayRef:default([])',   # Fresh empty array per object
    );

=head3 Built-in Types

The following types are available with inline checks (zero overhead):

=over 4

=item * B<Any> - accepts any value

=item * B<Defined> - must be defined (not undef)

=item * B<Str> - defined non-reference

=item * B<Int> - integer value

=item * B<Num> - numeric value

=item * B<Bool> - boolean (0, 1, or empty string)

=item * B<ArrayRef> - array reference

=item * B<HashRef> - hash reference

=item * B<CodeRef> - code reference

=item * B<Object> - blessed reference

=back

=head3 Modifiers

=over 4

=item * B<required> - must be provided in new()

=item * B<readonly> - setter disabled after construction

=item * B<default(value)> - default value if not provided

=back

Default values support:

    default(0)         # integer
    default(1.5)       # number  
    default(text)      # unquoted string
    default('text')    # quoted string
    default([])        # fresh empty array per object
    default({})        # fresh empty hash per object
    default(undef)     # explicit undef

=head2 object::register_type($name, $check, $coerce)

Register a custom type for use in slot specifications.

    # Simple check
    object::register_type('PositiveInt', sub {
        my $val = shift;
        return $val =~ /^\d+$/ && $val > 0;
    });
    
    # With coercion
    object::register_type('TrimmedStr', 
        sub { defined $_[0] && !ref $_[0] },  # check
        sub { my $v = shift; $v =~ s/^\s+|\s+$//g; $v }  # coerce
    );
    
    # Now use in define
    object::define('Counter',
        'value:PositiveInt',
        'label:TrimmedStr',
    );

=head2 object::has_type($name)

Returns true if a type is registered (built-in or custom).

    if (object::has_type('Email')) { ... }

=head2 object::list_types()

Returns arrayref of all registered type names.

    my $types = object::list_types();
    # ['Any', 'Defined', 'Str', 'Int', ... 'PositiveInt']

=head2 XS-Level Type Registration (for XS modules)

External XS modules can register types with C-level check functions
that bypass Perl callback overhead entirely (~5 cycles vs ~100 cycles).

=head3 C API Reference

Include C<object_types.h> in your XS module:

    #include "object_types.h"

=head4 object_register_type_xs

    void object_register_type_xs(pTHX_ const char *name,
                                 ObjectTypeCheckFunc check,
                                 ObjectTypeCoerceFunc coerce);

Register a type with C-level check and optional coercion functions.
Call from your BOOT section. The type name can then be used in
C<object::define()> slot specifications.

Parameters:

=over 4

=item * C<name> - Type name (e.g., "PositiveInt", "Email")

=item * C<check> - C function to validate values (required)

=item * C<coerce> - C function to coerce values (optional, pass NULL)

=back

=head4 ObjectTypeCheckFunc

    typedef bool (*ObjectTypeCheckFunc)(pTHX_ SV *val);

Type check function signature. Return true if value passes the check.

=head4 ObjectTypeCoerceFunc

    typedef SV* (*ObjectTypeCoerceFunc)(pTHX_ SV *val);

Type coercion function signature. Return the coerced value (may be
the same SV or a new mortal). Return NULL if coercion fails.

=head4 object_get_registered_type

    RegisteredType* object_get_registered_type(pTHX_ const char *name);

Look up a registered type by name. Returns NULL if not found.
Useful for introspection or chaining type checks.

=head3 Complete Example

    /* MyTypes.xs */
    #define PERL_NO_GET_CONTEXT
    #include "EXTERN.h"
    #include "perl.h"
    #include "XSUB.h"
    #include "object_types.h"
    
    static bool check_positive_int(pTHX_ SV *val) {
        if (!SvIOK(val) && !(SvPOK(val) && looks_like_number(val)))
            return false;
        return SvIV(val) > 0;
    }
    
    static bool check_email(pTHX_ SV *val) {
        if (SvROK(val)) return false;
        STRLEN len;
        const char *pv = SvPV(val, len);
        const char *at = memchr(pv, '@', len);
        return at && at != pv && at != pv + len - 1;
    }
    
    static SV* coerce_trim(pTHX_ SV *val) {
        STRLEN len;
        const char *pv = SvPV(val, len);
        const char *start = pv;
        const char *end = pv + len;
        while (start < end && isSPACE(*start)) start++;
        while (end > start && isSPACE(*(end-1))) end--;
        return sv_2mortal(newSVpvn(start, end - start));
    }
    
    MODULE = MyTypes  PACKAGE = MyTypes
    
    BOOT:
        object_register_type_xs(aTHX_ "PositiveInt", check_positive_int, NULL);
        object_register_type_xs(aTHX_ "Email", check_email, NULL);
        object_register_type_xs(aTHX_ "TrimmedStr", NULL, coerce_trim);

Usage in Perl:

    use MyTypes;  # Registers types in BOOT
    use object;
    
    object::define('User',
        'id:PositiveInt:required',
        'email:Email',
        'bio:TrimmedStr',
    );
    
    my $user = new User id => 42, email => 'user@example.com';

=head3 Performance Tiers

    Type Source               Check Cost    Total Overhead
    --------------------------------------------------------
    Built-in (Str, Int)       ~0 cycles     inline switch
    Registered C function     ~5 cycles     function pointer
    Perl callback             ~100 cycles   call_sv overhead

=head3 Linking

Your XS module needs to link against the object module. The functions
are exported with C<PERL_CALLCONV> visibility.

=head2 new $class @args

Create a new object. Supports positional or named arguments.

    my $cat = new Cat 'Whiskers', 3;           # positional
    my $cat = new Cat name => 'Whiskers';      # named

=head2 $obj->prototype

Get the prototype object (or undef if none).

=head2 $obj->set_prototype($proto)

Set the prototype object. Fails if object is frozen.

=head2 $obj->lock

Prevent adding new properties. Can be unlocked.

=head2 $obj->unlock

Allow adding new properties again. Fails if frozen.

=head2 $obj->freeze

Permanently prevent modifications. Cannot be undone.

=head2 $obj->is_frozen

Returns true if object is frozen.

=head2 $obj->is_locked

Returns true if object is locked (but may not be frozen).

=head2 object::import_accessors($class, $target)

Import function-style accessors for maximum performance. This enables
calling accessors as C<name $obj> instead of C<$obj-E<gt>name>, which
avoids method dispatch overhead.

    # In a BEGIN block so call checker sees the functions
    BEGIN {
        use object;
        object::define('Cat', qw(name age));
        object::import_accessors('Cat');  # imports to current package
    }
    
    my $cat = new Cat 'Whiskers', 3;
    
    # Function-style - 2.4x faster GET, 4x faster SET
    my $n = name $cat;
    age $cat, 4;
    
    # Method-style still works
    my $n = $cat->name;
    $cat->age(4);

The optional C<$target> parameter specifies which package to import into
(defaults to caller).

=head2 object::import_accessor($class, $prop, $alias, $target)

Import a single accessor with an optional alias name.

    BEGIN {
        use object;
        object::define('Cat', qw(name age));
        object::import_accessor('Cat', 'name', 'get_name');
        object::import_accessor('Cat', 'age', 'set_age');
    }
    
    my $cat = new Cat 'Whiskers', 3;
    my $n = get_name $cat;   # same as name($cat)
    set_age $cat, 4;         # same as age($cat, 4)

Parameters:

=over 4

=item * C<$class> - The class name

=item * C<$prop> - The property name to access

=item * C<$alias> - The function name to install (defaults to C<$prop>)

=item * C<$target> - Package to install into (defaults to caller)

=back

Function-style accessors are compiled to custom ops at compile time,
giving performance competitive with or faster than C<slot>.

=head1 PERFORMANCE COMPARISON

Method-style accessors (C<$obj-E<gt>name>):

    GET: 23-28M/s
    SET: 23-29M/s

Function-style accessors (C<name $obj>):

    GET: 63-68M/s  (22% faster than slot, 2.7x faster than method-style)
    SET: 100-175M/s (4x faster than method-style)

For comparison:

    hash->{key}:  45-74M/s
    slot:         52-59M/s GET, 149-360M/s SET

=head1 AUTHOR

LNATION E<email@lnation.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
