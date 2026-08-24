#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();
use File::Path ();
use Punk::Sqitch;

# The check's pieces, without App::Sqitch or the sqlite3 client: the conf
# reader, the plan parser, where the registry is per engine, and `pending`
# against a registry built by hand in the shape Sqitch's SQLite engine
# creates (the `changes` table and the columns the query reads).

BEGIN {
    plan skip_all => 'DBI + DBD::SQLite required' unless eval { require DBI; require DBD::SQLite; 1 };
}

sub write_file {
    my ($path, $body) = @_;
    my ($vol, $dir) = File::Spec->splitpath($path);
    File::Path::make_path($dir) if length $dir && !-d $dir;
    open my $fh, '>', $path or die "$path: $!";
    print $fh $body;
    close $fh;
}

my $dir = File::Temp->newdir;

# ---- sqitch.conf -------------------------------------------------------------------
{
    write_file("$dir/c/sqitch.conf", <<'CONF');
[core]
	engine = sqlite
	# plan_file = sqitch.plan
	top_dir = db
[engine "sqlite"]
	registry = meta   ; trailing comment
	client = /opt/sqlite3
[target "prod"]
	uri = db:pg://h/shop
	registry = "quoted name"
CONF
    my $c = Punk::Sqitch->read_conf("$dir/c/sqitch.conf");
    is($c->{'core.engine'}, 'sqlite', 'core.engine');
    is($c->{'core.top_dir'}, 'db', 'core.top_dir');
    ok(!exists $c->{'core.plan_file'}, 'a commented key is not a key');
    is($c->{'engine.sqlite.registry'}, 'meta', 'engine.sqlite.registry, trailing comment stripped');
    is($c->{'target.prod.registry'}, 'quoted name', 'a quoted value, quotes stripped');
    is(Punk::Sqitch->conf_get($c, 'registry', 'sqlite'), 'meta', 'conf_get: engine before core');
    is(Punk::Sqitch->conf_get($c, 'registry', 'sqlite', 'prod'), 'quoted name', 'conf_get: target before engine');
    is(Punk::Sqitch->conf_get($c, 'registry', 'pg'), undef, 'conf_get: nothing for another engine');
    is(Punk::Sqitch->conf_get($c, 'top_dir', 'sqlite'), 'db', 'conf_get: core');
    is_deeply(Punk::Sqitch->read_conf("$dir/c/none.conf"), {}, 'no file is an empty conf');
    is(Punk::Sqitch->plan_file_for("$dir/c", $c, 'sqlite'),
        File::Spec->catfile("$dir/c", 'db', 'sqitch.plan'), 'plan_file_for: top_dir/sqitch.plan');
    is(Punk::Sqitch->plan_file_for("$dir/c", { 'core.plan_file' => 'x/my.plan' }, 'sqlite'),
        File::Spec->catfile("$dir/c", 'x', 'my.plan'), 'plan_file_for: plan_file relative to the root');
    is(Punk::Sqitch->plan_file_for("$dir/c", {}, 'sqlite'),
        File::Spec->catfile("$dir/c", 'sqitch.plan'), 'plan_file_for: the default');
}

# ---- sqitch.plan --------------------------------------------------------------------
{
    write_file("$dir/p/sqitch.plan", <<'PLAN');
%syntax-version=1.0.0
%project=demo
%uri=https://example.com/demo

# a comment
users 2026-08-23T09:47:30Z Someone <s@example.com> # users table
api_keys [users] 2026-08-23T09:47:31Z Someone <s@example.com> # api keys
@v1.0 2026-08-23T10:00:00Z Someone <s@example.com> # first release
users [users@v1.0] 2026-08-23T10:10:08Z Someone <s@example.com> # rework users

later 2026-08-23T10:20:00Z Someone <s@example.com> # not yet
PLAN
    my $p = Punk::Sqitch->read_plan("$dir/p/sqitch.plan");
    is($p->{project}, 'demo', 'project from %project');
    is($p->{uri}, 'https://example.com/demo', '%uri');
    is_deeply($p->{changes}, [qw(users api_keys users later)],
        'changes in order, the reworked one twice, comments blanks and tags skipped');
    is_deeply($p->{tags}, ['v1.0'], 'tags');
    write_file("$dir/p/noproj.plan", "%syntax-version=1.0.0\nusers 2026-08-23T09:47:30Z S <s\@e> # x\n");
    my $e = ''; eval { Punk::Sqitch->read_plan("$dir/p/noproj.plan") } or $e = $@;
    like($e, qr/names no %project/, 'a plan without %project croaks');
    $e = ''; eval { Punk::Sqitch->read_plan("$dir/p/missing.plan") } or $e = $@;
    like($e, qr/cannot read the plan/, 'a missing plan croaks');
}

