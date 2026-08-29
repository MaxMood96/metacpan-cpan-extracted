# PURPOSE: Every module in the distribution loads
# LAYER:   unit
# COVERS:  Typesense::Client and all its delegates

use v5.38;
use warnings;
use Test::More;

my @modules = qw(
    Typesense::Client
    Typesense::Client::Error
    Typesense::Client::Version
    Typesense::Client::Collections
    Typesense::Client::Documents
    Typesense::Client::Aliases
    Typesense::Client::Synonyms
    Typesense::Client::Overrides
    Typesense::Client::Analytics
    Typesense::Client::Keys
);

require_ok($_) for @modules;

subtest 'delegates are created on demand and reused' => sub {
    my $ts = Typesense::Client->new(url => 'http://127.0.0.1:8108/', api_key => 'k');
    for my $r (qw(collections documents aliases synonyms overrides analytics keys)) {
        my $o = $ts->$r;
        ok(defined $o, "$r exists");
        is($ts->$r, $o, "$r is reused instead of rebuilt");
    }
};

done_testing();
