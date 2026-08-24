#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();
use File::Path ();
use Cwd ();

# `punk sqitch ...` end to end: a throwaway application with a config/punk.yml
# naming a SQLite database, driven through Punk::Command's in-process seam -
# $Punk::Command::OUT / $ERR and the exit code main returns - so the whole
# thing runs without spawning punk or sqitch. The deploy itself needs the
# sqlite3 client, because that is how Sqitch runs scripts.

BEGIN {
    # the runs chdir into the application root; a relative @INC entry would
    # stop resolving there
    @INC = map { File::Spec->rel2abs($_) } @INC;
    plan skip_all => 'App::Sqitch required' unless eval { require App::Sqitch; 1 };
    plan skip_all => 'DBI + DBD::SQLite required' unless eval { require DBI; require DBD::SQLite; 1 };
}
use Punk::Command ();
use Punk::Command::Sqitch ();

my $have_sqlite3 = do {
    my $v = `sqlite3 -version 2>/dev/null`;
    defined $v && $v =~ /\A\d/ ? 1 : 0;
};

sub write_file {
    my ($path, $body) = @_;
    my ($vol, $dir) = File::Spec->splitpath($path);
    File::Path::make_path($dir) if length $dir && !-d $dir;
    open my $fh, '>', $path or die "$path: $!";
    print $fh $body;
    close $fh;
}

# the application: app.psgi is the root marker, punk.yml the database
my $dir = File::Temp->newdir;
my $root = "$dir/app";
write_file("$root/app.psgi", "use TestApp; TestApp->to_app;\n");
# the class, loadable: a target verb loads it to find the plugins' projects
write_file("$root/lib/TestApp.pm", "package TestApp;\nuse Punk;\nget '/' => sub { \$_[0]->text('ok') };\n1;\n");
write_file("$root/config/punk.yml", <<"YML");
database:
  dsn: dbi:SQLite:dbname=var/test.db
YML
write_file("$root/config/punk.staging.yml", <<"YML");
database:
  dsn: dbi:SQLite:dbname=var/staging/app.db
YML
# one directory per database: Sqitch's SQLite registry is sqitch.db BESIDE
# the target, so two targets in one directory would share a registry and the
# second would look deployed already - the trap phase 1 of the plan names
File::Path::make_path("$root/var/$_") for qw(staging other);

# run `punk sqitch @args` from a given directory, capturing both streams
sub punk {
    my ($from, @args) = @_;
    my ($out, $err) = ('', '');
    open my $oh, '>', \$out or die $!;
    open my $eh, '>', \$err or die $!;
    local $Punk::Command::OUT = $oh;
    local $Punk::Command::ERR = $eh;
    my $cwd = Cwd::getcwd();
    chdir $from or die "$from: $!";
    my $code = Punk::Command->main('sqitch', @args);
    chdir $cwd;
    close $oh; close $eh;
    return ($code, $out, $err);
}

