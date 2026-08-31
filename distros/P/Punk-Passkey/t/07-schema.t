#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use PPKTest qw(fixture b64u_decode);

# The credential table, driven into a real SQLite database rather than
# read and believed.
#
# The claim under test is the one the ceremony depends on and cannot
# enforce itself: credential_id is unique across the WHOLE table, so a
# credential already registered to somebody else is refused by the
# database rather than by a check-then-insert that two requests can
# interleave through.

BEGIN {
    plan skip_all => 'DBD::SQLite is needed to drive the schema'
        unless eval { require DBI; require DBD::SQLite; 1 };
}

my $sql_dir = "$FindBin::Bin/../lib/Punk/Plugin/Passkey/sqitch";
plan skip_all => "no sqitch project at $sql_dir" unless -d $sql_dir;

sub slurp {
    open my $fh, '<', $_[0] or die "$_[0]: $!";
    local $/;
    return <$fh>;
}

# ---- the project itself ------------------------------------------------------

ok(-f "$sql_dir/sqitch.plan", 'the sqitch plan is shipped');
ok(-f "$sql_dir/sqitch.conf", 'and its configuration');
like(slurp("$sql_dir/sqitch.plan"), qr/^%project=punk_passkey$/m,
    'the project is named punk_passkey');
like(slurp("$sql_dir/sqitch.plan"), qr/\[punk_auth:users\]/,
    'and declares the users table as a dependency - a credential '
  . 'without an account to attach to is not a credential');

for my $engine (qw(sqlite pg mysql)) {
    for my $step (qw(deploy revert verify)) {
        ok(-f "$sql_dir/$engine/$step/passkeys.sql",
            "$engine has a $step script");
    }
    like(slurp("$sql_dir/sqitch.conf"), qr/\[engine "$engine"\]/,
        "...and sqitch.conf names $engine");
}

# every engine's deploy must carry the unique constraint - it is the
# race-free half of the ceremony, and an engine that quietly dropped it
# would look fine until two requests arrived together
for my $engine (qw(sqlite pg mysql)) {
    like(slurp("$sql_dir/$engine/deploy/passkeys.sql"),
        qr/credential_id\s+\S+.*UNIQUE/is,
        "$engine makes credential_id unique across the table");
}

# ---- deployed, and made to refuse --------------------------------------------

my $tmp = File::Temp->new(SUFFIX => '.db');
my $dbh = DBI->connect("dbi:SQLite:dbname=$tmp", '', '',
                       { RaiseError => 0, PrintError => 0, AutoCommit => 1 });
ok($dbh, 'a scratch database');

$dbh->do('PRAGMA foreign_keys = ON');
$dbh->do('CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT)')
    or die $dbh->errstr;
$dbh->do('INSERT INTO users (id, email) VALUES (1, ?)', undef, 'a@example.com');
$dbh->do('INSERT INTO users (id, email) VALUES (2, ?)', undef, 'b@example.com');

# the deploy script as shipped, statement by statement
{
    my $sql = slurp("$sql_dir/sqlite/deploy/passkeys.sql");
    $sql =~ s/^\s*--.*$//mg;
    my $ok = 1;
    for my $stmt (grep { /\S/ } split /;/, $sql) {
        next if $stmt =~ /\A\s*(BEGIN|COMMIT)\s*\z/i;
        $dbh->do($stmt) or do { $ok = 0; diag "$stmt: " . $dbh->errstr };
    }
    ok($ok, 'the shipped sqlite deploy script runs as written');
}

# the verify script is the contract: every column the ceremonies touch
{
    my $sql = slurp("$sql_dir/sqlite/verify/passkeys.sql");
    $sql =~ s/^\s*--.*$//mg;
    my $sth = $dbh->prepare($sql);
    ok($sth && $sth->execute,
        'and the shipped verify script runs against what it deployed - '
      . 'so a column renamed in one and not the other fails here rather '
      . 'than at the first login')
        or diag $dbh->errstr;
}

