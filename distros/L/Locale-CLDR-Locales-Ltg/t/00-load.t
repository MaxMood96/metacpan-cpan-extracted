#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Ltg';
use ok 'Locale::CLDR::Locales::Ltg::Latn::Lv';
use ok 'Locale::CLDR::Locales::Ltg::Latn';

done_testing();
