#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Et';
use ok 'Locale::CLDR::Locales::Et::Latn::Ee';
use ok 'Locale::CLDR::Locales::Et::Latn';

done_testing();
