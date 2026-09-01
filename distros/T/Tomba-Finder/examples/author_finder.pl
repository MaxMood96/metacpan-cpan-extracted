use Tomba::Finder;

$tomba = Tomba::Finder->new("ta_xxxxx", "ts_xxxxx");

$result = $tomba->AuthorFinder('https://clearbit.com/blog/company-name-to-domain-api');

print $result;

