
use Test::More;

use Apache::SessionX::Generate::Random;

my %session;

Apache::SessionX::Generate::Random::generate( \%session );

ok my $id =  $session{data}->{_session_id}, "generated a session_id";

is Apache::SessionX::Generate::Random::validate( \%session ), $id, "validated session_id";

done_testing;
