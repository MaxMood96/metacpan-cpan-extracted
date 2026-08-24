#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();
use File::Path ();
use Cwd ();
use FindBin ();

# Plugin-shipped projects: two test plugins register Sqitch projects, the
# second depending on the first and the application on the second. The
# registry rules (names, duplicates, cycles, engines) need nothing
# installed; the deploy half needs App::Sqitch, DBD::SQLite and sqlite3.

BEGIN {
    @INC = map { File::Spec->rel2abs($_) } @INC;   # the runs chdir
    plan skip_all => 'Punk required' unless eval { require Punk; 1 };
}
use lib "$FindBin::Bin/lib";
use Punk::Plugin::Sqitch ();
use Punk::Sqitch ();
no warnings 'once';   # $Punk::Command::OUT / $ERR, the capture seam

sub write_file {
    my ($path, $body) = @_;
    my ($vol, $dir) = File::Spec->splitpath($path);
    File::Path::make_path($dir) if length $dir && !-d $dir;
    open my $fh, '>', $path or die "$path: $!";
    print $fh $body;
    close $fh;
}
# a Sqitch project on disk: [ change, [deps], deploy sql, revert sql, verify sql ]
sub project {
    my ($dir, $name, @changes) = @_;
    my $plan = "%syntax-version=1.0.0\n%project=$name\n\n";
    my $t = 0;
    for my $c (@changes) {
        my ($change, $deps, $deploy, $revert, $verify) = @$c;
        $plan .= sprintf "%s%s 2026-08-23T10:%02d:00Z T <t\@e> # %s\n",
            $change, (@$deps ? ' [' . join(' ', @$deps) . ']' : ''), ++$t, $change;
        write_file("$dir/deploy/$change.sql", "$deploy\n");
        write_file("$dir/revert/$change.sql", "$revert\n");
        write_file("$dir/verify/$change.sql", "$verify\n");
    }
    write_file("$dir/sqitch.plan", $plan);
    return $dir;
}

my $dir  = File::Temp->newdir;
my $root = "$dir/app";
my $p1 = project("$dir/plug1", 'punk_first',
    [ keys => [], 'CREATE TABLE first_keys (id INTEGER PRIMARY KEY, digest TEXT NOT NULL);',
                  'DROP TABLE first_keys;', 'SELECT id, digest FROM first_keys WHERE 0;' ]);
my $p2 = project("$dir/plug2", 'punk_second',
    [ extra => ['punk_first:keys'], 'CREATE TABLE second_extra (id INTEGER PRIMARY KEY, key_id INTEGER REFERENCES first_keys(id));',
                  'DROP TABLE second_extra;', 'SELECT id, key_id FROM second_extra WHERE 0;' ]);

