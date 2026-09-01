use Tomba::Finder;

$tomba = Tomba::Finder->new("ta_xxxxx", "ts_xxxxx");

$result = $tomba->DomainSearch('tomba.io');

print $result;

