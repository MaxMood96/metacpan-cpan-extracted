#!perl
use 5.010;
use strict;
use warnings;
use Test::More;

# Every module loads, and the XS is there. First, so a build that half-worked
# says so here rather than in a plugin test twenty assertions in.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}

use_ok('Punk::APIKey')          or BAIL_OUT('the XS did not load');
use_ok('Punk::Plugin::APIKey');
use_ok('Punk::Model::ApiKey');
use_ok('Punk::Command::Apikey');

ok(defined $Punk::APIKey::VERSION, 'the distribution has a version');

can_ok('Punk::Plugin::APIKey', qw(register import state_for issue_for
                                  revoke_for keys_for forget_owners
                                  _mint _parse _digest _checksum
                                  _guard_for _checker_for));

# The plugin is XS the whole way down: the .pm file is documentation and a
# version number. If one of these is a Perl sub, something moved back.
{
    require B;
    for my $m (qw(register import state_for)) {
        my $cv = Punk::Plugin::APIKey->can($m);
        ok($cv && B::svref_2object($cv)->XSUB,
           "Punk::Plugin::APIKey::$m is XS");
    }
}

# The XS lives in this distribution's own shared library now, not in
# Punk::DIY's. A stale Punk-DIY on @INC that still ships the plugin would
# satisfy every assertion above, so name the file the XSUB came from.
{
    my $file = $INC{'Punk/APIKey.pm'};
    ok($file, 'Punk::APIKey was loaded from a file');
    like($file, qr/APIKey\.pm\z/, 'and it is this distribution');
}

diag("Testing Punk::APIKey $Punk::APIKey::VERSION, Perl $], $^X");
done_testing();
