#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Nqo';
use ok 'Locale::CLDR::Locales::Nqo::Nkoo::Gn';
use ok 'Locale::CLDR::Locales::Nqo::Nkoo';

done_testing();
