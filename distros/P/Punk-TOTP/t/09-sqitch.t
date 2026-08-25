use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
BEGIN {
    plan skip_all => 'Punk 0.22+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.22'); 1 };
}

# plugin 'TOTP' => { sqitch => 1 }: the three columns, shipped as the Sqitch
# project punk_totp under lib/Punk/Plugin/TOTP/sqitch - one change that
# requires punk_auth:users - and registered with Punk-Sqitch. A stand-in
# Punk::Plugin::Sqitch records the registration, so this needs nothing
# installed; the shipped files are checked directly.

use Punk::Plugin::TOTP ();
my $dir = do { (my $d = $INC{'Punk/TOTP.pm'}) =~ s/TOTP\.pm\z//; "${d}Plugin/TOTP/sqitch" };
ok(-f "$dir/sqitch.plan" && -f "$dir/sqitch.conf", 'the punk_totp project ships with the plugin');
{
    open my $fh, '<', "$dir/sqitch.plan" or die $!;
    my $plan = do { local $/; <$fh> };
    like($plan, qr/^%project=punk_totp$/m, 'named punk_totp');
    like($plan, qr/^totp \[punk_auth:users\] /m, 'one change, requiring Punk::Auth\'s users table');
}
for my $e (qw(sqlite pg mysql)) {
    ok(-f "$dir/$e/deploy/totp.sql" && -f "$dir/$e/revert/totp.sql" && -f "$dir/$e/verify/totp.sql",
        "$e: deploy, revert and verify scripts");
    open my $fh, '<', "$dir/$e/deploy/totp.sql" or die $!;
    my $sql = do { local $/; <$fh> };
    like($sql, qr/totp_secret.*totp_last_counter.*totp_enabled/s, "$e: the three columns, in the plugin's default spellings");
}

my $SQITCH_PM = 'Punk/Plugin/Sqitch.pm';

# ---- without Punk-Sqitch: an error at the plugin line --------------------------
# Hidden rather than assumed absent: this box may well have Punk-Sqitch
# installed, and then the require succeeds and there is nothing to croak about.
{
    package NoSqitchApp;
    use Punk;
    session secret => 'x' x 32;
    package main;
    my $had = delete $INC{$SQITCH_PM};
    my $e   = '';
    {
        local @INC = (sub {
            die "Can't locate $SQITCH_PM in \@INC (hidden by $0)\n"
                if $_[1] eq $SQITCH_PM;
            return;
        }, @INC);
        eval { NoSqitchApp->punk_app->plugin('TOTP', { issuer => 'T', sqitch => 1 }) } or $e = $@;
    }
    $INC{$SQITCH_PM} = $had if defined $had;
    like($e, qr/sqitch => 1 needs Punk-Sqitch \(Punk::Plugin::Sqitch\) installed/,
        'sqitch => 1 without Punk-Sqitch croaks');
}

# ---- with a stand-in: the registration -----------------------------------------
# Installed at RUNTIME and over the top of whatever is there. A stand-in written
# as an ordinary sub is compiled before any of this file runs, so on a box with
# Punk-Sqitch installed the real module loads afterwards and redefines it away
# again - which reads as the plugin never registering anything.
{
    no warnings 'redefine', 'once';
    *Punk::Plugin::Sqitch::project = sub {
        my ($class, $app, $name, $dir, %o) = @_;
        push @Punk::Plugin::Sqitch::PROJECTS, [ $app, $name, $dir, \%o ];
        return;
    };
    $INC{$SQITCH_PM} ||= __FILE__;   # so the plugin's require is a no-op
}
{
    package SqitchApp;
    use Punk;
    session secret => 'x' x 32;
    plugin 'TOTP' => { issuer => 'T', sqitch => 1 };
    package main;
    is(scalar @Punk::Plugin::Sqitch::PROJECTS, 1, 'sqitch => 1 registered one project');
    my ($app, $name, $d, $o) = @{ $Punk::Plugin::Sqitch::PROJECTS[0] };
    is($name, 'punk_totp', 'named punk_totp');
    is($d, $dir, 'the shipped directory, located from Punk/TOTP.pm - the module the XS always loads through');
    is_deeply($o, { engines => [qw(sqlite pg mysql)] }, 'for the engines it ships scripts for');
    my $cfg = Punk::Plugin::TOTP->state_for('SqitchApp');
    ok(!exists $cfg->{sqitch}, 'the option does not linger in the frozen config');
}
{
    package PlainApp;
    use Punk;
    session secret => 'x' x 32;
    plugin 'TOTP' => { issuer => 'T' };
    package main;
    is(scalar @Punk::Plugin::Sqitch::PROJECTS, 1, 'without sqitch => 1 nothing is registered');
}

done_testing();
