# [[[ HEADER ]]]
package Perl::Type::GMPInteger;
use strict;
use warnings;
use Perl::Config;  # don't use Perl::Types inside itself, in order to avoid circular includes
our $VERSION = 0.006_000;

# [[[ OO INHERITANCE ]]]
#use parent qw(Math::BigInt Perl::Type::Scalar);  # NEED UPGRADE, CORRELATION #rp023: Inline::CPP support for multiple inheritance
use parent qw(Math::BigInt);
use Math::BigInt lib => 'GMP';    # we still actually use GMP in PERLOPS_PERLTYPES mode, albeit indirectly via Math::BigInt::GMP
use Perl::Type::Scalar;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(Capitalization ProhibitMultiplePackages ProhibitReusedNames)  # SYSTEM DEFAULT 3: allow multiple & lower case package names

# [[[ SUB-TYPES ]]]
# a gmp_integer is multi-precision integer using the GMP library
package gmp_integer;
use strict;
use warnings;
use parent qw(Perl::Type::GMPInteger);

# [[[ SWITCH CONTEXT BACK TO PRIMARY PACKAGE ]]]
package Perl::Type::GMPInteger;
use strict;
use warnings;

# [[[ INCLUDES ]]]
# for type-checking via PerlTypes_SvHROKp(); inside INIT to delay until after 'use MyConfig';
# NEED ADDRESS: INIT disabled due to warning "too late to run INIT block", do we need it any more?
#INIT {
use Perl::HelperFunctions_cpp;
Perl::HelperFunctions_cpp::cpp_load();

#}
#use RPerl::Operation::Expression::Operator::GMPFunctions;  # NEED UPDATE, RPERL REFACTOR

# [[[ EXPORTS ]]]
use Exporter 'import';
our @EXPORT = qw(
    gmp_integer_CHECK gmp_integer_CHECKTRACE
    gmp_integer_to_boolean gmp_integer_to_nonsigned_integer gmp_integer_to_integer gmp_integer_to_number gmp_integer_to_character gmp_integer_to_string
    boolean_to_gmp_integer integer_to_gmp_integer nonsigned_integer_to_gmp_integer number_to_gmp_integer character_to_gmp_integer string_to_gmp_integer
);
our @EXPORT_OK = qw(gmp_integer_typetest0 gmp_integer_typetest1);

# DEV NOTE: never call Math::BigInt->new() without arg, to avoid 'Use of uninitialized value in new' introduced in M::BI v1.999712
sub new {
    { my gmp_integer $RETURN_TYPE };
    ( my string $class, my number $input ) = @ARG;
    if   ( defined $input ) { return Math::BigInt::new( 'gmp_integer', $input ); }
    else                    { return Math::BigInt::new( 'gmp_integer', 0 ); }
    return;
}

# [[[ TYPE-CHECKING ]]]
sub gmp_integer_CHECK {
    { my void $RETURN_TYPE };
    ( my $possible_gmp_integer ) = @ARG;

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_CHECK(), top of subroutine\n");
    if ( not( defined $possible_gmp_integer ) ) {
#        croak( "\nERROR EMPV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but undefined/null value found,\ncroaking" );
        die( "\nERROR EMPV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but undefined/null value found,\ndying\n" );
    }
    if ( not( main::PerlTypes_SvHROKp($possible_gmp_integer) ) ) {
#        croak("\nERROR EMPV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-hashref value found,\ncroaking");
        die("\nERROR EMPV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-hashref value found,\ndying\n");
    }
    my string $classname = main::class($possible_gmp_integer);
    if ( not defined $classname ) {
#        croak( "\nERROR EMPV02, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-object (blessed hashref) value found,\ncroaking" );
        die( "\nERROR EMPV02, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-object (blessed hashref) value found,\ndying\n" );
    }
    if ( not( UNIVERSAL::isa( $possible_gmp_integer, 'Math::BigInt' ) ) ) {
#        croak( "\nERROR EMPV03, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-Math::BigInt-derived object value found,\ncroaking" );
        die( "\nERROR EMPV03, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-Math::BigInt-derived object value found,\ndying\n" );
    }
    if ( $classname ne 'gmp_integer' ) {
#        croak( "\nERROR EMPV04, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-gmp_integer object value found,\ncroaking" );
        die( "\nERROR EMPV04, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-gmp_integer object value found,\ndying" );
    }
    if ( not exists $possible_gmp_integer->{value} ) {
#        croak( "\nERROR EMPV05, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry exists,\ncroaking" );
        die( "\nERROR EMPV05, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry exists,\ndying\n" );
    }
    if ( not defined $possible_gmp_integer->{value} ) {
#        croak( "\nERROR EMPV06, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry defined;\nOR\nERROR EMPV07, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but undefined/null value found,\ncroaking" );
        die( "\nERROR EMPV06, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry defined;\nOR\nERROR EMPV07, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but undefined/null value found,\ndying\n" );
    }
    if ( not defined main::class( $possible_gmp_integer->{value} ) ) {
#        croak( "\nERROR EMPV08, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-object (blessed hashref) value found,\ncroaking" );
        die( "\nERROR EMPV08, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-object (blessed hashref) value found,\ndying\n" );
    }
    if ( not( UNIVERSAL::isa( $possible_gmp_integer->{value}, 'Math::BigInt::GMP' ) ) ) {
#        croak( "\nERROR EMPV09, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-Math::BigInt::GMP object value found,\ncroaking" );
        die( "\nERROR EMPV09, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-Math::BigInt::GMP object value found,\ndying\n" );
    }

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_CHECK(), bottom of subroutine\n");
    return;
}

