#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Tk';
use ok 'Locale::CLDR::Locales::Tk::Latn::Tm';
use ok 'Locale::CLDR::Locales::Tk::Latn';

done_testing();
