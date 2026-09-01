#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Spec ();
use Cwd ();

# `punk apikey`, one process per command.
#
# Not in process, and for a reason worth stating: load_app runs the
# application's own app.psgi, which ends in `Class->to_app` - and to_app
# compiles once per class, so a second call in the same interpreter croaks
# "already compiled". Every application-loading punk command is therefore
# once per process by construction, which is exactly how `punk` runs anyway.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
    plan skip_all => 'Punk::Command->load_app required (Punk 0.32+)'
        unless eval { require Punk::Command; Punk::Command->can('load_app') };
    plan skip_all => 'DBD::SQLite required'
        unless eval { require DBI; require DBD::SQLite; 1 };
}

use File::Temp ();
use File::Path ();
use Punk::Command::Apikey ();
use Punk::Plugin::APIKey ();   # for its shipped DDL, below

my $CWD = Cwd::getcwd();
END { chdir $CWD if $CWD }

# ---- an application on disk --------------------------------------------------

my $root = File::Temp::tempdir(CLEANUP => 1);
my $db   = File::Spec->catfile($root, 'app.db');

{
    File::Path::make_path(File::Spec->catdir($root, 'lib'));
    my @inc = map { File::Spec->rel2abs($_) } grep { !ref } @INC;
    my $inc = join ",\n    ", map { "'$_'" } @inc;

    # __FILE__ rather than FindBin, deliberately. FindBin computes $Bin once,
    # when it is first loaded, so an app.psgi loaded IN PROCESS by
    # Punk::Command->load_app sees whatever directory FindBin was loaded from
    # - this test file's, since it uses FindBin itself. A fresh `punk`
    # process gets away with it because nothing there loads FindBin before
    # the application does. __FILE__ is right either way.
    _spew(File::Spec->catfile($root, 'app.psgi'), <<"PSGI");
use strict;
use warnings;
use File::Basename ();
use File::Spec ();
BEGIN {
    unshift \@INC,
    $inc;
    my \$root = File::Basename::dirname(File::Spec->rel2abs(__FILE__));
    unshift \@INC, "\$root/lib";
    chdir \$root;
}
use CliApp;
CliApp->to_app;
PSGI

    _spew(File::Spec->catfile($root, 'lib', 'CliApp.pm'), <<"CLASS");
package CliApp;
use Punk;
use Punk::Plugin::APIKey;

database dsn => 'dbi:SQLite:dbname=app.db';
model 'Punk::Model::ApiKey';

plugin 'APIKey' => {
    model  => 'Punk::Model::ApiKey',
    owner  => 'owner_id',
    kinds  => { live => 'sk_live_', test => 'sk_test_' },
    scopes => [qw(read write admin)],
};

get '/' => sub { \$_[0]->text('ok') };

1;
CLASS

    # the table, applied from the shipped script
    my $pm = $INC{'Punk/Plugin/APIKey.pm'};
    (my $dir = $pm) =~ s/\.pm\z//;
    my $sql = _slurp(File::Spec->catfile($dir, 'sqitch', 'sqlite', 'deploy',
                                         'api_keys.sql'));
    $sql =~ s/^\s*(?:BEGIN|COMMIT)\s*;\s*$//gmi;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '',
                           { RaiseError => 1, PrintError => 0 });
    $dbh->do($_) for grep { /\S/ } split /;\s*\n/, $sql;
    $dbh->disconnect;
}

# ---- the harness -------------------------------------------------------------

# @INC goes over absolute: the child ends up in the application root once
# app.psgi has chdir-ed there, and a relative -I stops resolving - which is
# how a blib quietly loses to an installed copy.
my @INC_ABS = map { Cwd::abs_path($_) || $_ } grep { !ref } @INC;

sub punk {
    my (@args) = @_;
    my $code = <<'CHILD';
use Punk::Command ();
use Punk::Command::Apikey ();
my ($out, $err) = ('', '');
open my $o, '>', \$out or die $!;
open my $e, '>', \$err or die $!;
my $rc = do {
    local $Punk::Command::OUT = $o;
    local $Punk::Command::ERR = $e;
    Punk::Command->main(@ARGV);
};
close $o; close $e;
print "\0CODE\0$rc\0OUT\0$out\0ERR\0$err";
CHILD
    my $cmd = join ' ', _q($^X), (map { '-I' . _q($_) } @INC_ABS),
                        '-e', _q($code), '--', map { _q($_) } @args;
    my $raw = qx{$cmd 2>/dev/null};
    my ($rc, $out, $err) = $raw =~ /\0CODE\0(.*?)\0OUT\0(.*?)\0ERR\0(.*)\z/s;
    return (defined $rc ? $rc : 255, $out // '', $err // '');
}

sub _q { my $s = shift; $s =~ s/'/'\\''/g; return "'$s'" }

# ---- list, on an empty table -------------------------------------------------

{
    my ($code, $out, $err) = punk('apikey', 'list', '--dir', $root);
    is($code, 0, 'apikey list runs against a real application') or diag $err;
    like($out, qr/no keys/, 'and says so when there are none');
}

# ---- issue -------------------------------------------------------------------

my $issued;
{
    my ($code, $out, $err) = punk('apikey', 'issue', '--dir', $root,
                            '--owner', 42, '--label', 'CI',
                            '--scopes', 'read,write');
    is($code, 0, 'apikey issue runs') or diag $err;
    ($issued) = $out =~ /(sk_\w+_\S+)/;
    ok($issued, 'and prints a key');
    is(length $issued, 8 + 43 + 6, 'of the right shape');
    like($out, qr/only time this key is shown/,
        'saying plainly that it cannot be shown again');
}

{
    # what reached the table is the digest, and never the key
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '',
                           { RaiseError => 1, PrintError => 0 });
    my $rows = $dbh->selectall_arrayref(
        'SELECT id, owner_id, label, prefix, digest, scopes, kind FROM api_keys',
        { Slice => {} });
    is(scalar @$rows, 1, 'one row');
    is($rows->[0]{owner_id}, 42, 'for the owner asked for');
    is($rows->[0]{label}, 'CI', 'with the label');
    is($rows->[0]{scopes}, 'read write', 'and the scopes, space joined');
    is($rows->[0]{kind}, 'live', 'the default kind');
    isnt($rows->[0]{digest}, $issued, 'the key itself is not in the table');
    unlike(out_of($dbh), qr/\Q$issued\E/,
        'and not anywhere else in the row either');
    $dbh->disconnect;
}

