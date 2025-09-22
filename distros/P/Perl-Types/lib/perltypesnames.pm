## no critic qw(Capitalization ProhibitMultiplePackages ProhibitReusedNames)  # SYSTEM DEFAULT 3: allow multiple & lower case package names
package  # hide from PAUSE indexing
    perlnames;
use strict;
use warnings;
use Perl::Config;
our $VERSION = 0.001_010;

1;

# DEV NOTE, CORRELATION #rp008: export name() and scope_type_name_value() to main:: namespace;
# can't achieve via Exporter due to circular dependency issue caused by Exporter in Config.pm and solved by 'require perltypes;' in Perl.pm
package main;
use perltypes;
use perltypesnamespaces;

#BEGIN { print 'in perlnames.pm, have @INC = ' . "\n" . Dumper(\@INC) . "\n"; }

use PadWalker qw(peek_my peek_our);

# NEED UPGRADE: somehow reduce duplicate code of name() and scope_type_name_value(), not easy due to PadWalker magic!
sub name {
    { my string $RETURN_TYPE };
    my unknown $input_variable_ref = \$_[0];
    my hashref $pad                = peek_my 1;    # pad my
    for my string $name ( keys %{$pad} ) {
        if ( $pad->{$name} == $input_variable_ref ) { return $name; }
    }

    $pad = peek_our 1;                             # pad our
    for my string $name ( keys %{$pad} ) {
        if ( $pad->{$name} == $input_variable_ref ) { return $name; }
    }

    my string_arrayref_arrayref $sigil_reftypes = [
        [ '$', 'SCALAR' ],
        [ '@', 'ARRAY' ],
        [ '%', 'HASH' ],
        [ '&', 'CODE' ]
    ];
    foreach my string $namespace (
        ( caller() . '::' ),
        sort keys %{ perltypesnamespaces::hash_noncore_nonperltypes() }
        )
    {
        $pad = do { no strict 'refs'; \%{$namespace} };    # pad stash
        for my string $name ( keys %{$pad} ) {
            if ( ( ref \$pad->{$name} ) ne 'GLOB' ) { next; }
            for my string_arrayref $sigil_reftype ( @{$sigil_reftypes} ) {
                my string $variable_ref
                    = *{ $pad->{$name} }{ $sigil_reftype->[1] };
                if (    ( defined $variable_ref )
                    and ( $variable_ref == $input_variable_ref ) )
                {
                    return ( $sigil_reftype->[0] . $namespace . $name );
                }
            }
        }
    }
    return '$__NO_VARIABLE_NAME_FOUND';
}

sub scope_type_name_value {
    { my string $RETURN_TYPE };
    my unknown $input_variable_ref = \$_[0];

    my string $type  = type( ${$input_variable_ref} );
    my string $value = to_string( ${$input_variable_ref} );

    my hashref $pad = peek_my 1;                        # pad my
    for my string $name ( keys %{$pad} ) {
        if ( $pad->{$name} == $input_variable_ref ) {
            return (
                'my' . q{ } . $type . q{ } . $name . q{ = } . $value . q{;} );
        }
    }

    $pad = peek_our 1;                                  # pad our
    for my string $name ( keys %{$pad} ) {
        if ( $pad->{$name} == $input_variable_ref ) {
            return (  'our' . q{ }
                    . $type . q{ }
                    . $name . q{ = }
                    . $value
                    . q{;} );
        }
    }

    my string_arrayref_arrayref $sigil_reftypes = [
        [ '$', 'SCALAR' ],
        [ '@', 'ARRAY' ],
        [ '%', 'HASH' ],
        [ '&', 'CODE' ]
    ];

    foreach my string $namespace (
        ( caller() . '::' ),
        sort keys %{ perltypesnamespaces::hash_noncore_nonperltypes() }
        )
    {
#        Perl::diag( 'in scope_type_name_value(), have $namespace = ' . $namespace . "\n" );
        $pad = do { no strict 'refs'; \%{$namespace} };    # pad stash
        for my string $name ( keys %{$pad} ) {
            if ( ( ref \$pad->{$name} ) ne 'GLOB' ) { next; }
            for my string_arrayref $sigil_reftype ( @{$sigil_reftypes} ) {
                my string $variable_ref
                    = *{ $pad->{$name} }{ $sigil_reftype->[1] };
                if (    ( defined $variable_ref )
                    and ( $variable_ref == $input_variable_ref ) )
                {
                    return (  $sigil_reftype->[0]
                            . $namespace
                            . $name . q{ = }
                            . $value
                            . q{;  # }
                            . $type );
                }
            }
        }
    }
    return $type . ' $__NO_VARIABLE_NAME_FOUND = ' . $value;
}

1;