sub gmp_integer_CHECKTRACE {
    { my void $RETURN_TYPE };
    ( my $possible_gmp_integer, my $variable_name, my $subroutine_name ) = @ARG;

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_CHECKTRACE(), top of subroutine\n");
    if ( not( defined $possible_gmp_integer ) ) {
#        croak( "\nERROR EMPV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but undefined/null value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but undefined/null value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not( main::PerlTypes_SvHROKp($possible_gmp_integer) ) ) {
#        croak( "\nERROR EMPV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-hashref value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-hashref value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    my string $classname = main::class($possible_gmp_integer);
    if ( not defined $classname ) {
#        croak( "\nERROR EMPV02, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-object (blessed hashref) value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV02, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-object (blessed hashref) value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not( UNIVERSAL::isa( $possible_gmp_integer, 'Math::BigInt' ) ) ) {
#        croak( "\nERROR EMPV03, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-Math::BigInt-derived object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV03, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-Math::BigInt-derived object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( $classname ne 'gmp_integer' ) {
#        croak( "\nERROR EMPV04, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-gmp_integer object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV04, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer external wrapper value expected but non-gmp_integer object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not exists $possible_gmp_integer->{value} ) {
#        croak( "\nERROR EMPV05, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry exists,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV05, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry exists,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not defined $possible_gmp_integer->{value} ) {
#        croak( "\nERROR EMPV06, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry defined;\nOR\nERROR EMPV07, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but undefined/null value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV06, MISSING HASH ENTRY, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped object in hash entry expected at key 'value' but no hash entry defined;\nOR\nERROR EMPV07, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but undefined/null value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not defined main::class( $possible_gmp_integer->{value} ) ) {
#        croak( "\nERROR EMPV08, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-object (blessed hashref) value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV08, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-object (blessed hashref) value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }
    if ( not( UNIVERSAL::isa( $possible_gmp_integer->{value}, 'Math::BigInt::GMP' ) ) ) {
#        croak( "\nERROR EMPV09, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-Math::BigInt::GMP object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ncroaking" );
        die( "\nERROR EMPV09, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\ngmp_integer internal wrapped value expected but non-Math::BigInt::GMP object value found,\nin variable " . $variable_name . " from subroutine " . $subroutine_name . ",\ndying\n" );
    }

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_CHECKTRACE(), bottom of subroutine\n");
    return;
}

# [[[ BOOLEANIFY ]]]
sub gmp_integer_to_boolean {
    { my boolean $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_boolean()' );
    if ( gmp_get_signed_integer($input_gmp_integer) == 0 ) { return 0; }    # DEV NOTE: this one matches the C++ code more closely

    #    if   ( $input_gmp_integer->is_zero() ) { return 0; }  # but this one may be faster?
    else { return 1; }
    return;
}

# [[[ UNSIGNED INTEGERIFY ]]]
sub gmp_integer_to_nonsigned_integer {
    { my nonsigned_integer $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_nonsigned_integer()' );
    return (abs $input_gmp_integer->numify());
}

# [[[ INTEGERIFY ]]]
sub gmp_integer_to_integer {
    { my integer $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_integer()' );
    return $input_gmp_integer->numify();
}

# [[[ NUMBERIFY ]]]
sub gmp_integer_to_number {
    { my number $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_number()' );
    return ($input_gmp_integer->numify() * 1.0);
}

# [[[ CHARACTERIFY ]]]
sub gmp_integer_to_character {
    { my character $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_character()' );
    my string $tmp_string = gmp_integer_to_string($input_gmp_integer);
    if   ( $tmp_string eq q{} ) { return q{}; }
    else                        { return (substr $tmp_string, 0, 1); }
    return;
}

# [[[ STRINGIFY ]]]
sub gmp_integer_to_string {
    { my string $RETURN_TYPE };
    ( my gmp_integer $input_gmp_integer ) = @ARG;

    #    gmp_integer_CHECK($input_gmp_integer);
    gmp_integer_CHECKTRACE( $input_gmp_integer, '$input_gmp_integer', 'gmp_integer_to_string()' );

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_to_string(), received \$input_gmp_integer = $input_gmp_integer\n");

    my integer $is_negative = $input_gmp_integer->is_neg();
    my string $retval       = reverse $input_gmp_integer->bstr();
    if ($is_negative) { chop $retval; }    # remove negative sign
    $retval =~ s/(\d{3})/$1_/gxms;
    if ( ( substr $retval, -1, 1 ) eq '_' ) { chop $retval; }
    $retval = reverse $retval;

    if ($is_negative) { $retval = q{-} . $retval; }

    #    Perl::diag('in PERLOPS_PERLTYPES gmp_integer_to_string(), have $retval = ' . q{'} . $retval . q{'} . "\n");
    return $retval;
}

# [[[ GMP INTEGERIFY ]]]
# DEV NOTE: keep all these *_to_gmp_integer() conversion subroutines here instead of spread throughout the other Perl/Type/*.pm files,
# so that loading will all be controlled by the 'use perlgmp;' directive

sub boolean_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my boolean $input_boolean ) = @ARG;

    #    ::boolean_CHECK($input_boolean);
    ::boolean_CHECKTRACE( $input_boolean, '$input_boolean', 'boolean_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new($input_boolean);
    return $output_gmp_integer;
}

sub integer_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my integer $input_integer ) = @ARG;

    #    ::integer_CHECK($input_integer);
    ::integer_CHECKTRACE( $input_integer, '$input_integer', 'integer_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new($input_integer);
    return $output_gmp_integer;
}

sub nonsigned_integer_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my nonsigned_integer $input_nonsigned_integer ) = @ARG;

    #    ::nonsigned_integer_CHECK($input_nonsigned_integer);
    ::nonsigned_integer_CHECKTRACE( $input_nonsigned_integer, '$input_nonsigned_integer', 'nonsigned_integer_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new($input_nonsigned_integer);
    return $output_gmp_integer;
}

sub number_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my number $input_number ) = @ARG;

    #    ::number_CHECK($input_number);
    ::number_CHECKTRACE( $input_number, '$input_number', 'number_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new( number_to_integer($input_number) );
    return $output_gmp_integer;
}

sub character_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my character $input_character ) = @ARG;

    #    ::character_CHECK($input_character);
    ::character_CHECKTRACE( $input_character, '$input_character', 'character_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new( character_to_integer($input_character) );
    return $output_gmp_integer;
}

sub string_to_gmp_integer {
    { my gmp_integer $RETURN_TYPE };
    ( my string $input_string ) = @ARG;

    #    ::string_CHECK($input_string);
    ::string_CHECKTRACE( $input_string, '$input_string', 'string_to_gmp_integer()' );
    my gmp_integer $output_gmp_integer = gmp_integer->new( string_to_integer($input_string) );
    return $output_gmp_integer;
}

# [[[ TYPE TESTING ]]]
sub gmp_integer_typetest0 {
    { my gmp_integer $RETURN_TYPE };
    my gmp_integer $retval = ( 21 / 7 ) + main::Perl__Type__Integer__MODE_ID();    # return gmp_integer (not number) value, don't do (22 / 7) etc.

    #    Perl::diag("in PERLOPS_PERLTYPES gmp_integer_typetest0(), have \$retval = $retval\n");
    return $retval;
}
sub gmp_integer_typetest1 {
    { my gmp_integer $RETURN_TYPE };
    ( my gmp_integer $lucky_gmp_integer ) = @ARG;

    #    ::gmp_integer_CHECK($lucky_gmp_integer);
    ::gmp_integer_CHECKTRACE( $lucky_gmp_integer, '$lucky_gmp_integer', 'gmp_integer_typetest1()' );

    #    Perl::diag('in PERLOPS_PERLTYPES gmp_integer_typetest1(), received $lucky_gmp_integer = ' . gmp_integer_to_string($lucky_gmp_integer) . "\n");
    return ( ( $lucky_gmp_integer * 2 ) + main::Perl__Type__Integer__MODE_ID() );
}

# DEV NOTE, CORRELATION #rp018: Perl::Type::*.pm files do not 'use RPerl;' and thus do not trigger the pseudo-source-filter contained in
# RPerl::CompileUnit::Module::Class::create_symtab_entries_and_accessors_mutators(),
# so *__MODE_ID() subroutines are hard-coded here instead of auto-generated there
package main;
use strict;
use warnings;
sub Perl__Type__GMPInteger__MODE_ID { return 0; }

1;    # end of class
