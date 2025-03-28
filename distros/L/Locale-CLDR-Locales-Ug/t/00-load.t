#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Ug';
use ok 'Locale::CLDR::Locales::Ug::Arab::Cn';
use ok 'Locale::CLDR::Locales::Ug::Arab';

done_testing();
