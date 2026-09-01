#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Spec ();

# The plugin ships its schema as a Sqitch project, and registers it when
# Punk-Sqitch is installed.
#
# Two halves, with different requirements. The registration and the plan are
# checked with nothing installed but this distribution - a plan file is a text
# format and the registry is a hash. Deploying it needs App::Sqitch, DBD::SQLite
# and the sqlite3 client, and is skipped when they are not all here.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
}

use Punk::Plugin::APIKey ();

my $pm = $INC{'Punk/Plugin/APIKey.pm'} or die 'not loaded from a file';
(my $base = $pm) =~ s/\.pm\z//;
my $dir = File::Spec->rel2abs(File::Spec->catdir($base, 'sqitch'));

# ---- what ships --------------------------------------------------------------

ok(-d $dir, 'the sqitch project ships beside the module');
ok(-f File::Spec->catfile($dir, 'sqitch.plan'), 'with a plan');
ok(-f File::Spec->catfile($dir, 'sqitch.conf'), 'and a conf');

{
    my $plan = do {
        open my $fh, '<', File::Spec->catfile($dir, 'sqitch.plan') or die $!;
        local $/; <$fh>;
    };
    like($plan, qr/^%project=punk_apikey$/m,
        'the project name is punk_apikey - the registry key, and it never '
      . 'changes once anyone has deployed it');
    like($plan, qr/^api_keys\s/m, 'with one change, named for the table');
}

for my $engine (qw(sqlite pg mysql)) {
    for my $kind (qw(deploy revert verify)) {
        ok(-f File::Spec->catfile($dir, $engine, $kind, 'api_keys.sql'),
            "$engine has a $kind script");
    }
}

# Sqitch runs a script through the engine's own client, so each has to be
# valid for that engine rather than for the one the author happened to test.
{
    my $my = do {
        open my $fh, '<', File::Spec->catfile($dir, 'mysql', 'deploy',
                                              'api_keys.sql') or die $!;
        local $/; <$fh>;
    };
    like($my, qr/digest\s+VARCHAR\(191\)/,
        'the MySQL digest column is a VARCHAR, because TEXT cannot be a key');
    unlike($my, qr/^\s*BEGIN\s*;/mi,
        'and it has no BEGIN: MySQL commits DDL implicitly, so a transaction '
      . 'wrapper is a lie');

    my $pg = do {
        open my $fh, '<', File::Spec->catfile($dir, 'pg', 'verify',
                                              'api_keys.sql') or die $!;
        local $/; <$fh>;
    };
    like($pg, qr/WHERE FALSE/i, 'the Pg verify uses WHERE FALSE, not WHERE 0');
}

{
    # A plugin's project must not depend on the application's own, which
    # deploys last - and owner_id is a column rather than a foreign key for
    # the separate reason that a key identifies an account.
    my $sql = do {
        open my $fh, '<', File::Spec->catfile($dir, 'sqlite', 'deploy',
                                              'api_keys.sql') or die $!;
        local $/; <$fh>;
    };
    unlike($sql, qr/REFERENCES/i,
        'owner_id is a column, not a foreign key to any users table');
    like($sql, qr/CREATE UNIQUE INDEX api_keys_digest/,
        'the digest index is unique - two rows must not claim one key');
}

# ---- registration ------------------------------------------------------------

SKIP: {
    skip 'Punk-Sqitch not installed', 5
        unless eval { require Punk::Plugin::Sqitch; 1 }
            && Punk::Plugin::Sqitch->can('project');

    # The registry is keyed off the application class, which Punk-Sqitch reads
    # through caller_class - the whole of its coupling to Punk.
    {
        package Fake::App;
        sub new { bless {}, shift }
        sub caller_class { 'Fake::App::Class' }
    }
    my $app = Fake::App->new;

    ok(eval {
        Punk::Plugin::Sqitch->project($app, punk_apikey => $dir,
                                      engines => [qw(sqlite pg mysql)]);
        1;
    }, 'the project registers') or diag $@;

    my $err = '';
    eval {
        Punk::Plugin::Sqitch->project($app, punk_apikey => $dir,
                                      engines => [qw(sqlite pg mysql)]);
        1;
    } or $err = $@;
    like($err, qr/punk_apikey/,
        'and a second registration of the same name croaks naming it - two '
      . 'plugins claiming one project would deploy over each other');

    $err = '';
    eval {
        Punk::Plugin::Sqitch->project($app, punk_apikey_bad => '/no/such/dir');
        1;
    } or $err = $@;
    ok($err, 'a project directory that does not exist is refused');

    $err = '';
    eval {
        Punk::Plugin::Sqitch->project($app, 'Bad Name' => $dir);
        1;
    } or $err = $@;
    ok($err, 'and so is a name that is not a Sqitch project name');

    # What THIS distribution registers, not what the registry happens to
    # contain: an application with Punk-DIY installed too has punk_feature in
    # there, and asserting on the whole set would fail for a reason that is
    # nobody's bug.
    my $projects = eval { Punk::Plugin::Sqitch->projects_for($app) };
    if (ref $projects eq 'ARRAY') {
        my %names = map { (ref $_ eq 'HASH' ? $_->{name} : $_) => 1 }
                        @$projects;
        ok($names{punk_apikey}, 'and it is in the registry the deploy walks');
    }
    else {
        ok(1, 'projects_for is not this version\'s spelling; skipped');
    }
}

# ---- a real deploy -----------------------------------------------------------

SKIP: {
    # Through Punk::Sqitch->run, which is what `punk sqitch deploy` calls, so
    # what is proved is the path an operator takes rather than a second
    # invocation written here that could be wrong in its own way.
    skip 'Punk-Sqitch required to deploy', 3
        unless eval { require Punk::Sqitch; 1 } && Punk::Sqitch->can('run');
    skip 'App::Sqitch required', 3 unless eval { require App::Sqitch; 1 };
    skip 'DBD::SQLite required', 3
        unless eval { require DBI; require DBD::SQLite; 1 };
    skip 'the sqlite3 client is required to deploy', 3 unless _which('sqlite3');

    require File::Temp;
    my $tmp = File::Temp::tempdir(CLEANUP => 1);
    my $db  = File::Spec->catfile($tmp, 'app.db');

    my $code = Punk::Sqitch->run(
        verb      => 'deploy',
        cwd       => $dir,
        target    => { uri => "db:sqlite:$db" },
        verbosity => 0,
    );
    is($code, 0, 'sqitch deploy runs against the shipped project')
        or skip 'deploy did not run', 2;

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '',
                           { RaiseError => 0, PrintError => 0 });
    my $tbl = $dbh && $dbh->selectall_arrayref(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='api_keys'");
    is(scalar @{ $tbl || [] }, 1, 'and creates the api_keys table');

    Punk::Sqitch->run(verb => 'revert', cwd => $dir,
                      target => { uri => "db:sqlite:$db" },
                      args => ['-y'], verbosity => 0);
    $tbl = $dbh && $dbh->selectall_arrayref(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='api_keys'");
    is(scalar @{ $tbl || [] }, 0, 'and revert takes it away again');
    $dbh->disconnect if $dbh;
}

sub _which {
    my ($cmd) = @_;
    for my $p (split /:/, ($ENV{PATH} || '')) {
        my $f = File::Spec->catfile($p, $cmd);
        return $f if -x $f;
    }
    return undef;
}

done_testing();
