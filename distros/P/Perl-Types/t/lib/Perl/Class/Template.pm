# [[[ PREPROCESSOR ]]]
# <<< CHANGE_ME: delete unused directives >>>
# <<< TYPE_CHECKING: OFF or ON or TRACE >>>
# <<< PRECOMPILE_ERROR: 'FOO' >>>
# <<< PARSE: OFF or ON >>>
# <<< PARSE_ERROR: 'FOO' >>>
# <<< GENERATE: OFF or ON >>>
# <<< GENERATE_ERROR: 'FOO' >>>
# <<< COMPILE: OFF or ON >>>
# <<< COMPILE_ERROR: 'FOO' >>>
# <<< EXECUTE: OFF or ON >>>
# <<< EXECUTE_ERROR: 'FOO' >>>
# <<< EXECUTE_SUCCESS: 'FOO' >>>
# <<< EXECUTE_SUCCESS_INTEGER_32: 'FOO' >>>
# <<< EXECUTE_SUCCESS_INTEGER_64: 'FOO' >>>
# <<< EXECUTE_SUCCESS_NUMBER_32: 'FOO' >>>
# <<< EXECUTE_SUCCESS_NUMBER_64: 'FOO' >>>

# [[[ HEADER ]]]
# <<< CHANGE_ME: replace with real class name >>>
package Perl::Class::Template;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
# <<< CHANGE_ME: leave as base class for no inheritance, or replace with real parent class name >>>
use parent qw(class);
use class;

# [[[ CRITICS ]]]
# <<< CHANGE_ME: delete unused directives >>>
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(ProhibitConstantPragma ProhibitMagicNumbers)  # USER DEFAULT 3: allow constants
## no critic qw(ProhibitExplicitStdin)  # USER DEFAULT 4: allow <STDIN> prompt
## no critic qw(RequireBriefOpen)  # USER DEFAULT 5: allow open() in perltidy-expanded code
## no critic qw(ProhibitCStyleForLoops)  # USER DEFAULT 6: allow C-style for() loop headers
## no critic qw(ProhibitParensWithBuiltins)  # USER DEFAULT 7: allow explicit parentheses for clearer order-of-operations precedence
## no critic qw(ProhibitMultiplePackages ProhibitReusedNames ProhibitPackageVars)  # USER DEFAULT 8: allow additional packages
## no critic qw(ProhibitCascadingIfElse)  # USER DEFAULT 9: allow cascading conditional chains until given-when is implemented
## no critic qw(ProhibitQuotedWordLists)  # USER DEFAULT 10: allow ('lists', 'of', 'quoted', 'literal', 'words')
## no critic qw(RequireTrailingCommas)  # USER DEFAULT 11: no trailing commas in RPerl lists

## no critic qw(ProhibitUselessNoCritic PodSpelling)  # DEVELOPER DEFAULT 1a: allow unreachable & POD-commented code, must be on line 1
## no critic qw(ProhibitUnreachableCode RequirePodSections RequirePodAtEnd)  # DEVELOPER DEFAULT 1b: allow POD & unreachable or POD-commented code, must be after line 1
## no critic qw(ProhibitStringySplit ProhibitInterpolationOfLiterals)  # DEVELOPER DEFAULT 2: allow string test values
## no critic qw(ProhibitUnusedPrivateSubroutines)  # DEVELOPER DEFAULT 3: allow uncalled subroutines

## no critic qw(ProhibitStringyEval)  # SYSTEM DEFAULT 1: allow eval()
## no critic qw(ProhibitCascadingIfElse)  # SYSTEM DEFAULT 2: allow argument-handling logic
## no critic qw(Capitalization ProhibitMultiplePackages ProhibitReusedNames)  # SYSTEM DEFAULT 3: allow multiple & lower case & mixed-case package names
## no critic qw(RequireCheckingReturnValueOfEval)  # SYSTEM DEFAULT 4: allow eval() test code blocks

