#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use File::Temp ();
use File::Spec ();
use File::Path ();
use Cwd ();

# The same ground as t/02 and t/05, against a real PostgreSQL: the target
# built from a Pg dsn, the registry found in a SCHEMA rather than a file,
# `pending` over two projects, deploy, verify and revert.
#
# Gated on PUNK_SQITCH_PG_DSN, the DBIx::Loop convention - the dsn of a
# database this test may create and drop tables in, and whose `sqitch`
# schema it will drop:
#
#   createdb punk_sqitch_test
#   PUNK_SQITCH_PG_DSN=dbi:Pg:dbname=punk_sqitch_test prove -lv t/07-pg.t

my $DSN = $ENV{PUNK_SQITCH_PG_DSN};
BEGIN {
    @INC = map { File::Spec->rel2abs($_) } @INC;   # the runs chdir
}
BEGIN {
    plan skip_all => 'PUNK_SQITCH_PG_DSN is not set' unless $ENV{PUNK_SQITCH_PG_DSN};
    plan skip_all => 'DBI and DBD::Pg required' unless eval { require DBI; require DBD::Pg; 1 };
    plan skip_all => 'App::Sqitch required' unless eval { require App::Sqitch; 1 };
    plan skip_all => 'the psql client is required (Sqitch runs scripts through it)'
        unless `psql --version 2>/dev/null` =~ /\d/;
}
use Punk::Sqitch;
use Punk::Command ();
use Punk::Command::Sqitch ();
use Punk::Plugin::Sqitch ();
no warnings 'once';

my %DB = (dsn => $DSN,
          (defined $ENV{PUNK_SQITCH_PG_USER} ? (user => $ENV{PUNK_SQITCH_PG_USER}) : ()),
          (defined $ENV{PUNK_SQITCH_PG_PASS} ? (password => $ENV{PUNK_SQITCH_PG_PASS}) : ()));

my $dbh = DBI->connect($DSN, $DB{user}, $DB{password}, { RaiseError => 1, PrintError => 0 })
    or plan skip_all => "cannot connect to $DSN";
# a clean slate, and the same on the way out
sub scrub {
    my $h = DBI->connect($DSN, $DB{user}, $DB{password}, { RaiseError => 0, PrintError => 0 }) or return;
    $h->do($_) for 'DROP TABLE IF EXISTS pg_extra', 'DROP TABLE IF EXISTS pg_items',
                   'DROP SCHEMA IF EXISTS sqitch CASCADE';
    $h->disconnect;
}
scrub();
END { scrub() }

sub write_file {
    my ($path, $body) = @_;
    my ($vol, $dir) = File::Spec->splitpath($path);
    File::Path::make_path($dir) if length $dir && !-d $dir;
    open my $fh, '>', $path or die "$path: $!";
    print $fh $body;
    close $fh;
}
sub project {
    my ($dir, $name, @changes) = @_;
    my $plan = "%syntax-version=1.0.0\n%project=$name\n\n";
    my $t = 0;
    for my $c (@changes) {
        my ($change, $deps, $deploy, $revert, $verify) = @$c;
        $plan .= sprintf "%s%s 2026-08-23T13:%02d:00Z T <t\@e> # %s\n",
            $change, (@$deps ? ' [' . join(' ', @$deps) . ']' : ''), ++$t, $change;
        write_file("$dir/deploy/$change.sql", "BEGIN;\n$deploy\nCOMMIT;\n");
        write_file("$dir/revert/$change.sql", "BEGIN;\n$revert\nCOMMIT;\n");
        write_file("$dir/verify/$change.sql", "$verify\n");
    }
    write_file("$dir/sqitch.plan", $plan);
    return $dir;
}

# ---- the target and the registry, from a Pg dsn --------------------------------------
{
    my $t = Punk::Sqitch->target_for({ %DB });
    is($t->{engine}, 'pg', 'a Pg dsn is the pg engine');
    like($t->{uri}, qr/\Adb:pg:/, 'and a db:pg: target');
    my $reg = Punk::Sqitch->registry_for({ %DB }, $t, {});
    is($reg->{kind}, 'schema', 'the registry is a schema');
    is($reg->{name}, 'sqitch', 'named sqitch by default');
    is($reg->{connect}[0], $DSN, 'reached through the application\'s own connection');
}

# ---- an application with a plugin project ----------------------------------------------
my $dir  = File::Temp->newdir;
my $root = "$dir/app";
my $plug = project("$dir/plug", 'punk_pgplug',
    [ items => [], 'CREATE TABLE pg_items (id bigserial PRIMARY KEY, name text NOT NULL);',
                   'DROP TABLE pg_items;', 'SELECT id, name FROM pg_items WHERE FALSE;' ]);
