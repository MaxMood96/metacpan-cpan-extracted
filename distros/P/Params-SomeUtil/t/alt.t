use strict;
use warnings;
use Test::More;
use Params::SomeUtil;

Params::SomeUtil->_alt_hook;

is_deeply( \@Params::Util::EXPORT_OK, \@Params::SomeUtil::EXPORT_OK );
is_deeply( \@Params::Util::ISA, \@Params::SomeUtil::ISA );
is_deeply( \%Params::Util::EXPORT_TAGS, \%Params::SomeUtil::EXPORT_TAGS );

ok( Params::Util::_POSINT(1) );
ok( !Params::Util::_POSINT(-2) );

done_testing;
