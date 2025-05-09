#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Chr';
use ok 'Locale::CLDR::Locales::Chr::Cher::Us';
use ok 'Locale::CLDR::Locales::Chr::Cher';

done_testing();
