#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}
use TFake ();
use Punk::Plugin::Authorisation ();

# Registration: what the plugin accepts, what it refuses, and where it looks
# when it is told nothing.
#
# All of it at boot, which is the point. An option that silently did not
# apply is a rule nobody can see is missing, and every one of these croaks is
# a thing that would otherwise be found by a request that was allowed and
# should not have been.

require Punk::App;
my $FROM_AUTH = Punk::App->can('auth_config') ? 1 : 0;

# Each case is a whole application class, because `plugin` is a boot-time
# keyword and to_app is where it runs. A name per case, so no two collide in
# one interpreter.
my $N = 0;
sub app_with {
    my (%o) = @_;
    my $pkg = 'TOpt' . ++$N;
    my $policy = $o{policy_pkg} || 'TPolicyOK';
    my $opts   = $o{opts} || {};
    my $auth   = $o{auth} // 'auth model => "TFake::Model::User", '
                          . 'rank => [qw(member admin)], '
                          . 'roles => sub { $_[1]->{role} };';
    my $src = qq{
        package $pkg;
        use Punk;
        session secret => 'x' x 32;
        $auth
        database backend => 'TFake::UserBackend';
        model 'TFake::Model::User';
        model 'Punk::Model::Grant';
        plugin 'Authorisation' => \$main::OPTS;
        get '/' => sub { \$_[0]->text('ok') };
        1;
    };
    local our $OPTS = $opts;
    my $err = '';
    eval "$src" or return (undef, $@);
    eval { $pkg->to_app; 1 } or $err = $@;
    return ($pkg, $err);
}

{
    package TPolicyOK;
    use Punk::Plugin::Authorisation;
    rule 'thing.read' => sub { 1 };
    1;
}

# ---- policy ---------------------------------------------------------------------

{
    my (undef, $err) = app_with(opts => { policy => 'not a package' });
    like($err, qr/policy must be a package name, not 'not a package'/,
         'a policy that is not a package name is refused, and quoted back');
}

{
    my (undef, $err) = app_with(opts => { policy => 'TPolicyOK/etc' });
    like($err, qr/policy must be a package name/,
         'and so is one with a path in it');
}

# The default: <AppClass>::Authorisation, so an application that puts its
# rules where the plugin looks says nothing at all.
{
    package TDefault::Authorisation;
    use Punk::Plugin::Authorisation;
    rule 'default.rule' => sub { 1 };
    1;
}
{
    package TDefault;
    use Punk;
    session secret => 'x' x 32;
    auth model => 'TFake::Model::User', rank => [qw(member admin)],
         roles => sub { $_[1]->{role} };
    database backend => 'TFake::UserBackend';
    model 'TFake::Model::User';
    plugin 'Authorisation';                 # no policy named
    get '/' => sub { $_[0]->text($_[0]->may('default.rule') ? 'yes' : 'no') };
}
{
    my $ok = eval { TDefault->to_app; 1 };
    ok($ok, 'a policy at <AppClass>::Authorisation needs no `policy` option')
        or diag($@);
    my $cfg = Punk::Plugin::Authorisation->state_for('TDefault');
    is($cfg->{policy}, 'TDefault::Authorisation',
       'and that is the package it recorded');
}

# ---- rank -----------------------------------------------------------------------

{
    my (undef, $err) = app_with(opts => { policy => 'TPolicyOK', rank => 'member' });
    like($err, qr/rank must be an arrayref of role names, lowest first/,
         'a rank that is not a list is refused');
}

{
    my (undef, $err) = app_with(opts => { policy => 'TPolicyOK', rank => { member => 1 } });
    like($err, qr/rank must be an arrayref/, 'a hashref is not a ladder either');
}

# ---- roles ----------------------------------------------------------------------

{
    my (undef, $err) = app_with(opts => { policy => 'TPolicyOK', roles => 'get_roles' });
    like($err, qr/roles must be a coderef/,
         'a roles hook that is not code is refused');
}

# ---- fields without grants ------------------------------------------------------
#
# The two belong together: `fields` names the grants table's columns, so
# naming them with no table to name is a line that would do nothing.

{
    my (undef, $err) = app_with(opts => { policy => 'TPolicyOK', fields => { subject => 'user_id' } });
    like($err, qr/fields names the grants table's columns, and grants are off/,
         'fields without grants is refused rather than ignored');
    like($err, qr/add grants => 'Model' or drop fields/,
         'naming both ways out');
}

# ---- what registration recorded -------------------------------------------------

{
    my ($pkg, $err) = app_with(opts => { policy => 'TPolicyOK' });
    is($err, '', 'a plain registration boots') or diag($err);

    my $cfg = Punk::Plugin::Authorisation->state_for($pkg);
    is(ref $cfg, 'HASH', 'state_for hands back the live configuration');
    is($cfg->{policy}, 'TPolicyOK', 'naming the policy package');
    ok(exists $cfg->{rules}, 'and carrying the rules it took');
    is(Punk::Plugin::Authorisation->state_for('No::Such::App'), undef,
       'and nothing for an application that never registered');
}

# ---- rules_for is a copy --------------------------------------------------------
#
# It is documented as one, and a caller that could reach into the live
# registry could add a rule to a running application from a `punk` command.

{
    my $rules = Punk::Plugin::Authorisation->rules_for('TPolicyOK');
    is_deeply([ sort keys %$rules ], ['thing.read'], 'rules_for lists the rules');

    delete $rules->{'thing.read'};
    $rules->{'thing.injected'} = sub { 1 };

    my $again = Punk::Plugin::Authorisation->rules_for('TPolicyOK');
    is_deeply([ sort keys %$again ], ['thing.read'],
              'and hands back a copy: changing it changes nothing');

    is(Punk::Plugin::Authorisation->rules_for('No::Such::Policy'), undef,
       'a package with no rules has none rather than an empty set');
}

# ---- import into main -----------------------------------------------------------
#
# `use Punk::Plugin::Authorisation` in a policy package installs `rule`. In
# main it installs nothing: main is where a script says `use` to get at the
# class methods, and a `rule` keyword there would be a keyword in everybody's
# namespace.

{
    ok(!main->can('rule'), 'use-ing the plugin from main installs no keyword');
    ok(TPolicyOK->can('rule'), 'and a policy package has one');
}

done_testing();
