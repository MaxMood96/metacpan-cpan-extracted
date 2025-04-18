use strict;
use warnings;
use lib qw(../../ .);
use Test::More tests => 4;
use t::Exception;
use HTTP::Session;
use CGI;
use HTTP::Session::Store::Test;
use HTTP::Session::State::Null;

my $session = HTTP::Session->new(
    store   => HTTP::Session::Store::Test->new(),
    state   => HTTP::Session::State::Null->new(),
    request => CGI->new,
);
for my $meth (qw/select update delete insert/) {
    throws_ok { $session->store->$meth() } qr/missing session_id/;
}
