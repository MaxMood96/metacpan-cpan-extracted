# [[[ HEADER ]]]
package Perl::Type::Number;
use strict;
use warnings;
use Perl::Config;  # don't use Perl::Types inside itself, in order to avoid circular includes
our $VERSION = 0.014_100;

# [[[ OO INHERITANCE ]]]
use parent qw(Perl::Type::Scalar);
use Perl::Type::Scalar;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(Capitalization ProhibitMultiplePackages ProhibitReusedNames)  # SYSTEM DEFAULT 3: allow multiple & lower case package names

# [[[ SUB-TYPES ]]]
# DEV NOTE, CORRELATION #rp007:
# a number is any numeric value, meaning either an integer or a floating-point number;
# Boolean, Nonsigned Integer, and Integer are all sub-classes of Number;
# the hidden Perl semantics are SvIOKp() for ints, and SvNOKp() for numbers;
# these numbers appear to act as C doubles and are implemented as such in RPerl;
# in the future, this can be optimized (for at least memory usage) by implementing full Float semantics
package number;
use strict;
use warnings;
use parent qw(Perl::Type::Number);

package constant_number;
use strict;
use warnings;
use parent qw(Perl::Type::Number);

# [[[ SWITCH CONTEXT BACK TO PRIMARY PACKAGE ]]]
package Perl::Type::Number;
use strict;
use warnings;

# [[[ INCLUDES ]]]
use POSIX qw(floor);

# [[[ EXPORTS ]]]
use Exporter 'import';
our @EXPORT = qw(number_CHECK number_CHECKTRACE number_to_boolean number_to_nonsigned_integer number_to_integer number_to_character number_to_string);
our @EXPORT_OK = qw(number_typetest0 number_typetest1);

# [[[ TYPE-CHECKING ]]]
sub number_CHECK {
    { my void $RETURN_TYPE };
    ( my $possible_number ) = @ARG;
    if ( not( defined $possible_number ) ) {
#        croak( "\nERROR ENV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but undefined/null value found,\ncroaking" );
        die( "\nERROR ENV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but undefined/null value found,\ndying\n" );
    }
    if (not(   main::PerlTypes_SvNOKp($possible_number)
            || main::PerlTypes_SvIOKp($possible_number) ) )
    {
#        croak( "\nERROR ENV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but non-number value found,\ncroaking" );
        die( "\nERROR ENV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but non-number value found,\ndying\n" );
    }
    return;
}
sub number_CHECKTRACE {
    { my void $RETURN_TYPE };
    ( my $possible_number, my $variable_name, my $subroutine_name ) = @ARG;
    if ( not( defined $possible_number ) ) {
#        croak( "\nERROR ENV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but undefined/null value found,\nin variable $variable_name from subroutine $subroutine_name,\ncroaking" );
        die( "\nERROR ENV00, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but undefined/null value found,\nin variable $variable_name from subroutine $subroutine_name,\ndying\n" );
    }
    if (not(   main::PerlTypes_SvNOKp($possible_number)
            || main::PerlTypes_SvIOKp($possible_number) )
        )
    {
#        croak( "\nERROR ENV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but non-number value found,\nin variable $variable_name from subroutine $subroutine_name,\ncroaking" );
        die( "\nERROR ENV01, TYPE-CHECKING MISMATCH, PERLOPS_PERLTYPES:\nnumber value expected but non-number value found,\nin variable $variable_name from subroutine $subroutine_name,\ndying\n" );
    }
    return;
}

# [[[ BOOLEANIFY ]]]
sub number_to_boolean {
    { my boolean $RETURN_TYPE };
    (my number $input_number) = @ARG;
#    number_CHECK($input_number);
    number_CHECKTRACE( $input_number, '$input_number', 'number_to_boolean()' );
    if ($input_number == 0) { return 0; }
    else { return 1; }
    return;
}

# [[[ UNSIGNED INTEGERIFY ]]]
sub number_to_nonsigned_integer {
    { my nonsigned_integer $RETURN_TYPE };
    (my number $input_number) = @ARG;
#    number_CHECK($input_number);
    number_CHECKTRACE( $input_number, '$input_number', 'number_to_nonsigned_integer()' );
    return floor(abs $input_number);
}

