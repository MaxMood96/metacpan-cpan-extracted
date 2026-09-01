use Tomba::Finder;

$tomba = Tomba::Finder->new("ta_xxxxx", "ts_xxxxx");

$result = $tomba->emailFinder('stripe.com', 'fname', 'lname');

print $result;

