package DeyeCloud::Client::Station;
use strict;
use warnings 'FATAL' => 'all';
no warnings qw(experimental::signatures);
use feature qw(signatures);
use parent qw(DeyeCloud::Client::Common Class::Accessor);

our $VERSION = $DeyeCloud::Client::Common::VERSION;

use constant {
    BASEURL => 'https://eu1-developer.deyecloud.com/v1.0',
    METHOD  => 'POST',
};

BEGIN {
    require Exporter;
    our @ISA = qw(Class::Accessor Exporter);
    our @EXPORT = qw();
}

sub new :prototype($%) ($class, %options) {
    map { $_ = 0 unless defined $_ } values %options;
    __PACKAGE__->mk_ro_accessors(keys %options);
    return bless { %options }, __PACKAGE__;
}

1;