# [[[ INTEGERIFY ]]]
sub number_to_integer {
    { my integer $RETURN_TYPE };
    (my number $input_number) = @ARG;
#    number_CHECK($input_number);
    number_CHECKTRACE( $input_number, '$input_number', 'number_to_integer()' );
    return floor($input_number);
}

# [[[ CHARACTERIFY ]]]
sub number_to_character {
    { my character $RETURN_TYPE };
    (my number $input_number) = @ARG;
#    number_CHECK($input_number);
    number_CHECKTRACE( $input_number, '$input_number', 'number_to_character()' );
    my string $tmp_string = number_to_string($input_number);
    if ($tmp_string eq q{}) { return q{}; }
    else { return (substr $tmp_string, 0, 1); }
}

# [[[ STRINGIFY ]]]
sub number_to_string {
    { my string $RETURN_TYPE };
    { my string $RETURN_TYPE };
    ( my number $input_number ) = @ARG;
#    number_CHECK($input_number);
    number_CHECKTRACE( $input_number, '$input_number', 'number_to_string()' );

#    Perl::diag("in PERLOPS_PERLTYPES number_to_string(), received \$input_number = $input_number\n");
#    Perl::diag("in PERLOPS_PERLTYPES number_to_string()...\n");
#    die 'TMP DEBUG';

    # DEV NOTE: disable old stringify w/out underscores
#    return "$input_number";

    # NEED FIX: if using RPerl data types here, causes errors for `perl -e 'use Perl::Type::Integer;'`
    my integer $is_negative = 0;
#    my $is_negative = 0;
    if ($input_number < 0) { $is_negative = 1; }
    my string $retval;
#    my $retval;
    my $split_parts = [ split /[.]/xms, "$input_number" ];   # arrayref::string

    if ( exists $split_parts->[0] ) {
        $retval = reverse $split_parts->[0];
        if ($is_negative) { chop $retval; }  # remove negative sign
        $retval =~ s/(\d{3})/$1_/gxms;
        if ((substr $retval, -1, 1) eq '_') { chop $retval; }
        $retval = reverse $retval;
    }
    else {
        $retval = '0';
    }

    if ( exists $split_parts->[1] ) {
        $split_parts->[1] =~ s/(\d{3})/$1_/gxms;
        if ((substr $split_parts->[1], -1, 1) eq '_') { chop $split_parts->[1]; }
#        if ((substr $split_parts->[1], 0, 1) eq '_') { chop $split_parts->[1]; }  # should not be necessary
        $retval .= '.' . $split_parts->[1];
    }

    if ($is_negative) { $retval = q{-} . $retval; }

#    Perl::diag('in PERLOPS_PERLTYPES number_to_string(), have $retval = ' . q{'} . $retval . q{'} . "\n");
    return $retval;
}

# [[[ TYPE TESTING ]]]
sub number_typetest0 {
    { my number $RETURN_TYPE };
    my number $retval
        = ( 22 / 7 ) + main::Perl__Type__Number__MODE_ID(); # return floating-point number value

#    Perl::diag("in PERLOPS_PERLTYPES number_typetest0(), have \$retval = $retval\n");
    return $retval;
}
sub number_typetest1 {
    { my number $RETURN_TYPE };
    ( my number $lucky_number ) = @ARG;
#    number_CHECK($lucky_number);
    number_CHECKTRACE( $lucky_number, '$lucky_number',
        'number_typetest1()' );

#    Perl::diag('in PERLOPS_PERLTYPES number_typetest1(), received $lucky_number = ' . number_to_string($lucky_number) . "\n");
    return ( ( $lucky_number * 2 ) + main::Perl__Type__Number__MODE_ID() );
}

# DEV NOTE, CORRELATION #rp018: Perl::Type::*.pm files do not 'use RPerl;' and thus do not trigger the pseudo-source-filter contained in
# RPerl::CompileUnit::Module::Class::create_symtab_entries_and_accessors_mutators(),
# so *__MODE_ID() subroutines are hard-coded here instead of auto-generated there
package main;
use strict;
use warnings;
sub Perl__Type__Number__MODE_ID { return 0; }

1;  # end of class
