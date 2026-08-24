#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();
use File::Path ();
use Cwd ();

# Punk::Plugin::Sqitch under real Punk applications: the three outcomes,
# the off-switch, a missing plan, a misnamed database, and the option
# checks. The registry is built by hand (t/03's shape) so this needs
# neither App::Sqitch nor the sqlite3 client - the plugin never loads the
# former and never runs the latter, which is the point of it.
#
# On a Punk without $app->on_compile the check runs at the `plugin` line;
# with it, at to_app. Each case evaluates the class AND compiles it, and
# looks at the combined outcome, so the test holds on both.

BEGIN {
    # the cases chdir into the application root, and a relative @INC entry
    # (-Ilib, blib/) would stop resolving there
    @INC = map { File::Spec->rel2abs($_) } @INC;
    plan skip_all => 'Punk required' unless eval { require Punk; 1 };
    plan skip_all => 'DBI + DBD::SQLite required' unless eval { require DBI; require DBD::SQLite; 1 };
}
use Punk::Plugin::Sqitch ();

sub write_file {
    my ($path, $body) = @_;
    my ($vol, $dir) = File::Spec->splitpath($path);
    File::Path::make_path($dir) if length $dir && !-d $dir;
    open my $fh, '>', $path or die "$path: $!";
    print $fh $body;
    close $fh;
}
sub registry {
    my ($path, @changes) = @_;
    my ($vol, $d) = File::Spec->splitpath($path);
    File::Path::make_path($d) if length $d && !-d $d;
    unlink $path;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$path", '', '', { RaiseError => 1 });
    $dbh->do('CREATE TABLE changes (change_id TEXT PRIMARY KEY, script_hash TEXT, change TEXT NOT NULL, '
           . 'project TEXT NOT NULL, note TEXT NOT NULL DEFAULT \'\', committed_at DATETIME NOT NULL, '
           . 'committer_name TEXT NOT NULL DEFAULT \'\', committer_email TEXT NOT NULL DEFAULT \'\', '
           . 'planned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, planner_name TEXT NOT NULL DEFAULT \'\', '
           . 'planner_email TEXT NOT NULL DEFAULT \'\')');
    my $i = 0;
    $dbh->do('INSERT INTO changes (change_id, change, project, committed_at) VALUES (?,?,?,?)',
             undef, sprintf('%040x', ++$i), $_, 'demo', sprintf('2026-08-23 10:%02d:00', $i)) for @changes;
    $dbh->disconnect;
}

my $dir  = File::Temp->newdir;
my $root = "$dir/app";
write_file("$root/app.psgi", "1;\n");
write_file("$root/config/punk.yml", "database:\n  dsn: dbi:SQLite:dbname=var/app.db\n");
write_file("$root/sqitch.plan", <<'PLAN');
%syntax-version=1.0.0
%project=demo

users 2026-08-23T09:47:30Z S <s@e> # users
api_keys [users] 2026-08-23T09:47:31Z S <s@e> # keys
PLAN
File::Path::make_path("$root/var");

# define a fresh app class with the plugin line, from inside the app root,
# and compile it; returns (error-or-undef, warnings)
my $N = 0;
sub app {
    my ($plugin_args) = @_;
    my $class = 'SqApp' . ++$N;
    my $cwd = Cwd::getcwd();
    chdir $root or die $!;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    my $err;
    my $ok = eval qq{
        package $class;
        use Punk;
        database dsn => 'dbi:SQLite:dbname=var/app.db';
        plugin 'Sqitch'$plugin_args;
        get '/' => sub { \$_[0]->text('ok') };
        1;
    };
    $err = $@ unless $ok;
    if ($ok) {
        my $psgi = eval { $class->to_app };
        $err = $@ unless $psgi;
    }
    chdir $cwd;
    return ($err, \@warnings, $class);
}

# ---- pending: croak ------------------------------------------------------------------
{
    registry("$root/var/sqitch.db", 'users');
    my ($err, $w) = app('');
    like($err, qr/Punk::Plugin::Sqitch: the schema is behind the code: 1 change pending for project 'demo' \(api_keys\) - run `punk sqitch deploy`/,
        'a pending change croaks at boot, naming it and the command');
}
{
    unlink "$root/var/sqitch.db";
    my ($err, $w) = app('');
    like($err, qr/2 changes pending for project 'demo' \(users, api_keys\)/,
        'no registry at all: everything pending, and it croaks');
}

# ---- pending: warn -------------------------------------------------------------------
{
    registry("$root/var/sqitch.db", 'users');
    my ($err, $w, $class) = app(" => { check => 'warn' }");
    is($err, undef, 'check => warn: the application compiles') or diag $err;
    is(scalar @$w, 1, 'with one warning');
    like($w->[0], qr/1 change pending for project 'demo' \(api_keys\)/, 'naming the change');
    my $r = Punk::Plugin::Sqitch->result_for($class);
    is($r->{deployed}, 1, 'result_for: the check\'s result is kept');
    is_deeply($r->{pending}, ['api_keys'], 'with the pending list');
}

