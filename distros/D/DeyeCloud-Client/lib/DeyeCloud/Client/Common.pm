package DeyeCloud::Client::Common;
use strict;
use warnings 'FATAL' => 'all';
no warnings qw(experimental::signatures);
use feature qw(signatures);
use boolean qw(:all);
use version;

use Class::XSAccessor { 'accessors' => [ qw(errno errmsg) ], };

our $VERSION = version->declare('v0.0.2')->stringify();

use constant {
    #{{{
    SSLCHECK       => 1,
    TIMEOUT        => 15,
    E_OK           => [   0, '' ],
    E_NOTOKEN      => [   1, 'No token provided' ],
    E_NOAPPID      => [   2, 'No appid provided' ],
    E_NOAPPSECRET  => [   3, 'No appsecret provided' ],
    E_NOACCEMAIL   => [   4, 'No account email provided' ],
    E_NOACCPWD     => [   5, 'No account password provided' ],
    E_REQFAILED    => [ 400, 'HTTP request failed: %s %s' ],
    E_DECFAILED    => [ 401, 'Server response decoding failed' ],
    E_INVALIDOPTS  => [ 402, 'Method requires another options list' ],
}; #}}}

BEGIN {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT = qw();
}

sub error :prototype($) ($self) {
    return (defined $self and isFalse $self->{'error'})
        ? boolean::false
        : boolean::true;
}

sub seterror :prototype($$@) ($self, $error = DeyeCloud::Client::Common::E_OK, @list) {
    $self->{'error'} = ($error->[0] == DeyeCloud::Client::Common::E_OK->[0])
        ? boolean::false
        : boolean::true;
    $self->errno($error->[0]);
    $self->errmsg(@list ? sprintf($error->[1], @list) : $error->[1]);
}

1;
