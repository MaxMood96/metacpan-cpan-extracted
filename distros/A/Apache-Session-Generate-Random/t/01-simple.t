
use Test::More;

use Apache::Session::Generate::Random;

my %session;

Apache::Session::Generate::Random::generate( \%session );

ok my $id =  $session{data}->{_session_id}, "generated a session_id";

is Apache::Session::Generate::Random::validate( \%session ), $id, "validated session_id";

done_testing;
