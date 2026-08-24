#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use Punk::Sqitch;

# target_for: a Punk `database` options hash to a Sqitch target URI.
#
# The judge of a URI is URI::db, because that is what Sqitch parses it
# with: every URI minted here must give back a DSN URI::db considers
# equivalent to the one it came from. Equivalent, not identical - URI::db
# spells a mysql target back as dbi:MariaDB:, and orders keys its own way -
# so the comparison is driver family plus the key/value set.

sub t { Punk::Sqitch->target_for(@_) }

sub dsn_parts {
    my ($dsn) = @_;
    my ($drv, $spec) = $dsn =~ /\Adbi:([^:]+):(.*)\z/s;
    my %kv = map { /\A([^=]+)=(.*)\z/s ? ($1 => $2) : () } split /;/, $spec;
    return (lc $drv, \%kv);
}

# ---- the three engines --------------------------------------------------------
{
    my $t = t({ dsn => 'dbi:SQLite:dbname=var/app.db' });
    is($t->{uri}, 'db:sqlite:var/app.db', 'SQLite: a relative file');
    is($t->{engine}, 'sqlite', 'engine sqlite');
    is(t({ dsn => 'dbi:SQLite:dbname=/var/lib/app/app.db' })->{uri},
        'db:sqlite:/var/lib/app/app.db', 'SQLite: an absolute file');
    is(t({ dsn => 'dbi:SQLite:app.db' })->{uri}, 'db:sqlite:app.db',
        'SQLite: the bare spelling is the file');
    is(t({ dsn => 'dbi:SQLite:dbname=:memory:' })->{uri}, 'db:sqlite::memory:',
        'SQLite: :memory: passes through (a Sqitch target nobody should use, but it is what was asked)');
}
{
    my $t = t({ dsn => 'dbi:Pg:dbname=shop' });
    is($t->{uri}, 'db:pg:shop', 'Pg: database only, no authority');
    is($t->{engine}, 'pg', 'engine pg');
    is(t({ dsn => 'dbi:Pg:host=dbhost;port=5433;dbname=shop', user => 'shop' })->{uri},
        'db:pg://shop@dbhost:5433/shop', 'Pg: user, host and port');
    is(t({ dsn => 'dbi:Pg:dbname=shop;host=dbhost' })->{uri},
        'db:pg://dbhost/shop', 'Pg: host without a user, any key order');
    is(t({ dsn => 'dbi:Pg:dbname=shop', user => 'shop' })->{uri},
        'db:pg://shop@/shop', 'Pg: a user and no host (the socket)');
    is(t({ dsn => 'dbi:Pg:dbname=shop;sslmode=require;application_name=punk' })->{uri},
        'db:pg:shop?sslmode=require&application_name=punk',
        'Pg: other keys become query parameters, in dsn order');
    is(t({ dsn => 'dbi:Pg(RaiseError=>1):dbname=shop' })->{uri}, 'db:pg:shop',
        'Pg: the dbi:Driver(attrs): spelling is read past');
    is(t({ dsn => 'dbi:Pg:shop' })->{uri}, 'db:pg:shop', 'Pg: bare database name');
    is(t({ dsn => 'dbi:Pg:dbname=shop', user => 'al@ice' })->{uri},
        'db:pg://al%40ice@/shop', 'Pg: a user is percent-encoded');
    is(t({ dsn => 'dbi:Pg:dbname=my shop' })->{uri}, 'db:pg:my%20shop',
        'Pg: so is the database name');
}
{
    is(t({ dsn => 'dbi:mysql:database=shop;host=h;port=3307', user => 'bob' })->{uri},
        'db:mysql://bob@h:3307/shop', 'mysql: user, host, port');
    is(t({ dsn => 'dbi:mysql:shop' })->{uri}, 'db:mysql:shop', 'mysql: bare database');
    my $t = t({ dsn => 'dbi:MariaDB:database=shop' });
    is($t->{uri}, 'db:mysql:shop', 'MariaDB: Sqitch\'s engine for it is mysql');
    is($t->{engine}, 'mysql', 'engine mysql');
}