# ---- where the registry is ----------------------------------------------------------------
{
    my $db = { dsn => 'dbi:SQLite:dbname=var/app.db' };
    my $t  = Punk::Sqitch->target_for($db);
    my $r  = Punk::Sqitch->registry_for($db, $t, {});
    is($r->{kind}, 'file', 'SQLite: the registry is a file');
    is($r->{path}, File::Spec->catpath('', 'var/', 'sqitch.db'),
        'beside the target, the registry name with the target\'s extension');
    is(Punk::Sqitch->registry_for($db, $t, { 'engine.sqlite.registry' => 'meta' })->{path},
        File::Spec->catpath('', 'var/', 'meta.db'), 'a renamed registry keeps the extension');
    is(Punk::Sqitch->registry_for($db, $t, { 'engine.sqlite.registry' => 'reg.sqlite' })->{path},
        File::Spec->catpath('', 'var/', 'reg.sqlite'), 'a registry name with a dot is used whole');
    is(Punk::Sqitch->registry_for($db, $t, { 'core.registry' => '/abs/reg.db' })->{path},
        '/abs/reg.db', 'an absolute registry is used as is');
    my $bare = { dsn => 'dbi:SQLite:dbname=var/app' };
    is(Punk::Sqitch->registry_for($bare, Punk::Sqitch->target_for($bare), {})->{path},
        File::Spec->catpath('', 'var/', 'sqitch'), 'a target with no extension gives a registry with none');

    my $pg = { dsn => 'dbi:Pg:host=h;dbname=shop', user => 'u', password => 'p' };
    my $rp = Punk::Sqitch->registry_for($pg, Punk::Sqitch->target_for($pg), {});
    is($rp->{kind}, 'schema', 'Pg: a schema');
    is($rp->{name}, 'sqitch', 'named sqitch by default');
    is_deeply($rp->{connect}, [ 'dbi:Pg:host=h;dbname=shop', 'u', 'p' ], 'reached through the application\'s own connection');
    my $my = { dsn => 'dbi:mysql:database=shop;host=h' };
    is(Punk::Sqitch->registry_for($my, Punk::Sqitch->target_for($my), { 'engine.mysql.registry' => 'reg' })->{kind},
        'database', 'mysql: a database');
    my $fb = { dsn => 'dbi:Firebird:dbname=/d/a.fdb;host=h' };
    is(Punk::Sqitch->registry_for($fb, Punk::Sqitch->target_for($fb), {})->{kind}, 'unknown',
        'Firebird: the check does not know where its registry is');
    my $cr = { dsn => 'dbi:Pg:dbname=x', sqitch_engine => 'cockroach' };
    is(Punk::Sqitch->registry_for($cr, Punk::Sqitch->target_for($cr), {})->{kind}, 'schema', 'CockroachDB: a schema, like Pg');
}

# ---- pending ------------------------------------------------------------------------------
# a registry in the shape Sqitch's SQLite engine creates, by hand
sub registry {
    my ($path, @rows) = @_;
    my ($vol, $d) = File::Spec->splitpath($path);
    File::Path::make_path($d) if length $d && !-d $d;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$path", '', '', { RaiseError => 1 });
    $dbh->do(<<'SQL');
CREATE TABLE changes (
    change_id       TEXT PRIMARY KEY,
    script_hash     TEXT,
    change          TEXT NOT NULL,
    project         TEXT NOT NULL,
    note            TEXT NOT NULL DEFAULT '',
    committed_at    DATETIME NOT NULL,
    committer_name  TEXT NOT NULL DEFAULT '',
    committer_email TEXT NOT NULL DEFAULT '',
    planned_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    planner_name    TEXT NOT NULL DEFAULT '',
    planner_email   TEXT NOT NULL DEFAULT ''
)
SQL
    my $i = 0;
    for my $r (@rows) {
        my ($project, $change) = @$r;
        $dbh->do('INSERT INTO changes (change_id, change, project, committed_at) VALUES (?,?,?,?)',
                 undef, sprintf('%040x', ++$i), $change, $project,
                 sprintf('2026-08-23 10:%02d:00', $i));
    }
    $dbh->disconnect;
}