## no critic qw(ProhibitBooleanGrep)  # SYSTEM SPECIAL 1: allow grep
## no critic qw(ProhibitAutoloading RequireArgUnpacking)  # SYSTEM SPECIAL 2: allow Autoload & read-only @ARG
## no critic qw(ProhibitParensWithBuiltins ProhibitNoisyQuotes)  # SYSTEM SPECIAL 3: allow auto-generated code
## no critic qw(ProhibitExcessMainComplexity)  # SYSTEM SPECIAL 4: allow complex code outside subroutines, must be on line 1
## no critic qw(ProhibitExcessComplexity)  # SYSTEM SPECIAL 5: allow complex code inside subroutines, must be after line 1
## no critic qw(ProhibitPostfixControls)  # SYSTEM SPECIAL 6: PERL CRITIC FILED ISSUE #639, not postfix foreach or if
## no critic qw(ProhibitDeepNests)  # SYSTEM SPECIAL 7: allow deeply-nested code
## no critic qw(ProhibitNoStrict)  # SYSTEM SPECIAL 8: allow no strict
## no critic qw(RequireUseStrict)  # SYSTEM SPECIAL 9: allow omitted strict
## no critic qw(RequireBriefOpen)  # SYSTEM SPECIAL 10: allow complex processing with open filehandle
## no critic qw(ProhibitBacktickOperators)  # SYSTEM SPECIAL 11: allow system command execution
## no critic qw(ProhibitCascadingIfElse)  # SYSTEM SPECIAL 12: allow complex conditional logic
## no critic qw(RequireCarping)  # SYSTEM SPECIAL 13: allow die instead of croak
## no critic qw(ProhibitAutomaticExportation)  # SYSTEM SPECIAL 14: allow global exports from Config.pm & elsewhere
## no critic qw(ProhibitPackageVars)  # SYSTEM SPECIAL 15: allow package variables for exports tests

# COMBO CRITICS
## no critic qw(ProhibitUselessNoCritic PodSpelling ProhibitExcessMainComplexity)  # DEVELOPER DEFAULT 1a: allow unreachable & POD-commented code; SYSTEM SPECIAL 4: allow complex code outside subroutines, must be on line 1

# [[[ EXPORTS ]]]
# <<< CHANGE_ME: delete for no exports, or replace with real names of subroutines (not methods) to be exported >>>
use Exporter qw(import);
our @EXPORT    = qw(pies_are_round pi_r_squared);
our @EXPORT_OK = qw(garply gorce);

# [[[ INCLUDES ]]]
# <<< CHANGE_ME: delete for no includes, or replace with real include package name(s) >>>
use Perl::Types::Test::Foo qw(ylprag ecrog);
use Perl::Types::Test::Bar;

# [[[ CONSTANTS ]]]
# <<< CHANGE_ME: delete for no constants, or replace with real constant name(s) & data >>>
use constant PI  => my number $TYPED_PI  = 3.141_59;
use constant PIE => my string $TYPED_PIE = 'pecan';

# NEED UPGRADE: constant array & hash refs not read-only as of Perl v5.20
#use constant DAYS => my arrayref::string $TYPED_DAYS
#    = [ 'Sun', 'Mon', 'Tues', 'Weds', 'Thurs', 'Fri', 'Sat' ];
#use constant HYDROGEN => my arrayref::scalartype $TYPED_HYDROGEN = [
#    my integer $TYPED_number = 1,
#    my number $TYPED_weight  = 1.007_94,
#    my string $TYPED_symbol  = 'H'
#];
#use constant TRANSCENDENTALS => my hashref::number $TYPED_TRANSCENDENTALS
#    = { pi => 3.141_59, e => 2.718_28, c => 299_792_458 };
#use constant EINSTEIN => my hashref::scalartype $TYPED_EINSTEIN = {
#    name       => my string $TYPED_name        = 'Albert Einstein',
#    birth_year => my integer $TYPED_birth_year = 1_879,
#    death_year => my integer $TYPED_death_year = 1_955
#};

# [[[ OO PROPERTIES ]]]
# <<< CHANGE_ME: replace with real property name(s) & default data >>>
our hashref $properties = {
    plugh => my integer $TYPED_plugh         = 23,
    xyzzy => my string $TYPED_xyzzy          = 'twenty-three',
    thub  => my arrayref::integer $TYPED_thub = undef,                    # no  initial size, no  initial values 
    thud  => my arrayref::integer $TYPED_thud = [ 2, 4, 6, 8 ],           # no  initial size, yes initial values
    thuj  => my arrayref::integer $TYPED_thuj->[4 - 1] = undef,           # yes initial size, no  initial values
    thuv  => my arrayref::integer $TYPED_thuv->[4 - 1] = [ 2, 4, 6, 8 ],  # yes initial size, yes initial values; NEED ANSWER, DOES THIS CURRENTLY WORK???
    yyx   => my hashref::number $TYPED_yyx = undef,
    yyz   => my hashref::number $TYPED_yyz = { a => 3.1, b => 6.2, c => 9.3 }  # NEED FIX, DOES NOT CURRENTLY WORK
};

# [[[ SUBROUTINES & OO METHODS ]]]

# <<< CHANGE_ME: delete for no subroutines/methods, or replace with real subroutine(s)/method(s) >>>
sub pies_are_round {
    { my void $RETURN_TYPE };
    print 'in pies_are_round(), having PIE() = ', PIE(), "\n";
    return;
}

