package Punk::Command::Fakecmd;

# t/1311's plugin-seam fixture: bin/punk probes Punk::Command::<Ucfirst> on an
# unknown command, and loading the module IS the registration.

use strict;
use warnings;
use Punk::Command ();

Punk::Command->register(fakecmd => {
    abstract => 'a test fixture',
    hidden   => 1,
    options  => [ { spec => 'shout', doc => 'upper case' } ],
    code     => sub {
        my ($opt) = @_;
        print $opt->{shout} ? "FAKE\n" : "fake\n";
        return 42;
    },
}, __PACKAGE__);

# A doctor row, so t/1311 can prove `punk doctor` finds a plugin's row
# without that plugin's command having been named first.
Punk::Command->register_doctor('Fakecmd' => sub {
    return (1, 'the fixture is installed');
}, __PACKAGE__) if Punk::Command->can('register_doctor');

1;