my $root = "$dir/app";
write_file("$root/app.psgi", "1;\n");
write_file("$root/sqitch.plan", <<'PLAN');
%syntax-version=1.0.0
%project=demo

users 2026-08-23T09:47:30Z S <s@e> # users
api_keys [users] 2026-08-23T09:47:31Z S <s@e> # keys
@v1.0 2026-08-23T10:00:00Z S <s@e> # first
users [users@v1.0] 2026-08-23T10:10:08Z S <s@e> # rework
later 2026-08-23T10:20:00Z S <s@e> # later
PLAN
my %DB = (dsn => "dbi:SQLite:dbname=$root/var/app.db");
sub pend { Punk::Sqitch->pending(root => $root, database => { %DB }, @_) }

{
    my $r = pend();
    is($r->{project}, 'demo', 'fresh: the project');
    is($r->{deployed}, 0, 'fresh: nothing deployed');
    is_deeply($r->{pending}, [qw(users api_keys users later)], 'fresh: everything pending (no registry file is an answer)');
    ok(!$r->{error} && !$r->{drift}, 'fresh: no error, no drift');
    is($r->{registry}{path}, "$root/var/sqitch.db", 'fresh: where it looked');
}
{
    registry("$root/var/sqitch.db", [demo => 'users'], [demo => 'api_keys'], [other => 'x']);
    my $r = pend();
    is($r->{deployed}, 2, 'partial: two deployed (another project\'s row is not counted)');
    is_deeply($r->{pending}, [qw(users later)], 'partial: the rework and the new change are pending');
    unlink "$root/var/sqitch.db";
}
{
    registry("$root/var/sqitch.db", map { [demo => $_] } qw(users api_keys users));
    my $r = pend();
    is($r->{deployed}, 3, 'rework deployed: three rows');
    is_deeply($r->{pending}, ['later'], 'rework deployed: only the change after it is pending - counts, not names');
    unlink "$root/var/sqitch.db";
}
{
    registry("$root/var/sqitch.db", map { [demo => $_] } qw(users api_keys users later));
    my $r = pend();
    is($r->{deployed}, 4, 'up to date: four');
    is_deeply($r->{pending}, [], 'up to date: nothing pending');
    unlink "$root/var/sqitch.db";
}
{
    registry("$root/var/sqitch.db", map { [demo => $_] } qw(users api_keys users later extra));
    my $r = pend();
    like($r->{drift}, qr/registry holds 5 changes for project 'demo' but the plan lists 4/,
        'drift: more in the registry than the plan');
    is_deeply($r->{pending}, [], 'drift: nothing is called pending');
    unlink "$root/var/sqitch.db";
}
{
    registry("$root/var/sqitch.db", [demo => 'users'], [demo => 'something_else']);
    my $r = pend();
    like($r->{drift}, qr/last deployed change is 'something_else' but the plan's entry 2 is 'api_keys'/,
        'drift: the last deployed name is not the plan\'s entry at that position');
    unlink "$root/var/sqitch.db";
}
{
    # a renamed registry, through the conf
    registry("$root/var/meta.db", map { [demo => $_] } qw(users api_keys users later));
    my $r = pend(conf => { 'engine.sqlite.registry' => 'meta' });
    is($r->{deployed}, 4, 'a renamed registry is read where sqitch.conf says');
    unlink "$root/var/meta.db";
}
{
    # a registry file that is not a database: reachable is not readable
    write_file("$root/var/sqitch.db", "not a database\n");
    my $r = pend();
    like($r->{error}, qr/cannot read the registry/, 'a registry that cannot be read is an error, not "all pending"');
    is_deeply($r->{pending}, [qw(users api_keys users later)], 'with the plan\'s changes still listed for the caller');
    unlink "$root/var/sqitch.db";
}
{
    my $e = ''; eval { Punk::Sqitch->pending(root => "$dir/nowhere", database => { %DB }) } or $e = $@;
    like($e, qr/no plan at .*nowhere.*sqitch\.plan - run `punk sqitch init` first/, 'no plan croaks, naming the path and the fix');
    $e = ''; eval { Punk::Sqitch->pending(root => $root) } or $e = $@;
    like($e, qr/needs the database options/, 'no database croaks');
}

done_testing();