write_file("$root/app.psgi", "use PgApp; PgApp->to_app;\n");
write_file("$root/config/punk.yml", "database:\n  dsn: $DSN\n"
    . (defined $DB{user} ? "  user: $DB{user}\n" : '')
    . (defined $DB{password} ? "  password: $DB{password}\n" : ''));
write_file("$root/lib/PgApp.pm", <<"PM");
package PgApp;
use Punk;
plugin '+Punk::Plugin::TestSchema' => { name => 'punk_pgplug', dir => '$plug' };
plugin 'Sqitch' => { check => 'warn' };
get '/' => sub { \$_[0]->text('ok') };
1;
PM
project("$root/sqitch", 'pgapp',
    [ extra => ['punk_pgplug:items'],
      'CREATE TABLE pg_extra (id bigserial PRIMARY KEY, item_id bigint REFERENCES pg_items(id));',
      'DROP TABLE pg_extra;', 'SELECT id, item_id FROM pg_extra WHERE FALSE;' ]);

sub punk {
    my (@args) = @_;
    my ($out, $err) = ('', '');
    open my $oh, '>', \$out or die $!;
    open my $eh, '>', \$err or die $!;
    local $Punk::Command::OUT = $oh;
    local $Punk::Command::ERR = $eh;
    my $cwd = Cwd::getcwd();
    chdir $root or die $!;
    my $code = Punk::Command->main('sqitch', @args);
    chdir $cwd;
    close $oh; close $eh;
    return ($code, $out, $err);
}

{
    my ($code, $out, $err) = punk('pending');
    is($code, 1, 'pending: exit 1 with both projects undeployed');
    is_deeply([ $out =~ /^# Project:\s+(\S+)/mg ], [qw(punk_pgplug pgapp)], 'both listed, plugin first');
    like($out, qr/# Registry: schema sqitch/, 'the registry is named as a schema');
}
{
    my ($code, $out, $err) = punk('deploy');
    is($code, 0, 'deploy over both projects') or diag $err;
    like($out, qr/\+ items \.+ ok.*\+ extra \.+ ok/s, 'in dependency order');
    my $rows = $dbh->selectall_arrayref('SELECT project, change FROM sqitch.changes ORDER BY committed_at');
    is_deeply($rows, [ [punk_pgplug => 'items'], [pgapp => 'extra'] ],
        'one registry schema, both projects');
    my ($n) = $dbh->selectrow_array(
        "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('pg_items','pg_extra')");
    is($n, 2, 'both tables exist');
}
{
    my ($code, $out, $err) = punk('pending');
    is($code, 0, 'pending: exit 0 once deployed');
    my ($code2, $out2) = punk('verify');
    is($code2, 0, 'verify over both projects') or diag $out2;
}
{
    # The boot check, against a real registry schema - in a CHILD process,
    # because `punk sqitch` has already loaded the application class in this
    # one with the check held off ($SKIP_CHECK), which is exactly what it is
    # for. A booting server is a fresh process, and so is this.
    my $script = <<'PL';
use strict; use warnings;
my ($root) = @ARGV;
chdir $root or die "chdir $root: $!";
unshift @INC, "$root/lib";
my @w;
$SIG{__WARN__} = sub { push @w, $_[0] };
require PgApp;
PgApp->to_app;
require Punk::Plugin::Sqitch;
my $r = Punk::Plugin::Sqitch->result_for('PgApp');
printf "kind=%s pending=%d warnings=%d\n",
    $r->{registry}{kind}, scalar @{ $r->{pending} }, scalar @w;
PL
    my $file = "$dir/boot.pl";
    write_file($file, $script);
    my @inc = map { "-I$_" } grep { !ref && -d } @INC;
    my $out = `$^X @inc \Q$file\E \Q$root\E 2>&1`;
    is($? >> 8, 0, 'the application compiles in a fresh process with everything deployed') or diag $out;
    like($out, qr/kind=schema /, 'the check read the registry schema');
    like($out, qr/pending=0 /, 'nothing pending');
    like($out, qr/warnings=0/, 'and it said nothing');
}
{
    my ($code, $out, $err) = punk('revert', '-y');
    is($code, 0, 'revert -y over both projects') or diag $err;
    is_deeply([ $out =~ /^# project (\S+)/mg ], [qw(pgapp punk_pgplug)], 'the application first, then the plugin');
    my ($n) = $dbh->selectrow_array(
        "SELECT count(*) FROM information_schema.tables WHERE table_name IN ('pg_items','pg_extra')");
    is($n, 0, 'both tables gone');
}

done_testing();
