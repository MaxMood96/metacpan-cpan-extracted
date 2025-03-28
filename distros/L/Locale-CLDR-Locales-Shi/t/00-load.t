#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Shi';
use ok 'Locale::CLDR::Locales::Shi::Latn::Ma';
use ok 'Locale::CLDR::Locales::Shi::Latn';
use ok 'Locale::CLDR::Locales::Shi::Tfng::Ma';
use ok 'Locale::CLDR::Locales::Shi::Tfng';

done_testing();
