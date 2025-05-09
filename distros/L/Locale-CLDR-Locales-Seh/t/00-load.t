#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Seh';
use ok 'Locale::CLDR::Locales::Seh::Latn::Mz';
use ok 'Locale::CLDR::Locales::Seh::Latn';

done_testing();
