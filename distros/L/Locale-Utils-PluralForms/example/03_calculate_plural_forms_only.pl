#!perl -T ## no critic (TidyCode)

use strict;
use warnings;

our $VERSION = 0;

require Locale::Utils::PluralForms;

# initialize English plural forms
my $obj = Locale::Utils::PluralForms->new(
    # bool construct of plural will be converted into interger 0/1
    plural_forms => 'nplurals=2; plural=(n != 1)',
);

printf
    "English:\nplural_forms = '%s'\nnplurals = %s\n\n",
    $obj->plural_forms,
    $obj->nplurals;

my $plural_code = $obj->plural_code;
for (0 .. 2) {
    printf
        "The en plural from for %d is %d\n",
        $_,
        $plural_code->($_),
}

# change to Russian plural forms
$obj->plural_forms(
    # bool construct of plural will be converted into interger 0/1
    'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
);

printf
    "Russian:\nplural_forms = '%s'\nnplurals = %s\n\n",
    $obj->plural_forms,
    $obj->nplurals;

$plural_code = $obj->plural_code;
for (0 .. 2, 5, 100 .. 102, 105, 110 .. 112, 115, 120 .. 122, 125) { ## no critic (MagicNumbers)
    printf
        "The ru plural from for %d is %d\n",
        $_,
        $plural_code->($_),
}

__END__

Output:

English:
plural_forms = 'nplurals=2; plural=(n != 1)'
nplurals = 2

The en plural from for 0 is 1
The en plural from for 1 is 0
The en plural from for 2 is 1
Russian:
plural_forms = 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 or n%100>=20) ? 1 : 2)'
nplurals = 3

The ru plural from for 0 is 2
The ru plural from for 1 is 0
The ru plural from for 2 is 1
The ru plural from for 5 is 2
The ru plural from for 100 is 2
The ru plural from for 101 is 0
The ru plural from for 102 is 1
The ru plural from for 105 is 2
The ru plural from for 110 is 2
The ru plural from for 111 is 2
The ru plural from for 112 is 2
The ru plural from for 115 is 2
The ru plural from for 120 is 2
The ru plural from for 121 is 0
The ru plural from for 122 is 1
The ru plural from for 125 is 2