# ---- more engines, the override, the explicit target, the registry --------------
{
    is(t({ dsn => 'dbi:Oracle:host=h;port=1521;sid=ORCL', user => 'u' })->{uri},
        'db:oracle://u@h:1521/ORCL', 'Oracle: the sid is the database');
    is(t({ dsn => 'dbi:Oracle:service_name=svc;host=h' })->{uri}, 'db:oracle://h/svc',
        'Oracle: service_name is an alias for it');
    is(t({ dsn => 'dbi:Firebird:dbname=/data/app.fdb;host=h' })->{uri}, 'db:firebird://h/%2Fdata%2Fapp.fdb',
        'Firebird: a file on a host');
    is(t({ dsn => 'dbi:ClickHouse:host=h;database=shop' })->{engine}, 'clickhouse', 'ClickHouse');
    my $t = t({ dsn => 'dbi:Pg:dbname=shop;host=h', sqitch_engine => 'cockroach' });
    is($t->{uri}, 'db:cockroach://h/shop', 'sqitch_engine: CockroachDB on the Pg driver, the mapping kept');
    is($t->{engine}, 'cockroach', 'and the engine says so');
    $t = t({ dsn => 'dbi:ODBC:DSN=vert', sqitch_target => 'db:vertica://u@h/shop', password => 'p' });
    is($t->{uri}, 'db:vertica://u@h/shop', 'sqitch_target: the application\'s own URI wins, whatever the dsn');
    is($t->{engine}, 'vertica', 'the engine read from it');
    is($t->{password}, 'p', 'the password still beside it');
    my $e = ''; eval { t({ dsn => 'dbi:ODBC:x', sqitch_target => 'postgres://h/x' }) } or $e = $@;
    like($e, qr/sqitch_target 'postgres:\/\/h\/x' is not a db: URI/, 'a sqitch_target that is not a db: URI croaks');
    Punk::Sqitch->engine_for(Vertica => { engine => 'vertica', name => 'database' });
    is(t({ dsn => 'dbi:Vertica:database=shop;host=h' })->{uri}, 'db:vertica://h/shop',
        'engine_for: a driver registered at runtime maps like the built-ins');
    ok((grep { $_ eq 'vertica' } @{ Punk::Sqitch->engines }), 'and engines lists it');
    $e = ''; eval { Punk::Sqitch->engine_for(X => { engine => 'x' }) } or $e = $@;
    like($e, qr/`engine` and `name` are required/, 'engine_for needs both');
    $e = ''; eval { Punk::Sqitch->engine_for(X => { engine => 'x', name => 'd', colour => 1 }) } or $e = $@;
    like($e, qr/unknown key 'colour'/, 'and refuses an unknown key');
}

# ---- the password is not in the URI ---------------------------------------------
{
    my $t = t({ dsn => 'dbi:Pg:host=h;dbname=shop', user => 'shop', password => 's3cret' });
    is($t->{uri}, 'db:pg://shop@h/shop', 'the URI carries the user and not the password');
    is($t->{password}, 's3cret', 'the password rides beside it, for $SQITCH_PASSWORD');
    is(t({ dsn => 'dbi:Pg:dbname=shop', password => '' })->{password}, undef,
        'an empty password is no password');
}

# ---- the round trip, judged by URI::db ---------------------------------------------
SKIP: {
    skip 'URI::db required for the round-trip tests', 6
        unless eval { require URI::db; 1 };
    my @cases = (
        [ 'dbi:SQLite:dbname=var/app.db' ],
        [ 'dbi:Pg:host=dbhost;port=5433;dbname=shop', 'shop' ],
        [ 'dbi:Pg:dbname=shop;sslmode=require;application_name=punk' ],
        [ 'dbi:Pg:dbname=shop', 'al@ice' ],
        [ 'dbi:mysql:database=shop;host=h;port=3307', 'bob' ],
        [ 'dbi:MariaDB:database=shop' ],
    );
    for my $c (@cases) {
        my ($dsn, $user) = @$c;
        my $t = t({ dsn => $dsn, ($user ? (user => $user) : ()) });
        my $u = URI::db->new($t->{uri});
        my ($want_drv, $want) = dsn_parts($dsn);
        my ($got_drv,  $got)  = dsn_parts($u->dbi_dsn);
        # mysql and MariaDB are one family to URI::db, and it prefers the latter
        my %fam = (mysql => 'mysql', mariadb => 'mysql');
        $_ = $fam{$_} // $_ for $want_drv, $got_drv;
        # the bare-name spellings normalise to the key
        my $ok = $want_drv eq $got_drv
              && join(';', map { "$_=$want->{$_}" } sort keys %$want)
              eq join(';', map { "$_=$got->{$_}" }  sort keys %$got)
              && (($user // '') eq ($u->user // ''));
        ok($ok, "round trip: $dsn -> $t->{uri} -> " . $u->dbi_dsn)
            or diag explain { want => $want, got => $got, user => scalar $u->user };
    }
}

# ---- croaks ----------------------------------------------------------------------
{
    my $e = ''; eval { t({}) } or $e = $@;
    like($e, qr/no dsn - add a database keyword/, 'no dsn croaks with the keyword\'s hint');
    $e = ''; eval { t({ dsn => 'postgres://x' }) } or $e = $@;
    like($e, qr/is not a DBI dsn/, 'a non-DBI dsn croaks');
    $e = ''; eval { t({ dsn => 'dbi:Informix:shop' }) } or $e = $@;
    like($e, qr/no target mapping for the 'Informix' driver\. Either set sqitch_target => "db:ENGINE:\.\.\." on the database .* or register the driver with Punk::Sqitch->engine_for\('Informix'/,
        'an unmapped driver croaks naming it and both ways out');
    $e = ''; eval { t({ dsn => 'dbi:Pg:host=h' }) } or $e = $@;
    like($e, qr/names no database \(dbname=/, 'a dsn with no database name croaks');
    $e = ''; eval { t({ dsn => 'dbi:SQLite:dbname=a.db;mode=ro' }) } or $e = $@;
    like($e, qr/'mode' in the SQLite dsn has no place/, 'an extra SQLite key croaks');
    $e = ''; eval { t('dbi:Pg:dbname=x') } or $e = $@;
    like($e, qr/takes the database options hashref/, 'a bare string croaks');
}

# ---- which verbs take a target -------------------------------------------------------
ok(Punk::Sqitch->takes_target($_), "$_ takes a target") for qw(deploy revert verify status log check);
ok(!Punk::Sqitch->takes_target($_), "$_ is plan-only") for qw(add tag rework plan show init);

done_testing();
