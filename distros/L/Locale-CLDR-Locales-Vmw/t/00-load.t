#!perl -T
use Test::More;
use Test::Exception;
use ok( 'Locale::CLDR' );
my $locale;

diag( "Testing Locale::CLDR v0.46.0, Perl $], $^X" );
use ok 'Locale::CLDR::Locales::Vmw';
use ok 'Locale::CLDR::Locales::Vmw::Latn::Mz';
use ok 'Locale::CLDR::Locales::Vmw::Latn';

done_testing();