# ---- up to date -------------------------------------------------------------------------
{
    registry("$root/var/sqitch.db", 'users', 'api_keys');
    my ($err, $w, $class) = app('');
    is($err, undef, 'up to date: compiles') or diag $err;
    is(scalar @$w, 0, 'silently');
    is_deeply(Punk::Plugin::Sqitch->result_for($class)->{pending}, [], 'nothing pending');
}

# ---- drift ------------------------------------------------------------------------------
{
    registry("$root/var/sqitch.db", 'users', 'api_keys', 'something_local');
    my ($err, $w) = app('');
    like($err, qr/project 'demo': the registry holds 3 changes for project 'demo' but the plan lists 2/,
        'drift croaks: something deployed here the plan does not describe');
    my ($err2, $w2) = app(" => { check => 'warn' }");
    is($err2, undef, 'drift under warn: compiles');
    like($w2->[0], qr/registry holds 3 changes/, 'with the warning');
}

# ---- the database away ----------------------------------------------------------------
{
    write_file("$root/var/sqitch.db", "this is not a database\n");
    my ($err, $w) = app('');
    is($err, undef, 'a registry that cannot be read: the application starts') or diag $err;
    like($w->[0], qr/cannot read the registry.* - starting without the schema check/,
        'with a warning saying the check did not run');
    unlink "$root/var/sqitch.db";
}

# ---- off ----------------------------------------------------------------------------------
{
    my ($err, $w) = app(' => { check => 0 }');
    is($err, undef, 'check => 0: compiles with everything pending');
    is(scalar @$w, 0, 'and says nothing');
}

# ---- misconfiguration croaks at the plugin line ---------------------------------------------
{
    registry("$root/var/sqitch.db", 'users', 'api_keys');
    my ($err) = app(" => { database => 'nope' }");
    like($err, qr/no database 'nope' configured \(have: default\)/, 'an unconfigured database name');
    ($err) = app(" => { check => 'maybe' }");
    like($err, qr/check must be 'croak', 'warn' or 0, not 'maybe'/, 'a bad check value');
    ($err) = app(" => { colour => 'red' }");
    like($err, qr/unknown option 'colour' \(known: check, database, dir, env\)/, 'an unknown option');
    rename "$root/sqitch.plan", "$root/sqitch.plan.away";
    ($err) = app('');
    like($err, qr/no plan at .*sqitch\.plan - run `punk sqitch init` first/, 'no plan croaks at the plugin line');
    rename "$root/sqitch.plan.away", "$root/sqitch.plan";
}

# ---- dir: from anywhere ------------------------------------------------------------------------
{
    registry("$root/var/sqitch.db", 'users');
    my $class = 'SqAppDir';
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    my $ok = eval qq{
        package $class;
        use Punk;
        database dsn => 'dbi:SQLite:dbname=var/app.db';
        plugin 'Sqitch' => { dir => '$root', check => 'warn' };
        1;
    };
    ok($ok, 'dir => points the plugin at the application from another cwd') or diag $@;
    # on a Punk with on_compile the check waits for to_app; compile from
    # another cwd too, since dir => is what points it home
    eval { SqAppDir->to_app; 1 } or diag $@;
    like($warnings[0] // '', qr/api_keys/, 'and the check ran there');
}

# ---- the to_app path: a database declared in the class, after the plugin line ---
# Only possible with $app->on_compile and $app->databases (Punk 0.31): the
# check runs at to_app and reads the registrar, so a `database` keyword
# below the plugin line - and no punk.yml at all - is seen.
SKIP: {
    skip 'needs a Punk with $app->on_compile and $app->databases', 4
        unless Punk::App->can('on_compile') && Punk::App->can('databases');
    my $root2 = "$dir/classapp";
    write_file("$root2/app.psgi", "1;\n");
    write_file("$root2/sqitch.plan", "%syntax-version=1.0.0\n%project=classapp\n\nusers 2026-08-23T09:47:30Z S <s\@e> # users\n");
    File::Path::make_path("$root2/var");
    my @w;
    local $SIG{__WARN__} = sub { push @w, $_[0] };
    my ($err, $compiled);
    {
        my $cwd = Cwd::getcwd();
        chdir $root2 or die $!;
        my $ok = eval q{
            package ClassDbApp;
            use Punk;
            plugin 'Sqitch' => { check => 'warn' };          # above the database line
            database dsn => 'dbi:SQLite:dbname=var/class.db'; # and no config/punk.yml
            get '/' => sub { $_[0]->text('ok') };
            1;
        };
        $err = $@ unless $ok;
        $compiled = eval { ClassDbApp->to_app; 1 } ? 1 : 0;
        $err //= $@ unless $compiled;
        chdir $cwd;
    }
    is($err, undef, 'the plugin line above the database keyword, no punk.yml: compiles') or diag $err;
    ok($compiled, 'and to_app ran the check');
    is(scalar @w, 1, 'with one warning');
    like($w[0], qr/1 change pending for project 'classapp' \(users\)/,
        'naming the change - the database was read from the class at to_app');
}

done_testing();
