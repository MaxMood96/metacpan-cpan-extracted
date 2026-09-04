#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use YAML::XS qw(Load);
use JSON::MaybeXS;

use File::SOPS;
use Crypt::Age;

# k30 asked for a per-leaf type override on File::SOPS->encrypt, because
# a caller who writes `if ($cfg->{port} > 1024)` before encrypting turns the
# string 8080 into type:int and, said the ticket, has no way to say otherwise.
#
# The conclusion was not to add one: the channel already exists and it is the
# scalar itself (ADR 0002). These are the idioms File::SOPS documents in place
# of an argument, pinned here so that a change to the type ladder cannot
# quietly take the remedy away with it -- reading the PRIVATE SVp_IOK/SVp_NOK
# instead of the public flags, for instance, would leave the first subtest
# below with no way to pass.

my ($public, $secret) = Crypt::Age->generate_keypair();

sub types_of {
    my ($data) = @_;
    my $yaml = File::SOPS->encrypt(
        data       => $data,
        recipients => [$public],
        format     => 'yaml',
    );
    my %type;
    $type{$1} = $2 while $yaml =~ /^(\w+): ENC\[[^\]]*type:(\w+)\]$/mg;
    return (\%type, $yaml);
}

subtest 'a numeric read is repairable, and repairs the text too' => sub {
    my %cfg = (port => '8080', padded => '007', keeps => '1.50');

    # Every one of these is a READ in numeric context. Perl sets the numeric
    # flag on the scalar in place; the string it already held is untouched.
    my $sum = 0;
    $sum += $cfg{$_} for keys %cfg;

    my ($contaminated) = types_of({%cfg});
    is($contaminated->{port}, 'int', 'reading a string numerically retypes it')
        or diag('this is the defect k30 was raised about');

    # The documented remedy.
    $cfg{$_} = "$cfg{$_}" for keys %cfg;

    my ($type, $yaml) = types_of({%cfg});
    is($type->{port},   'str', 'restringifying puts the type back');
    is($type->{padded}, 'str', 'for a padded integer too');
    is($type->{keeps},  'str', 'and for a float-looking string');

    my $back = File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]);
    is($back->{port},   '8080', 'the original text survives, not just the type');
    is($back->{padded}, '007',  'padding included');
    is($back->{keeps},  '1.50', 'and trailing zeros');
};

subtest 'the other direction: promoting a string to a number' => sub {
    my %cfg = (port => '5432', ratio => '1.50');

    $cfg{port}  = 0 + $cfg{port};
    $cfg{ratio} = 0.0 + $cfg{ratio};

    my ($type, $yaml) = types_of({%cfg});
    is($type->{port},  'int',   '0 + $x asks for type:int');
    is($type->{ratio}, 'float', '0.0 + $x asks for type:float');

    # A number is written in Go's canonical form, so this one does not
    # round-trip its source text -- which is the point of asking for a number.
    like($yaml, qr/^ratio: ENC\[/m, 'and it is encrypted');
    my $back = File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]);
    cmp_ok($back->{ratio}, '==', 1.5, 'coming back as the number');
};

subtest 'bool has no Perl literal, so it is asked for explicitly' => sub {
    my ($type) = types_of({ on => JSON->true, off => JSON->false, word => 'true' });
    is($type->{on},   'bool', 'JSON->true is type:bool');
    is($type->{off},  'bool', 'JSON->false too');
    is($type->{word}, 'str',  'while the string true stays a string');
};

subtest 'a numeric assignment destroys the text, and no API could restore it' => sub {
    # The one case the idiom does NOT cover, documented as such: += replaces
    # the scalar's value rather than merely reading it, so '1.50' is gone
    # before File::SOPS sees anything. A type argument to encrypt would have
    # written the same 1.5 under a different label.
    my %cfg = (ratio => '1.50');
    $cfg{ratio} += 0;
    $cfg{ratio} = "$cfg{ratio}";

    my ($type, $yaml) = types_of({%cfg});
    is($type->{ratio}, 'str', 'the type is what was asked for');

    my $back = File::SOPS->decrypt(encrypted => $yaml, identities => [$secret]);
    is($back->{ratio}, '1.5', 'but the text is the one the caller assigned');
};

done_testing;
