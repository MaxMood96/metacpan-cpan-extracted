use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use JSON::Validator::Schema::Troglodyne;

sub validate {
    my ($opts, $args) = @_;
    my $validator = JSON::Validator::Schema::Troglodyne->new();
    return $validator->validate($opts, $args);
}

sub _test {
    my ($input, $data, $test, $msg) = @_;
    my @errors = validate($input, $data);
    like($errors[0], $test, $msg);
}

my %data = (
    type       => 'object',
    required   => [qw{foo bar}],
    properties => {
        foo => { type => 'email' },
        bar => { type => 'callback' },
    },
);

my %input = (
    foo => 'test@test.test',
    bar => '',
);

# Sub checkinz
_test(\%input, \%data, qr/not a fully qualified sub name/i, "non fq Bogus subname results in failure");
$input{bar} = [];
_test(\%input, \%data, qr/not a fully qualified sub name/i, "Bogus subname type results in failure");
$input{bar} = 'Fully::bogus';
_test(\%input, \%data, qr/cannot be loaded/i, "Unloadable Bogus subname results in failure");
$input{bar} = 'JSON::Validator::Schema::Troglodyne::bogus';
_test(\%input, \%data, qr/sub which does not exist/i, "Bogus subname results in failure");
$input{bar} = 'JSON::Validator::Schema::Troglodyne::_troglodyne_path';
my @err = validate(\%input, \%data);
is(scalar(@err), 0, "OK subname & email results in no failure");

# email checkinz
$input{foo} = 'bogus';
_test(\%input, \%data, qr/no email/i, "Bogus email results in failure");
$input{foo} = [];
_test(\%input, \%data, qr/wrong type/i, "Bogus email type results in failure");

done_testing();
