use Tomba::Finder;

$tomba = Tomba::Finder->new("ta_xxxxx", "ts_xxxxx");

$result = $tomba->LinkedinFinder('https://www.linkedin.com/in/alex-maccaw-ab592978');

print $result;