sub pi_r_squared {
    { my number $RETURN_TYPE };
    ( my number $r ) = @ARG;
    my number $area = PI() * $r ** 2;
    print 'in pi_r_squared(), have $area = PI() * $r ** 2 = ', $area, "\n";
    return $area;
}

sub garply {
    { my arrayref::number $RETURN_TYPE };        
    ( my integer $garply_input, my arrayref::number $garply_array ) = @ARG;
    my integer $garply_input_size = scalar @{$garply_array};
    my integer $ungarply_size_typed = scalar @{my arrayref::integer $TYPED_ungarply = [4, 6, 8, 10]};
#    my integer $ungarply_size_untyped = scalar @{[4, 6, 8, 10]};  missing type_inner, not supported in CPPOPS_CPPTYPES
    my arrayref::number $garply_output = [
        $garply_input * $garply_array->[0],
        $garply_input * $garply_array->[1],
        $garply_input * $garply_array->[2]
    ];
    return $garply_output;
}

sub gorce {
    { my hashref::string $RETURN_TYPE };
    ( my integer $al, my number $be, my string $ga, my hashref::string $de) = @ARG;
    return {
        alpha => integer_to_string($al),
        beta  => number_to_string($be),
        gamma => $ga,
        delta => %{$de}
    };
}

sub quux {
    { my void $RETURN_TYPE };
    ( my Perl::Class::Template $self) = @ARG;
    $self->{plugh} = $self->{plugh} * 2;
    return;
}

sub quince {
    { my integer $RETURN_TYPE };
    my string $quince_def
        = '...Cydonia vulgaris ... Cydonia, a city in Crete ... [1913 Webster]';
    print $quince_def;
    return (length $quince_def);
};

sub qorge {
    { my hashref::string $RETURN_TYPE };
    ( my Perl::Class::Template $self, my integer $qorge_input ) = @ARG;
    return {
        a => $self->{xyzzy} x $qorge_input,
        b => 'howdy',
        c => q{-23.42}
    };
}

sub qaft {
    { my arrayref::Perl::Class::Template $RETURN_TYPE };
    ( my Perl::Class::Template $self, my integer $foo, my number $bar, my string $bat, my hashref::string $baz ) = @ARG;
    my arrayref::Perl::Class::Template $retval = [];
    $retval->[0] = Perl::Class::Template->new();
    $retval->[0]->{xyzzy} = 'larry';  # saint or stooge?
    $retval->[1] = Perl::Class::Template->new();
    $retval->[1]->{xyzzy} = 'curly';
    $retval->[2] = Perl::Class::Template->new();
    $retval->[2]->{xyzzy} = 'moe';
    return $retval;
}

1;    # end of class


# [[[ ADDITIONAL CLASSES ]]]
# <<< CHANGE_ME: delete for no additional classes, or replace with real classes >>>

# [[[ HEADER ]]]
# <<< CHANGE_ME: replace with real shorthand class name >>>
package  # hide from PAUSE indexing
    Template;  # SHORTHAND CLASS: child class Template is functionally equivalent to parent class Perl::Class::Template
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
# <<< CHANGE_ME: replace with real parent class name >>>
use parent qw(Perl::Class::Template);  # SHORTHAND CLASS: inherit subroutines & OO methods from parent class
require Perl::Class::Template;

# NEED ANSWER: are these parent class properties automatically inherited or do we really need to explicitly inherit as shown below???
# [[[ OO PROPERTIES ]]]
# <<< CHANGE_ME: replace with real parent class name >>>
our hashref $properties = $Perl::Class::Template;  # SHORTHAND CLASS: no additional properties, only inherit from parent class

# SHORTHAND CLASS: no additional subroutines & OO methods, only inherit from parent class

1;    # end of class


# [[[ HEADER ]]]
# <<< CHANGE_ME: replace with real class name >>>
package Perl::Class::TemplateAdditional;
use strict;
use warnings;
use types;
our $VERSION = 0.001_000;

# [[[ OO INHERITANCE ]]]
# <<< CHANGE_ME: leave as base class for no inheritance, or replace with real parent class name >>>
use parent qw(class);
use class;

# [[[ CRITICS ]]]
# <<< CHANGE_ME: delete for no directives, or add real directives >>>

# [[[ INCLUDES ]]]
# <<< CHANGE_ME: delete for no includes, or add real include package name(s) >>>

# [[[ CONSTANTS ]]]
# <<< CHANGE_ME: delete for no constants, or add real constant name(s) & data >>>

# [[[ OO PROPERTIES ]]]
# <<< CHANGE_ME: leave empty for no properties, or add real property name(s) & default data >>>
our hashref $properties = {};

# [[[ SUBROUTINES & OO METHODS ]]]
# <<< CHANGE_ME: delete for no subroutines/methods, or add real subroutine(s)/method(s) >>>

1;    # end of class
