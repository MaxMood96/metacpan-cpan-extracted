use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Date/Format.pm',
    'lib/Date/Format/Generic.pm',
    'lib/Date/Language.pm',
    'lib/Date/Language/Afar.pm',
    'lib/Date/Language/Amharic.pm',
    'lib/Date/Language/Arabic.pm',
    'lib/Date/Language/Austrian.pm',
    'lib/Date/Language/Brazilian.pm',
    'lib/Date/Language/Bulgarian.pm',
    'lib/Date/Language/Chinese.pm',
    'lib/Date/Language/Chinese_GB.pm',
    'lib/Date/Language/Czech.pm',
    'lib/Date/Language/Danish.pm',
    'lib/Date/Language/Dutch.pm',
    'lib/Date/Language/English.pm',
    'lib/Date/Language/Finnish.pm',
    'lib/Date/Language/French.pm',
    'lib/Date/Language/Gedeo.pm',
    'lib/Date/Language/German.pm',
    'lib/Date/Language/Greek.pm',
    'lib/Date/Language/Hungarian.pm',
    'lib/Date/Language/Icelandic.pm',
    'lib/Date/Language/Italian.pm',
    'lib/Date/Language/Norwegian.pm',
    'lib/Date/Language/Occitan.pm',
    'lib/Date/Language/Oromo.pm',
    'lib/Date/Language/Romanian.pm',
    'lib/Date/Language/Russian.pm',
    'lib/Date/Language/Russian_cp1251.pm',
    'lib/Date/Language/Russian_koi8r.pm',
    'lib/Date/Language/Sidama.pm',
    'lib/Date/Language/Somali.pm',
    'lib/Date/Language/Spanish.pm',
    'lib/Date/Language/Swedish.pm',
    'lib/Date/Language/Tigrinya.pm',
    'lib/Date/Language/TigrinyaEritrean.pm',
    'lib/Date/Language/TigrinyaEthiopian.pm',
    'lib/Date/Language/Turkish.pm',
    'lib/Date/Parse.pm',
    'lib/Time/Zone.pm',
    'lib/TimeDate.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/cpanrt.t',
    't/date.t',
    't/edge-cases.t',
    't/format.t',
    't/getdate.t',
    't/lang-data.t',
    't/lang.t',
    't/zone.t'
);

notabs_ok($_) foreach @files;
done_testing;
