#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Mi';
use ok 'Locale::CLDR::Locales::Mi::Latn::Nz';
use ok 'Locale::CLDR::Locales::Mi::Latn';

done_testing();
