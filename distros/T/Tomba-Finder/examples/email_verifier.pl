use Tomba::Finder;

$tomba = Tomba::Finder->new("ta_xxxxx", "ts_xxxxx");

$result = $tomba->EmailVerifier('b.mohamed@tomba.io');

print $result;

