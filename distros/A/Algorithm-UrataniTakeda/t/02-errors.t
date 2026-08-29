#!perl

use v5.26;

use Test2::V0 -no_srand => 1;
use Test2::Tools::Exception qw( dies  );

use Algorithm::UrataniTakeda;

subtest 'patterns' => sub {

    like dies { Algorithm::UrataniTakeda->new }, qr/^Required parameter 'patterns' is missing/, "no patterns";

    like dies { Algorithm::UrataniTakeda->new( patterns => [] ) }, qr/^Parameter 'patterns' cannot be empty/, "empty patterns";

    like dies { Algorithm::UrataniTakeda->new( patterns => [ "one", undef ] ) }, qr/^Parameter 'patterns' cannot contain empty strings/,
      "patterns with undef";

    like dies { Algorithm::UrataniTakeda->new( patterns => [ "one", "" ] ) }, qr/^Parameter 'patterns' cannot contain empty strings/,
      "patterns with empty string";

};

done_testing;