# ---- usage -------------------------------------------------------------------------
{
    my ($code, $out, $err) = punk($root);
    is($code, 2, 'no verb is a usage error');
    like($err, qr/a sqitch verb is required/, 'saying so');
    like($err, qr/usage: punk sqitch \[--env ENV\]/, 'with the usage');
    ($code, $out, $err) = punk($root, '--bogus', 'status');
    is($code, 2, 'an unknown option before the verb is a usage error');
    like($err, qr/sqitch's own options go after it/, 'pointing at where they go');
    ($code, $out, $err) = punk($root, '--env');
    is($code, 2, '--env without a value is a usage error');
    ($code, $out, $err) = punk($root, '--help');
    is($code, 0, '--help is not an error');
    like($out, qr/--database NAME/, 'and prints the usage');
}

# ---- no application ----------------------------------------------------------------
{
    my ($code, $out, $err) = punk("$dir", 'status');
    is($code, 2, 'no app.psgi above the cwd: exit 2');
    like($err, qr/no application found \(looked for app\.psgi upwards from/, 'naming where it looked');
}

# ---- the database resolution ---------------------------------------------------------
{
    my ($code, $out, $err) = punk($root, '--database', 'nope', 'status');
    is($code, 1, 'an unconfigured database name is an error');
    like($err, qr/no database 'nope' configured \(have: default\)/, 'listing what is configured');
}

# ---- a project, deployed ---------------------------------------------------------------
SKIP: {
    skip 'sqlite3 client required for deploys (Sqitch runs scripts through it)', 33
        unless $have_sqlite3;

    my ($code, $out, $err) = punk($root, 'init', 'testapp', '--engine', 'sqlite');
    is($code, 0, 'punk sqitch init') or diag $err;
    ok(-f "$root/sqitch/sqitch.plan" && -f "$root/sqitch/sqitch.conf", 'wrote the plan and the conf under sqitch/');
    unlike(slurp("$root/sqitch/sqitch.conf"), qr/^\s*target\s*=\s*db:/m, 'and no target in the conf - it comes from punk.yml every run');

    ($code, $out, $err) = punk($root, 'add', 'users', '-n', 'users table');
    is($code, 0, 'punk sqitch add (plan-only: no database needed)') or diag $err;
    write_file("$root/sqitch/deploy/users.sql", "CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT NOT NULL);\n");
    write_file("$root/sqitch/revert/users.sql", "DROP TABLE users;\n");
    write_file("$root/sqitch/verify/users.sql", "SELECT id, email FROM users WHERE 0;\n");

    ($code, $out, $err) = punk($root, 'pending');
    is($code, 1, 'punk sqitch pending: exit 1 with a change pending');
    like($out, qr/Pending change:\n  \* users/, 'naming it');
    like($out, qr/Registry: var\/sqitch\.db/, 'and where it looked');
    ($code, $out, $err) = punk($root, 'pending', '--quiet');
    is($code, 1, '--quiet: the code alone');
    is($out . $err, '', 'and nothing printed');
    ($code, $out, $err) = punk($root, 'pending', '--target', 'x');
    is($code, 2, 'pending takes no other arguments');

    ($code, $out, $err) = punk($root, 'deploy');
    is($code, 0, 'punk sqitch deploy') or diag $err;
    like($out, qr{Deploying changes to db:sqlite:/\S*/var/test\.db},
        'to the target punk.yml names, made absolute because each project runs from its own directory');
    like($out, qr/\+ users \.+ ok/, 'the change deployed');
    ok(-f "$root/var/test.db", 'the database is where the dsn said, relative to the app root');
    ok(-f "$root/var/sqitch.db", 'and Sqitch\'s registry beside it');
    {
        my $dbh = DBI->connect("dbi:SQLite:dbname=$root/var/test.db", '', '', { RaiseError => 1 });
        my ($n) = $dbh->selectrow_array("SELECT COUNT(*) FROM sqlite_master WHERE name = 'users'");
        is($n, 1, 'the table exists');
        my $reg = DBI->connect("dbi:SQLite:dbname=$root/var/sqitch.db", '', '', { RaiseError => 1 });
        my ($project, $change) = $reg->selectrow_array('SELECT project, change FROM changes');
        is("$project/$change", 'testapp/users', 'recorded under the project in the registry');
    }

    ($code, $out, $err) = punk($root, 'pending');
    is($code, 0, 'punk sqitch pending: exit 0 once deployed');
    like($out, qr/Deployed: 1\nNothing pending/, 'saying so');

    ($code, $out, $err) = punk($root, 'status');
    is($code, 0, 'punk sqitch status');
    like($out, qr/Nothing to deploy \(up-to-date\)/, 'up to date');

    ($code, $out, $err) = punk($root, 'verify');
    is($code, 0, 'punk sqitch verify') or diag $err;

    ($code, $out, $err) = punk($root, 'deploy', '--target', 'db:sqlite:var/other/explicit.db');
    is($code, 0, 'an explicit --target after the verb wins') or diag $err;
    ok(-f "$root/var/other/explicit.db", 'and deploys there');

    # from outside, --dir points at the application
    ($code, $out, $err) = punk("$dir", '--dir', $root, 'status');
    is($code, 0, '--dir points at the application from anywhere') or diag $err;

    # from a subdirectory: the root is found and is the cwd for the call
    File::Path::make_path("$root/lib/deep");
    ($code, $out, $err) = punk("$root/lib/deep", 'status');
    is($code, 0, 'run from a subdirectory of the application');
    like($out, qr/Nothing to deploy/, 'against the same database');

    # --env: another layer, another database
    ($code, $out, $err) = punk($root, '--env', 'staging', 'deploy');
    is($code, 0, '--env staging deploys') or diag $err;
    like($out, qr{db:sqlite:/\S*/var/staging/app\.db}, 'to the staging layer\'s database');
    ok(-f "$root/var/staging/app.db", 'which now exists');

    # a failing change is Sqitch's exit code and message, not a crash
    ($code, $out, $err) = punk($root, 'add', 'broken', '-n', 'broken');
    write_file("$root/sqitch/deploy/broken.sql", "THIS IS NOT SQL;\n");
    write_file("$root/sqitch/revert/broken.sql", "SELECT 1;\n");
    write_file("$root/sqitch/verify/broken.sql", "SELECT 1;\n");
    # the sqlite3 client is a child process writing to the real fd 2, which
    # no Perl-level capture sees: park it on /dev/null for this one call
    ($code, $out, $err) = do {
        require POSIX;
        open my $null, '>', File::Spec->devnull or die $!;
        my $saved = POSIX::dup(2);
        POSIX::dup2(fileno($null), 2);
        my @r = punk($root, 'deploy');
        POSIX::dup2($saved, 2);
        POSIX::close($saved);
        @r;
    };
    is($code, 2, 'a failing deploy is exit 2 - Sqitch\'s own code for it');
    like($err, qr/Deploy failed/, 'with Sqitch\'s own message on stderr');

    # sqitch's own help for a verb comes through
    ($code, $out, $err) = punk($root, 'help', 'deploy');
    is($code, 0, 'punk sqitch help deploy');
    like($out, qr/sqitch deploy \[options\]/, 'renders the page into the captured stdout - no perldoc, no pager');
}

sub slurp { my ($p) = @_; open my $fh, '<', $p or die "$p: $!"; local $/; <$fh> }

done_testing();