# ---- the registry rules, on a registrar-shaped stand-in ------------------------------
{
    package Fake::App; sub new { bless { class => $_[1] }, $_[0] } sub caller_class { $_[0]{class} }
}
{
    my $app = Fake::App->new('RulesApp');
    Punk::Plugin::Sqitch->project($app, punk_first => $p1);
    Punk::Plugin::Sqitch->project($app, punk_second => $p2, engines => ['sqlite', 'pg']);
    my $list = Punk::Plugin::Sqitch->projects_for('RulesApp', app_project => 'rulesapp');
    is_deeply([ map { $_->{name} } @$list ], [qw(punk_first punk_second)], 'two projects, in dependency order');
    is($list->[1]{owner}, 'main', 'the owner is the registering package');
    is_deeply($list->[1]{engines}, ['sqlite', 'pg'], 'engines recorded');
    is_deeply($list->[1]{plan}{requires}, ['punk_first'], 'the plan\'s cross-project requirement was read');

    my $e = ''; eval { Punk::Plugin::Sqitch->project($app, punk_first => $p1) } or $e = $@;
    like($e, qr/project 'punk_first' is registered twice: by main and by main/, 'a duplicate name croaks naming both owners');
    $e = ''; eval { Punk::Plugin::Sqitch->project($app, 'bad name' => $p1) } or $e = $@;
    like($e, qr/'bad name' is not a Sqitch project name/, 'a name Sqitch would refuse croaks');
    $e = ''; eval { Punk::Plugin::Sqitch->project($app, punk_other => $p1) } or $e = $@;
    like($e, qr/registered as 'punk_other' by main but its plan says %project=punk_first/, 'a name that is not the plan\'s %project croaks');
    $e = ''; eval { Punk::Plugin::Sqitch->project($app, punk_none => "$dir/nowhere") } or $e = $@;
    like($e, qr/'punk_none' \(main\): .*nowhere' is not a directory/, 'a missing directory croaks');
    $e = ''; eval { Punk::Plugin::Sqitch->project($app, punk_x => $p1, colour => 1) } or $e = $@;
    like($e, qr/unknown option 'colour' \(known: engines\)/, 'an unknown option croaks');
    $e = ''; eval { Punk::Plugin::Sqitch->project($app, punk_x => $p1, engines => ['Not An Engine']) } or $e = $@;
    like($e, qr/'Not An Engine' is not an engine name/, 'something that is not an engine name croaks - any Sqitch engine is accepted');
}
{
    # registration order is a tiebreak, not the order: the dependent first
    my $app = Fake::App->new('OrderApp');
    Punk::Plugin::Sqitch->project($app, punk_second => $p2);
    Punk::Plugin::Sqitch->project($app, punk_first => $p1);
    is_deeply([ map { $_->{name} } @{ Punk::Plugin::Sqitch->projects_for('OrderApp') } ],
        [qw(punk_first punk_second)], 'a project deploys after the one it requires whatever the registration order');
}
{
    my $app = Fake::App->new('MissingApp');
    Punk::Plugin::Sqitch->project($app, punk_second => $p2);
    my $e = ''; eval { Punk::Plugin::Sqitch->projects_for('MissingApp') } or $e = $@;
    like($e, qr/project 'punk_second' \(main\) requires project 'punk_first', which no plugin registered/,
        'a requirement nobody registered croaks naming the plugin');
}
{
    my $pa = project("$dir/cyc_a", 'cyc_a', [ a => ['cyc_b:b'], 'SELECT 1;', 'SELECT 1;', 'SELECT 1;' ]);
    my $pb = project("$dir/cyc_b", 'cyc_b', [ b => ['cyc_a:a'], 'SELECT 1;', 'SELECT 1;', 'SELECT 1;' ]);
    my $app = Fake::App->new('CycleApp');
    Punk::Plugin::Sqitch->project($app, cyc_a => $pa);
    Punk::Plugin::Sqitch->project($app, cyc_b => $pb);
    my $e = ''; eval { Punk::Plugin::Sqitch->projects_for('CycleApp') } or $e = $@;
    like($e, qr/depend on each other in a cycle: cyc_a -> cyc_b -> cyc_a/, 'a cycle croaks naming it');
}
{
    my $pa = project("$dir/needs_app", 'needs_app', [ a => ['myapp:users'], 'SELECT 1;', 'SELECT 1;', 'SELECT 1;' ]);
    my $app = Fake::App->new('NeedsApp');
    Punk::Plugin::Sqitch->project($app, needs_app => $pa);
    my $e = ''; eval { Punk::Plugin::Sqitch->projects_for('NeedsApp', app_project => 'myapp') } or $e = $@;
    like($e, qr/requires the application's own project 'myapp', which deploys after every plugin's/,
        'a plugin project that needs the application\'s croaks');
}
{
    # the registry-name policy
    my $app_project = { name => 'x', dir => $root, conf => { 'core.registry' => 'meta' }, plugin => 0 };
    my $e = ''; eval { Punk::Sqitch->project_list($app_project, [ { name => 'p' } ]) } or $e = $@;
    like($e, qr/names the registry 'meta', and a plugin project cannot see that/, 'a renamed registry with plugin projects croaks');
    is_deeply(Punk::Sqitch->project_list($app_project, []), [ $app_project ], 'and without plugins it is nobody\'s business');
}

# ---- an application with both plugins: the boot check and the CLI -----------------------
write_file("$root/app.psgi", "use TestApp2; TestApp2->to_app;\n");
write_file("$root/config/punk.yml", "database:\n  dsn: dbi:SQLite:dbname=var/app.db\n");
File::Path::make_path("$root/var");
write_file("$root/lib/TestApp2.pm", <<"PM");
package TestApp2;
use Punk;
plugin '+Punk::Plugin::TestSchema'  => { name => 'punk_first',  dir => '$p1' };
plugin '+Punk::Plugin::TestSchemaB' => { name => 'punk_second', dir => '$p2', engines => ['sqlite'] };
plugin 'Sqitch' => { check => 'warn' };
get '/' => sub { \$_[0]->text('ok') };
1;
PM
# the application's own project: one change depending on the second plugin's
project($root, 'testapp2',
    [ users => ['punk_second:extra'], 'CREATE TABLE users (id INTEGER PRIMARY KEY, extra_id INTEGER REFERENCES second_extra(id));',
                'DROP TABLE users;', 'SELECT id, extra_id FROM users WHERE 0;' ]);

{
    # the boot check, at the plugin line (or to_app), covers every project
    my @w;
    local $SIG{__WARN__} = sub { push @w, $_[0] };
    local @INC = ("$root/lib", @INC);
    my $cwd = Cwd::getcwd();
    chdir $root or die $!;
    my $ok = eval { require TestApp2; TestApp2->to_app; 1 };
    my $err = $@;
    chdir $cwd;
    ok($ok, 'the application compiles with check => warn') or diag $err;
    is(scalar @w, 1, 'one warning');
    like($w[0], qr/1 change pending for project 'punk_first' \(keys\); 1 change pending for project 'punk_second' \(extra\); 1 change pending for project 'testapp2' \(users\)/,
        'naming every project\'s pending changes, plugins first');
    my $results = Punk::Plugin::Sqitch->projects_for('TestApp2', app_project => 'testapp2');
    is_deeply([ map { $_->{name} } @$results ], [qw(punk_first punk_second)], 'both plugin projects registered through the real plugin seam');
}

SKIP: {
    skip 'App::Sqitch, DBD::SQLite and the sqlite3 client required for the deploys', 21
        unless eval { require App::Sqitch; require DBI; require DBD::SQLite; 1 }
            && `sqlite3 -version 2>/dev/null` =~ /\A\d/;
    require Punk::Command;
    require Punk::Command::Sqitch;
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
    sub headers { my ($out) = @_; [ $out =~ /^# project (\S+)/mg ] }

    my ($code, $out, $err) = punk($root, 'pending');
    is($code, 1, 'pending: exit 1 with everything pending');
    is_deeply([ $out =~ /^# Project:\s+(\S+)/mg ], [qw(punk_first punk_second testapp2)], 'pending lists every project, in deploy order');

    ($code, $out, $err) = punk($root, 'deploy');
    is($code, 0, 'deploy over every project') or diag $err;
    is_deeply(headers($out), [qw(punk_first punk_second testapp2)], 'the plugins in dependency order, then the application');
    like($out, qr/\+ keys \.+ ok.*\+ extra \.+ ok.*\+ users \.+ ok/s, 'every change deployed, in that order');
    {
        my $reg = DBI->connect("dbi:SQLite:dbname=$root/var/sqitch.db", '', '', { RaiseError => 1 });
        my $rows = $reg->selectall_arrayref('SELECT project, change FROM changes ORDER BY committed_at');
        is_deeply($rows, [ [punk_first => 'keys'], [punk_second => 'extra'], [testapp2 => 'users'] ],
            'one registry, three projects - the plugin projects ran with the target made absolute');
        my $db = DBI->connect("dbi:SQLite:dbname=$root/var/app.db", '', '', { RaiseError => 1 });
        my ($n) = $db->selectrow_array("SELECT COUNT(*) FROM sqlite_master WHERE name IN ('first_keys','second_extra','users')");
        is($n, 3, 'and all three tables exist in the one database');
    }

    ($code, $out, $err) = punk($root, 'pending');
    is($code, 0, 'pending: exit 0 once everything is deployed');
    is(scalar(() = $out =~ /Nothing pending/g), 3, 'three times nothing');

    ($code, $out, $err) = punk($root, 'status');
    is($code, 0, 'status over every project');
    is_deeply(headers($out), [qw(punk_first punk_second testapp2)], 'with a header per project');
    ($code, $out, $err) = punk($root, '--project', 'punk_second', 'status');
    is($code, 0, '--project: one project');
    is_deeply(headers($out), [], 'and no header for a single one');
    like($out, qr/Project:\s+punk_second/, 'the one asked for');
    ($code, $out, $err) = punk($root, '--project', 'nope', 'status');
    is($code, 1, 'an unknown --project is an error');
    like($err, qr/no project 'nope' \(have: punk_first, punk_second, testapp2\)/, 'listing them');

    ($code, $out, $err) = punk($root, 'verify');
    is($code, 0, 'verify over every project') or diag $err;

    ($code, $out, $err) = punk($root, 'revert', '-y');
    is($code, 0, 'revert -y over every project') or diag $err;
    is_deeply(headers($out), [qw(testapp2 punk_second punk_first)], 'the application first, then the plugins in reverse');

    ($code, $out, $err) = punk($root, '--app-only', 'deploy');
    is($code, 2, '--app-only deploy with the plugin projects reverted fails - the dependency is missing');
    like($err, qr/punk_second:extra/, 'and Sqitch names the missing change');
}

done_testing();