# a real credential from a real capture, stored
my $cred_id;
{
    my $f = fixture('reg-none.txt');
    require Punk::Passkey;
    my $att = Punk::Passkey::_decode_cbor(b64u_decode($f->{attestationObject}));
    my $ad  = PPKTest::auth_data($att->{authData});
    $cred_id = PPKTest::b64u_encode($ad->{credentialId});

    my $ok = $dbh->do(
        'INSERT INTO passkeys (user_id, credential_id, public_key,
                               sign_count, created_at)
         VALUES (?, ?, ?, ?, ?)',
        undef, 1, $cred_id, $ad->{cose}, 0, time);
    ok($ok, 'a real credential stores');

    my $row = $dbh->selectrow_hashref(
        'SELECT * FROM passkeys WHERE credential_id = ?', undef, $cred_id);
    ok($row, 'and reads back');
    is($row->{user_id}, 1, 'against its user');
    is($row->{sign_count}, 0, 'with a sign count to move forward from');
    is(length $row->{public_key}, length $ad->{cose},
        'and the COSE key survived the round trip byte for byte');
    is($row->{public_key}, $ad->{cose}, '...identically');
}

# ---- the constraint ----------------------------------------------------------

{
    my $ok = $dbh->do(
        'INSERT INTO passkeys (user_id, credential_id, public_key,
                               sign_count, created_at)
         VALUES (?, ?, ?, ?, ?)',
        undef, 1, $cred_id, 'x', 0, time);
    ok(!$ok, 'the same credential id cannot be registered twice');
    like($dbh->errstr // '', qr/unique/i, '...refused by the constraint');
}

{
    # and not merely per user: the same id claimed by a DIFFERENT
    # account is the case the spec actually cares about, because that
    # is somebody trying to attach your authenticator to their login
    my $ok = $dbh->do(
        'INSERT INTO passkeys (user_id, credential_id, public_key,
                               sign_count, created_at)
         VALUES (?, ?, ?, ?, ?)',
        undef, 2, $cred_id, 'x', 0, time);
    ok(!$ok,
        'nor claimed by a second account - the constraint is on the '
      . 'table, not on the pair, which is what makes it race-free');
    like($dbh->errstr // '', qr/unique/i, '...also by the constraint');
}

{
    # a second, different credential for the same user is fine: a
    # passkey user is expected to have several, and an account that
    # cannot register a second device is an account lost with the first
    my $ok = $dbh->do(
        'INSERT INTO passkeys (user_id, credential_id, public_key,
                               sign_count, created_at)
         VALUES (?, ?, ?, ?, ?)',
        undef, 1, 'a-second-credential', 'y', 0, time);
    ok($ok, 'a second credential for the same user is allowed');
    is($dbh->selectrow_array(
        'SELECT COUNT(*) FROM passkeys WHERE user_id = 1'), 2,
        'so one account can carry two');
}

{
    # deleting the account takes its credentials with it
    $dbh->do('DELETE FROM users WHERE id = 1') or diag $dbh->errstr;
    is($dbh->selectrow_array(
        'SELECT COUNT(*) FROM passkeys WHERE user_id = 1'), 0,
        'and deleting the account removes its credentials rather than '
      . 'leaving them pointing at nobody');
}

# ---- revert ------------------------------------------------------------------
{
    my $sql = slurp("$sql_dir/sqlite/revert/passkeys.sql");
    $sql =~ s/^\s*--.*$//mg;
    for my $stmt (grep { /\S/ } split /;/, $sql) {
        next if $stmt =~ /\A\s*(BEGIN|COMMIT)\s*\z/i;
        $dbh->do($stmt);
    }
    my $sth = $dbh->prepare('SELECT 1 FROM passkeys');
    ok(!$sth || !$sth->execute, 'the revert script removes the table');
}

done_testing;