sub out_of {
    my ($dbh) = @_;
    my $all = $dbh->selectall_arrayref('SELECT * FROM api_keys');
    return join '|', map { join ',', map { defined $_ ? $_ : '' } @$_ } @$all;
}

# ---- list, with a row --------------------------------------------------------

{
    my ($code, $out) = punk('apikey', 'list', '--dir', $root);
    is($code, 0, 'list runs with a row');
    like($out, qr/\bCI\b/, 'showing the label');
    like($out, qr/\blive\b/, 'the state');
    like($out, qr/\Q@{[ substr($issued, 0, 16) ]}\E/,
        'and the prefix, which identifies a key without being one');
    unlike($out, qr/\Q$issued\E/, 'never the key');
    unlike($out, qr/[0-9a-f]{64}/, 'and never the digest');
}

{
    my ($code, $out) = punk('apikey', 'list', '--dir', $root, '--owner', 7);
    is($code, 0, '--owner runs');
    like($out, qr/no keys/, 'and filters to that owner');
}

# ---- revoke ------------------------------------------------------------------

{
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '',
                           { RaiseError => 1, PrintError => 0 });
    my ($id) = $dbh->selectrow_array('SELECT id FROM api_keys LIMIT 1');
    $dbh->disconnect;

    my ($code, $out) = punk('apikey', 'revoke', '--dir', $root, $id);
    is($code, 0, 'apikey revoke runs');
    like($out, qr/revoked key $id/, 'and says what it revoked');

    $dbh = DBI->connect("dbi:SQLite:dbname=$db", '', '',
                        { RaiseError => 1, PrintError => 0 });
    my ($revoked) = $dbh->selectrow_array(
        'SELECT revoked FROM api_keys WHERE id = ?', undef, $id);
    ok($revoked, 'the row carries a timestamp');
    my ($count) = $dbh->selectrow_array('SELECT COUNT(*) FROM api_keys');
    is($count, 1, 'and is still there - revoke is not a delete');
    $dbh->disconnect;

    ($code, $out) = punk('apikey', 'list', '--dir', $root);
    like($out, qr/revoked/, 'so it is still listed, marked revoked');
}

# ---- misuse ------------------------------------------------------------------

{
    my ($code, undef, $err) = punk('apikey', 'issue', '--dir', $root,
                                   '--label', 'no owner');
    is($code, 2, 'issue with no owner is a usage error');
    like($err, qr/--owner is required/, 'saying which');
    like($err, qr/usage: punk apikey issue/, 'with the usage');
}

{
    my ($code, undef, $err) = punk('apikey', 'issue', '--dir', $root,
                                   '--owner', 1, '--label', 'x',
                                   '--scopes', 'wrte');
    is($code, 1, 'a scope outside the vocabulary fails');
    like($err, qr/scope 'wrte' is not in the vocabulary/,
        'naming what it could have been');
}

{
    my ($code, undef, $err) = punk('apikey', 'revoke', '--dir', $root);
    is($code, 2, 'revoke with no id is a usage error');
    like($err, qr/an id is required/, 'saying so');
}

{
    my ($code, undef, $err) = punk('apikey', 'list', '--dir',
                                   File::Temp::tempdir(CLEANUP => 1));
    is($code, 1, 'a directory with no application exits 1');
    like($err, qr/no application found/, 'with the reason');
}

# ---- help --------------------------------------------------------------------

{
    my ($code, $out) = punk('help', 'apikey');
    is($code, 0, 'punk help apikey works');
    like($out, qr/^\s+issue\s/m, 'listing its verbs');
    like($out, qr/^\s+revoke\s/m, 'all of them');
}

{
    my ($code, $out) = punk('apikey', 'issue', '--help');
    is($code, 0, 'and a verb has its own help');
    like($out, qr/--scopes LIST/, 'generated from the declared options');
    like($out, qr/no way to show it again/,
        'including the thing an operator most needs to know');
}

sub _slurp { open my $f, '<', $_[0] or die "$_[0]: $!"; local $/; return <$f> }
sub _spew  { open my $f, '>', $_[0] or die "$_[0]: $!"; print $f $_[1]; close $f }

done_testing();
