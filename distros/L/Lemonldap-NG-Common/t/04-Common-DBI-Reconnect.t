use strict;
use warnings;
use Test::More;

# Test DBI reconnection after connection loss
# This verifies that the system recovers gracefully after a database
# connection is lost (e.g., after Patroni failover)

BEGIN {
    use_ok('Lemonldap::NG::Common::Conf');
    use_ok( 'Lemonldap::NG::Common::Lib::DBI', 'check_dbh' );
}

my $dbf = 't/cdbiReconnectTest.sql';
unlink $dbf;

SKIP: {
    eval { require DBI; };
    skip( "DBI not installed", 22 ) if ($@);
    eval { require DBD::SQLite };
    skip( "DBD::SQLite not installed", 22 ) if ($@);

    my $h;

    ok(
        $h = Lemonldap::NG::Common::Conf->new( {
                type        => 'CDBI',
                dbiChain    => "DBI:SQLite:dbname=$dbf",
                dbiUser     => '',
                dbiPassword => '',
            }
        ),
        'CDBI object created'
    );

    $h->_dbh->{sqlite_unicode} = 1;
    ok(
        $h->_dbh->do(
            'CREATE TABLE lmConfig (cfgNum int not null primary key, data text)'
        ),
        'Test database created'
    );

    my $cfg1 = { cfgNum => 1, test => 'initial_value' };
    ok( $h->store($cfg1) == 1, 'Config 1 stored successfully' );
    my $loaded;

    subtest 'Automatic reconnection', sub {
        my $oldDbh = $h->{_dbh} or fail 'No db handle';
        $oldDbh->disconnect;
        ok( !eval { $oldDbh->ping }, 'Ping fails on disconnected handle' );

        my $cfg2 = { cfgNum => 2, test => 'after_reconnect' };
        ok( $h->store($cfg2) == 2, 'Config 2 stored after reconnection' );

        $loaded = $h->load(2);
        ok( $loaded && $loaded->{test} eq 'after_reconnect',
            'Config 2 loaded after reconnection' );

        # Verify we got a new handle
        ok( $h->{_dbh} ne $oldDbh, 'New DBH created after reconnection' );
    };

    subtest 'Multiple consecutive disconnections', sub {
        for my $i ( 3 .. 5 ) {
            $h->{_dbh}->disconnect if $h->{_dbh};
            my $cfg = { cfgNum => $i, test => "iteration_$i" };
            ok( $h->store($cfg) == $i,
                "Config $i stored after reconnection #$i" );
        }

        # Verify all configs are accessible
        for my $i ( 1 .. 5 ) {
            $loaded = $h->load($i);
            ok( $loaded,
                "Config $i is accessible after multiple reconnections" );
        }
    };
}

# Cleanup
unlink $dbf;

done_testing();
