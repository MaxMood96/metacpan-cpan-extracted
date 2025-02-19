#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Jmc';
use ok 'Locale::CLDR::Locales::Jmc::Latn::Tz';
use ok 'Locale::CLDR::Locales::Jmc::Latn';

done_testing();
