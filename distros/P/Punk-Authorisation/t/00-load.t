#!perl
use 5.010;
use strict;
use warnings;
use File::Spec ();
use Test::More;

# Every module loads, and the XS is there. First, so a build that half-worked
# says so here rather than in a plugin test twenty assertions in.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}

use_ok('Punk::Authorisation')          or BAIL_OUT('the XS did not load');
use_ok('Punk::Plugin::Authorisation');
use_ok('Punk::Model::Grant');

can_ok('Punk::Plugin::Authorisation', qw(register import state_for rules_for));

# The plugin is XS the whole way down: the .pm file is documentation and a
# version number. If one of these is a Perl sub, something moved back.
{
    require B;
    for my $m (qw(register import state_for rules_for)) {
        my $cv = Punk::Plugin::Authorisation->can($m);
        ok($cv && B::svref_2object($cv)->XSUB,
           "Punk::Plugin::Authorisation::$m is XS");
    }
}

# The Sqitch project ships, and ships where the plugin looks for it -
# pau_authz_boot.h asks for the directory beside this .pm, so the assertion
# is the same lookup and not a path spelled a second way. This is what fails
# when Makefile.PL's lib/ walk is lost and MakeMaker's own map takes only the
# .pm files.
{
    my $pm = $INC{'Punk/Plugin/Authorisation.pm'};
    ok($pm, 'the plugin was loaded from a file') or done_testing(), exit;
    (my $dir = $pm) =~ s/\.pm\z//;
    $dir = File::Spec->catdir($dir, 'sqitch');
    ok(-f File::Spec->catfile($dir, 'sqitch.plan'), 'the punk_authz plan ships');
    for my $engine (qw(sqlite pg mysql)) {
        ok(-f File::Spec->catfile($dir, $engine, 'deploy', 'grants.sql'),
           "the $engine deploy script ships");
    }
}

diag("Testing Punk::Authorisation $Punk::Authorisation::VERSION, "
   . "Punk $Punk::VERSION, Perl $], $^X");
done_testing();
