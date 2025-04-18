#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Twq';
use ok 'Locale::CLDR::Locales::Twq::Latn::Ne';
use ok 'Locale::CLDR::Locales::Twq::Latn';

done_testing();
