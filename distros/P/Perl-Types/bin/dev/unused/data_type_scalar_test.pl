#!/usr/bin/env perl
use strict;
use warnings;
use Perl::Types;
our $VERSION = 0.003_021;

## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls)  # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(ProhibitUnreachableCode RequirePodSections RequirePodAtEnd PodSpelling)  # DEVELOPER DEFAULT 1: allow unreachable & POD-commented code
## no critic qw(ProhibitStringySplit ProhibitInterpolationOfLiterals)  # DEVELOPER DEFAULT 2: allow string test values
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils

$Perl::DEBUG = 1;

# UNCOMMENT TO ENABLE PERL TYPES FOR C++ OPS
#perltypes::types_enable('PERL');

# UNCOMMENT TO ENABLE C++ TYPES FOR C++ OPS
perltypes::types_enable('CPP');

# UNCOMMENT TO ENABLE C++ OPS
use Perl::Type::Integer_cpp;  Perl::Type::Integer_cpp::cpp_load();
use Perl::Type::Number_cpp;  Perl::Type::Number_cpp::cpp_load();
use Perl::Type::String_cpp; Perl::Type::String_cpp::cpp_load();

#Perl::diag(q{in scalar_test.pl, have Perl__Type__Integer__MODE_ID() = '} . Perl__Type__Integer__MODE_ID() . "'\n");
#Perl::diag(q{in scalar_test.pl, have Perl__Type__Number__MODE_ID() = '} . Perl__Type__Number__MODE_ID() . "'\n");
#Perl::diag(q{in scalar_test.pl, have Perl__Type__String__MODE_ID() = '} . Perl__Type__String__MODE_ID() . "'\n");
Perl::diag(q{in scalar_test.pl, have main::Perl__Type__Integer__MODE_ID() = '} . main::Perl__Type__Integer__MODE_ID() . "'\n");
Perl::diag(q{in scalar_test.pl, have main::Perl__Type__Number__MODE_ID() = '} . main::Perl__Type__Number__MODE_ID() . "'\n");
Perl::diag(q{in scalar_test.pl, have main::Perl__Type__String__MODE_ID() = '} . main::Perl__Type__String__MODE_ID() . "'\n");

# use Data::Dumper() to to stringify a string
sub string_dumperify {
    { my string $RETURN_TYPE; }
    ( my string $input_string ) = @_;
        Perl::diag("in scalar_test.pl string_dumperify(), received have \$input_string =\n$input_string\n\n");
        $input_string = Dumper( [$input_string] );
        $input_string =~ s/^\s+|\s+$//xmsg;         # strip leading whitespace
        my @input_string_split = split "\n", $input_string;
        $input_string = $input_string_split[1];    # only select the data line
        return $input_string;
}

# variable declarations
my integer $integer_retval;
my number $number_retval;
my string $string_retval;
my string $my_string;
my string $dumper_string;

# loop to test for memory leaks
my integer $i_MAX = 0;  # CONSTANT
for my integer $i ( 0 .. $i_MAX ) {
    Perl::diag("in scalar_test.pl, top of for() loop $i/$i_MAX\n\n");

    # [[[ INTEGER TESTS ]]]

#    $string_retval = integer_to_string();  # TIV00; error PERLOPS EIV00, CPPOPS "Usage: integer_to_string(input_integer)"
#    $string_retval = integer_to_string(undef);  # TIV01; error EIV00
#    $string_retval = integer_to_string(3);  # TIV02
#    $string_retval = integer_to_string(-17);  # TIV03
#    $string_retval = integer_to_string(-17.3);  # TIV04; error EIV01
#    $string_retval = integer_to_string('-17.3');  # TIV05; error EIV01
#    $string_retval = integer_to_string([3]);  # TIV06; error EIV01
#    $string_retval = integer_to_string({a_key => 3});  # TIV07; error EIV01
#    $string_retval = integer_to_string(-1_234_567_890);  # TIV08
#    $string_retval = integer_to_string(-1_234_567_890_000);  # TIV09; error EIV01
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval = '$string_retval'\n");

#    $integer_retval = integer_typetest0();  # TIV10
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$integer_retval = $integer_retval\n");
    

#    $integer_retval = integer_typetest1();  # TIV20; error PERLOPS EIV00, CPPOPS "Usage: main::integer_typetest1(lucky_integer)"
#    $integer_retval = integer_typetest1(undef);  # TIV21; error EIV00
#    $integer_retval = integer_typetest1(3);  # TIV22
#    $integer_retval = integer_typetest1(-17);  # TIV23
#    $integer_retval = integer_typetest1(-17.3);  # TIV24; error EIV01
#    $integer_retval = integer_typetest1('-17.3');  # TIV25; error EIV01
#    $integer_retval = integer_typetest1([3]);  # TIV26; error EIV01
#    $integer_retval = integer_typetest1({a_key => 3});  # TIV27; error EIV01
##    $integer_retval = integer_typetest1(-1_234_567_890);  # NOT TEST-WORTHY: arithmetic overflow, incorrect results
#    $integer_retval = integer_typetest1(-234_567_890);  # TIV28
#    $integer_retval = integer_typetest1(-1_234_567_890_000);  # TIV29; error EIV01
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$integer_retval = $integer_retval\n");

    # [[[ NUMBER TESTS ]]]

#    $string_retval = number_to_string();  # TNV00; error PERLOPS ENV00, CPPOPS "Usage: number_to_string(input_number)"
#    $string_retval = number_to_string(undef);  # TNV01; error ENV00
#    $string_retval = number_to_string(3);  # TNV02
#    $string_retval = number_to_string(-17);  # TNV03
#    $string_retval = number_to_string(-17.3);  # TNV04
#    $string_retval = number_to_string('-17.3');  # TNV05; error ENV01
#    $string_retval = number_to_string([3]);  # TNV06; error ENV01
#    $string_retval = number_to_string({a_key => 3});  # TNV07; error ENV01
#    $string_retval = number_to_string(3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679);  # TNV08
    $string_retval = number_to_string(1_234_567.890_123_456);  # TNV08
    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval = '$string_retval'\n");

#    $number_retval = number_typetest0();  # TNV10
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$number_retval = $number_retval\n");

    croak('done');

#    $number_retval = number_typetest1();  # TNV20; error PERLOPS ENV00, CPPOPS "Usage: main::number_typetest1(lucky_number)"
#    $number_retval = number_typetest1(undef);  # TNV21; error ENV00
#    $number_retval = number_typetest1(3);  # TNV22
#    $number_retval = number_typetest1(-17);  # TNV23
#    $number_retval = number_typetest1(-17.3);  # TNV24
#    $number_retval = number_typetest1('-17.3');  # TNV25; error ENV01
#    $number_retval = number_typetest1([3]);  # TNV26; error ENV01
#    $number_retval = number_typetest1({a_key => 3});  # TNV27; error ENV01
#    $number_retval = number_typetest1(3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679);  # TNV28
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$number_retval = $number_retval\n");

    # [[[ STRING TESTS ]]]

#    $string_retval = string_to_string();  # TPV00; error PERLOPS EPV00, CPPOPS "Usage: string_to_string(input_string)"
#    $string_retval = string_to_string(undef);  # TPV01; error EPV00
#    $string_retval = string_to_string(3);  # TPV02; error EPV01
#    $string_retval = string_to_string(-17);  # TPV03; error EPV01
#    $string_retval = string_to_string(-17.3);  # TPV04; error EPV01
#    $string_retval = string_to_string('-17.3');  # TPV05
#    $string_retval = string_to_string([3]);  # TPV06; error EPV01
#    $string_retval = string_to_string({a_key => 3});  # TPV07; error EPV01
#    $string_retval = string_to_string('Melange');  # TPV08
#    $string_retval = string_to_string("\nThe Spice Extends Life\nThe Spice Expands Consciousness\nThe Spice Is Vital To Space Travel\n");  # TPV09
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval =\n$string_retval\n");

    # DEV NOTE: in English grammar, I prefer the comma after the right-quote
    $my_string = '\'I am a single-quoted string, in a single-quoted string with back-slash control chars\', the first string said introspectively.' ;    # TPV10
#    $my_string = '"I am a double-quoted string, in a single-quoted string with no back-slash chars", the second string observed.';  # TPV11
#    $my_string = "'I am a single-quoted string, in a double-quoted string with no back-slash chars', the third string added.";  # TPV12
#    $my_string = "\"I am a double-quoted string, in a double-quoted string with back-slash control chars\", the fourth string offered.";  # TPV13
#    $my_string = '\'I am a single-quoted string, in a single-quoted string with back-slash control and \ display \ chars\', the fifth string shouted.';  # TPV14
#    $my_string = '"I am a double-quoted string, in a single-quoted string with back-slash \ display \ chars", the sixth string hollered.';  # TPV15
#    $my_string = "'I am a single-quoted string, in a double-quoted string with back-slash \\ display \\ chars', the seventh string yelled.";  # TPV16
#    $my_string = "\"I am a double-quoted string, in a double-quoted string with back-slash control and \\ display \\ chars\", the eighth string belted.";  # TPV17

#    $my_string = q{'I am a single-quoted string, in a single-quoted q{} string with no back-slash chars', the ninth string chimed in.};  # TPV20
#    $my_string = q{"I am a double-quoted string, in a single-quoted q{} string with no back-slash chars", the tenth string opined.};  # TPV21
#    $my_string = qq{'I am a single-quoted string, in a double-quoted qq{} string with no back-slash chars', the eleventh string asserted.};  # TPV22
#    $my_string = qq{"I am a double-quoted string, in a double-quoted qq{} string with no back-slash chars", the twelfth string insisted.};  # TPV23
#    $my_string = q{'I am a single-quoted string, in a single-quoted q{} string with back-slash \ display \ chars', the thirteenth string whispered.};  # TPV24
#    $my_string = q{"I am a double-quoted string, in a single-quoted q{} string with back-slash \ display \ chars", the fourteenth string breathed.};  # TPV25
#    $my_string = qq{'I am a single-quoted string, in a double-quoted qq{} string with back-slash \\ display \\ chars', the fifteenth string mouthed.};  # TPV26
#    $my_string = qq{"I am a double-quoted string, in a double-quoted qq{} string with back-slash \\ display \\ chars", the sixteenth string implied.};  # TPV27

=disable
    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$my_string =\n$my_string\n\n");
    $dumper_string = Dumper([$my_string]);  # retrieve Dumper()'s version of the stringified string
    $dumper_string =~ s/^\s+|\s+$//xmsg;  # strip leading whitespace
    my @dumper_split = split "\n", $dumper_string;
    $dumper_string = $dumper_split[1];  # only select the data line
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have Dumper([\$my_string]) =\n" . Dumper([$my_string]) . "\n");
=cut

    $dumper_string = string_dumperify($my_string);
    $string_retval = string_to_string($my_string);
    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval =\n$string_retval STRINGIFY\n\n");
    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$dumper_string =\n$dumper_string DUMPERIFY\n\n");

#    $string_retval = string_typetest0();  # TPV30
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval =\n$string_retval\n");

#    $string_retval = string_typetest1();  # TPV40; error PERLOPS EPV00, CPPOPS "Usage: main::string_typetest1(lucky_string)"
#    $string_retval = string_typetest1(undef);  # TPV41; error EPV00
#    $string_retval = string_typetest1(3);  # TPV42; error EPV01
#    $string_retval = string_typetest1(-17);  # TPV43; error EPV01
#    $string_retval = string_typetest1(-17.3);  # TPV44; error EPV01
#    $string_retval = string_typetest1('-17.3');  # TPV45
#    $string_retval = string_typetest1([3]);  # TPV46; error EPV01
#    $string_retval = string_typetest1({a_key => 3});  # TPV47; error EPV01
    $string_retval = string_typetest1('Melange');  # TPV48
#    $string_retval = string_typetest1("\nThe Spice Extends Life\nThe Spice Expands Consciousness\nThe Spice Is Vital To Space Travel\n");  # TPV49
#    Perl::diag("in scalar_test.pl $i/$i_MAX, have \$string_retval =\n$string_retval\n");

    croak('Done for now, croaking');
}

#croak('Done for now, croaking');

