#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;

# The DDL this distribution ships, against the model that reads it.
#
# t/10 proves the guard with a fake backend, which proves nothing about the
# columns. This applies the real sqlite/deploy/api_keys.sql through DBI and
# drives the plugin over it - so a column renamed in one place and not the
# other fails here rather than in somebody's deploy. No App::Sqitch needed:
# the point is the SQL, not the tool that ships it.

BEGIN {
    plan skip_all => 'Punk 0.32+ required'
        unless eval { require Punk; Punk->VERSION('0.32'); 1 };
    plan skip_all => 'DBD::SQLite required'
        unless eval { require DBI; require DBD::SQLite; 1 };
}

use File::Spec ();
use Punk::Plugin::APIKey ();
use Punk::Model::ApiKey ();

# The shipped script, found the way the plugin finds its project.
my $pm = $INC{'Punk/Plugin/APIKey.pm'} or die 'not loaded from a file';
(my $dir = $pm) =~ s/\.pm\z//;

# One file, one database, for the whole test: a :memory: handle per connect
# would be a different database each time.
my $db = File::Spec->catfile(File::Spec->tmpdir, "punk-apikey-$$.db");
unlink $db;
END { unlink $db if $db }

my $dsn = "dbi:SQLite:dbname=$db";

# ---- the api_keys DDL --------------------------------------------------------

{
    my $file = File::Spec->catfile($dir, 'sqitch', 'sqlite', 'deploy',
                                   'api_keys.sql');
    ok(-f $file, 'the sqlite deploy script ships') or do {
        diag("looked in $file");
        done_testing();
        exit;
    };

    my $sql = do { open my $fh, '<', $file or die $!; local $/; <$fh> };
    # Sqitch runs these through the sqlite3 client, which takes the whole
    # file; DBI wants one statement at a time, so the transaction wrapper is
    # dropped and the rest split on the semicolons.
    $sql =~ s/^\s*(?:BEGIN|COMMIT)\s*;\s*$//gmi;

    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1, PrintError => 0 });
    $dbh->do($_) for grep { /\S/ } split /;\s*\n/, $sql;

    my @cols = map { $_->[1] }
        @{ $dbh->selectall_arrayref('PRAGMA table_info(api_keys)') };
    is_deeply([ sort @cols ],
              [ sort qw(id owner_id kind label prefix digest scopes
                        rate_per_min expires revoked last_used created) ],
        'the api_keys table has exactly the columns the plugin reads');

    # The unique index on the digest is what makes the lookup an equality
    # test rather than a scan, and what stops two rows claiming one key.
    my $idx = $dbh->selectall_arrayref(
        "SELECT name, \"unique\" FROM pragma_index_list('api_keys')",
        { Slice => {} });
    my %by = map { $_->{name} => $_ } @$idx;
    ok($by{api_keys_digest}, 'with an index on the digest');
    ok($by{api_keys_digest}{unique}, 'which is unique');
    ok($by{api_keys_owner}, 'and one on the owner, for the account page');
    $dbh->disconnect;
}

# ---- the plugin over the real table ------------------------------------------

{
    package App::Keys;
    use Punk;
    use Punk::Plugin::APIKey;
    database dsn => $dsn;
    model 'Punk::Model::ApiKey';
    plugin 'APIKey' => {
        model  => 'Punk::Model::ApiKey',
        owner  => 'owner_id',
        kinds  => { live => 'sk_live_' },
        scopes => [qw(read write)],
    };
    my $api = under '/api' => api_key_guard(scope => 'read');
    $api->get('/x' => sub { $_[0]->text('in') });
}

{
    my $kapp = App::Keys->to_app;
    my $khit = sub {
        my ($key) = @_;
        my %env = (
            REQUEST_METHOD => 'GET', PATH_INFO => '/api/x', QUERY_STRING => '',
            SERVER_NAME => 'x', SERVER_PORT => 80, HTTP_HOST => 'x',
            'psgi.url_scheme' => 'http');
        $env{HTTP_AUTHORIZATION} = "Bearer $key" if defined $key;
        my $r = $kapp->(\%env);
        return $r->[0];
    };

    my ($key, $row) = Punk::Plugin::APIKey->issue_for(
        'App::Keys', owner => 7, label => 'CI', scopes => ['read']);

    is($khit->($key), 200, 'a key issued into a real table authenticates');
    is($khit->(), 401, 'and no key does not');

    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1, PrintError => 0 });
    my $stored = $dbh->selectall_arrayref(
        'SELECT prefix, digest, scopes, owner_id FROM api_keys',
        { Slice => {} });
    is(scalar @$stored, 1, 'one row');
    isnt($stored->[0]{digest}, $key,
        'and what is stored is the digest, never the key');
    is(length $stored->[0]{digest}, 64, 'sha256 hex');
    is($stored->[0]{prefix}, substr($key, 0, 16),
        'with a prefix that identifies it without being usable');
    $dbh->disconnect;

    Punk::Plugin::APIKey->revoke_for('App::Keys', $row->{id});
    is($khit->($key), 401, 'revoking it against a real table stops it');
}

# The revert script has to undo exactly what deploy did, or a rollback leaves
# a half-schema behind - which is the failure nobody discovers until they need
# the rollback.
{
    my $rev = File::Spec->catfile($dir, 'sqitch', 'sqlite', 'revert',
                                  'api_keys.sql');
    ok(-f $rev, 'the revert script ships too');
    my $body = do { open my $fh, '<', $rev or die $!; local $/; <$fh> };
    $body =~ s/^\s*(?:BEGIN|COMMIT)\s*;\s*$//gmi;
    my $dbh = DBI->connect($dsn, '', '', { RaiseError => 1, PrintError => 0 });
    $dbh->do($_) for grep { /\S/ } split /;\s*\n/, $body;
    my $left = $dbh->selectall_arrayref(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='api_keys'");
    is(scalar @$left, 0, 'and takes the table with it');
    $dbh->disconnect;
}

done_testing();
