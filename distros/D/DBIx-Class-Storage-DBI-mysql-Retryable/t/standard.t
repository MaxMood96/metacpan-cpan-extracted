#!/usr/bin/perl

use lib qw(t/lib);
use strict;
use warnings;

use Test2::Bundle::More;
use Test2::Tools::Compare;
use Test2::Tools::Explain;

use DBIx::Class::Storage::DBI::mysql::Retryable;

use Env         qw< CDTEST_DSN >;
use Time::HiRes qw< time sleep >;

use CDTest;

############################################################

CDTest::Schema->storage_type('::DBI::mysql::Retryable');

### DEBUG
#DBIx::Class::Storage::DBI::mysql::Retryable->warn_on_retryable_error(1);

# The SQL and the lack of a real database doesn't really matter, since the sole purpose
# of this engine is to handle certain exceptions and react to them.  However,
# running this with a proper MySQL CDTEST_DSN would grant some additional $dbh checks.
#
# To specify a MySQL DB, you'll need a call like:
#
# CDTEST_DSN='dbi:mysql:database=...;host=...' CDTEST_DBUSER=... CDTEST_DBPASS=... prove -lrv t
#
# It will then use that database, instead of a default SQLite one.  Make sure the
# database doesn't have any useful data in it.  The database must exist prior to running
# the test.

our @TEST_ERRORS = (
    'Deadlock found when trying to get lock; try restarting transaction',
    'Lock wait timeout exceeded; try restarting transaction',
    'MySQL server has gone away',
    'Lost connection to MySQL server during query',
    'WSREP has not yet prepared node for application use',
    'Server shutdown in progress',
);

our $EXEC_COUNTER    = 0;
our $EXEC_SUCCESS_AT = 4;
our $EXEC_SLEEP_TIME = 0.5;
our $EXEC_UPDATE_SQL = 'SELECT 1';
our $EXEC_ACTUALLY_EXECUTE = 0;

our $COMMIT_COUNTER    = 0;
our $COMMIT_SUCCESS_AT = 4;
our $COMMIT_SLEEP_TIME = 0.5;
our $COMMIT_ACTUALLY_EXECUTE = 0;

our $UPDATE_FAILED = 0;
our $COMMIT_FAILED = 0;

our $IS_MYSQL = $CDTEST_DSN && $CDTEST_DSN =~ /^dbi:mysql:/;

no warnings 'redefine';
*DBIx::Class::Storage::DBI::_dbh_execute = sub {
    my ($self, $dbh, $sql, $bind, $bind_attrs) = @_;

    # The SQL is always $EXEC_UPDATE_SQL for the UPDATEs, but not for SET SESSION commands
    $sql = $EXEC_UPDATE_SQL if $sql =~ /UPDATE/i;

    my $sth = $self->_bind_sth_params(
        $self->_prepare_sth($dbh, $sql),
        [],
        {},
    );

    # Zero-based error, then one-based counter MOD check
    my $error = $TEST_ERRORS[ $EXEC_COUNTER % @TEST_ERRORS ];

    my $rv = '0E0';
    if ($EXEC_ACTUALLY_EXECUTE) {
        $rv = eval { $sth->execute };
        $error = $@ if $@;
    }

    sleep $EXEC_SLEEP_TIME if $EXEC_SLEEP_TIME;

    $EXEC_COUNTER++;
    if ($EXEC_COUNTER % $EXEC_SUCCESS_AT) {  # only success at exact divisors
        $UPDATE_FAILED = 1;
        $self->throw_exception(
            "DBI Exception: DBD::mysql::st execute failed: $error"
        );
    }

    $UPDATE_FAILED = 0;
    return (wantarray ? ($rv, $sth, @$bind) : $rv);
};

# The original is just a simple: shift->_dbh->commit;
*DBIx::Class::Storage::DBI::_exec_txn_commit = sub {
    my ($self) = @_;

    my $dbh = $self->_dbh;

    # Zero-based error, then one-based counter MOD check
    my $error = $TEST_ERRORS[ $COMMIT_COUNTER % @TEST_ERRORS ];

    my $rc = !!1;
    if ($COMMIT_ACTUALLY_EXECUTE) {
        $rc = eval { $dbh->commit };
        $error = $@ if $@;
    }

    sleep $COMMIT_SLEEP_TIME if $COMMIT_SLEEP_TIME;

    $COMMIT_COUNTER++;
    if ($COMMIT_COUNTER % $COMMIT_SUCCESS_AT) {  # only success at exact divisors
        $COMMIT_FAILED = 1;
        $self->throw_exception(
            "DBI Exception: DBD::mysql::db commit failed: $error"
        );
    }

    $COMMIT_FAILED = 0;
    return $rc;
};

my $orig_do = \&DBI::db::do;
*DBI::db::do = sub {
    my $sql = $_[1];

    # Ignore override for MySQL
    return $orig_do->(@_) if $IS_MYSQL;

    # If it's a sleep function, emulate it
    if ($sql =~ /SELECT SLEEP\((\d+)\)/) {
        sleep $1;
        return "0E0";
    }

    # Pretend it worked if it's a SET statement
    return "0E0" if $sql =~ /^SET /;

    # Otherwise, continue with the original 'do' method
    return $orig_do->(@_) ;
};
use warnings 'redefine';

my $orig__connect = \&DBIx::Class::Storage::DBI::_connect;
sub __connect_test {
    my ($self) = @_;
    return $orig__connect->($self) unless $UPDATE_FAILED;
    $UPDATE_FAILED = 0;

    # Zero-based error, then one-based counter MOD check
    my $error = $TEST_ERRORS[ $EXEC_COUNTER % @TEST_ERRORS ];

    sleep $EXEC_SLEEP_TIME if $EXEC_SLEEP_TIME;

    $EXEC_COUNTER++;
    $self->throw_exception(
        "DBI Connection failed: DBI connect(...) failed: $error"
    ) if $EXEC_COUNTER % $EXEC_SUCCESS_AT;  # only success at exact divisors

    return $orig__connect->($self);
}

my $schema = CDTest->init_schema(
    no_deploy   => 1,
    no_preclean => 1,
    no_populate => 1,
);
my $storage = $schema->storage;

# Force jitter off to remove randomness from tests
my $timer_opts = $storage->timer_options;
$timer_opts->{jitter_factor}         = 0;
$timer_opts->{timeout_jitter_factor} = 0;
$storage->_reset_retryable_timeout;

sub run_update_test {
    my %args = @_;

    # Defaults
    $args{duration} //= $EXEC_SLEEP_TIME;   # assume complete success
    $args{attempts} //= 1;
    $args{timeout}  //= 25;  # half of 50s timeout

    SKIP: {
        # SQLite does not recognize SET SESSION commands
        skip "CDTEST_DSN not set to a MySQL DB for a retryable_timeout test", 12
            if $storage->retryable_timeout && !$IS_MYSQL;

        # Changing storage variables may require some resetting
        $storage->connect_info( $storage->_connect_info );
        $storage->disconnect;

        my $update_track = sub { $schema->resultset('Track')->update({ track_id => 1 }) };
        my $start_time = time;

        # Test2::Tools::Exception checks eval _too_ properly for us to be able to use it here, especially
        # when we're trying to test for $@ pollution.  Instead, we want to blindly check $@, as assume
        # failures from that.  But, we'll check both sides for test failure clarity.
        local $@;
        my $ok = eval {
            $update_track->()          unless $args{use_transaction};
            $schema->txn_do($update_track) if $args{use_transaction};
            1;
        };
        my $err = $@;

        if ($args{exception}) {
            ok  (!$ok,                   'SQL dies');
            like($err, $args{exception}, 'expected exception');
        }
        else {
            ok($ok,      'SQL successful');
            is($err, '', 'no exception');
        }

        # Always add two seconds for lag and code runtimes
        my $duration = time - $start_time;
        note sprintf "Duration: %.2f seconds (range: %.2f - %.2f)", $duration, $args{duration}, $args{duration} + 2;
        cmp_ok $duration, '>=', $args{duration},     'expected duration (>=)';
        cmp_ok $duration, '<=', $args{duration} + 2, 'expected duration (<=)';

        is $EXEC_COUNTER,      $args{attempts}, 'expected attempts counter';

        SKIP: {
            skip "CDTEST_DSN not set to a MySQL DB",           8 unless $IS_MYSQL;
            skip "Retryable timeouts are not on in this test", 8 unless $storage->retryable_timeout;
            skip "Retryable is disabled",                      8 if     $storage->disable_retryable;

            my $dbh           = $storage->dbh;
            my $connect_attrs = $storage->_dbi_connect_info->[3];
            is $connect_attrs->{$_}, $args{timeout}, "$_ (attr) was reset" for map { "mysql_${_}_timeout" } qw< connect write >;

            my $timeout_vars = $dbh->selectall_hashref("SHOW VARIABLES LIKE '%_timeout'", 'Variable_name');
            is $timeout_vars->{$_}{Value}, $args{timeout}, "$_ (session var) was reset" for map { "${_}_timeout" } qw<
                lock_wait innodb_lock_wait net_read net_write
            >;

            skip "Aggressive timeouts are not on in this test", 2 unless $storage->aggressive_timeouts;
            skip "Can't use aggressive timeouts on this version of DBD::mysql", 2 if $DBD::mysql::VERSION < 4.023;

            is $connect_attrs->{$_}, $args{timeout}, "$_ (attr) was reset" for ('mysql_read_timeout');
            is $timeout_vars->{$_}{Value}, $args{timeout}, "$_ (session var) was reset" for ('wait_timeout');
        };
    };
}

############################################################

subtest 'clean_test' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 1;

    run_update_test;
};

subtest 'clean_test_with_retryable_timeout' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 1;

    # Purposely using legacy attribute shims for testing
    $storage->retryable_timeout(50);

    run_update_test;

    $storage->retryable_timeout(0);
};

subtest 'clean_test_with_disable_retryable' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 1;

    $storage->disable_retryable(1);

    run_update_test;

    $storage->disable_retryable(0);
};

subtest 'clean_test_with_db_transactions' => sub {
    local $EXEC_COUNTER      = 0;
    local $EXEC_SUCCESS_AT   = 1;
    local $COMMIT_COUNTER    = 0;
    local $COMMIT_SUCCESS_AT = 1;

    run_update_test(
        use_transaction => 1,
    );
};

subtest 'recoverable_failures' => sub {
    local $EXEC_COUNTER    = 0;

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME + (
            # hitting minimum exponential timer sleeps each time
            (1.41 - $EXEC_SLEEP_TIME) +
            (2.00 - $EXEC_SLEEP_TIME) +
            (2.83 - $EXEC_SLEEP_TIME)
        ),
        attempts => $EXEC_SUCCESS_AT,
    );
};

subtest 'recoverable_transaction_failures' => sub {
    local $EXEC_COUNTER      = 0;
    local $EXEC_SUCCESS_AT   = 1;
    local $COMMIT_COUNTER    = 0;

    run_update_test(
        use_transaction => 1,
        duration => (
            $EXEC_SUCCESS_AT   * $EXEC_SLEEP_TIME   +
            $COMMIT_SUCCESS_AT * $COMMIT_SLEEP_TIME + (
                # hitting minimum exponential timer sleeps each time
                (1.41 - $COMMIT_SLEEP_TIME) +
                (2.00 - $COMMIT_SLEEP_TIME) +
                (2.83 - $COMMIT_SLEEP_TIME)
            )
        ),
        attempts => $EXEC_SUCCESS_AT * $COMMIT_SUCCESS_AT,
    );
};

subtest 'recoverable_mixed_execute_transaction_failures' => sub {
    local $EXEC_COUNTER      = 0;
    local $EXEC_SUCCESS_AT   = 2;
    local $EXEC_SLEEP_TIME   = 0;
    # NOTE: COMMIT_COUNTER won't get hit until after execute is successful
    local $COMMIT_COUNTER    = $EXEC_COUNTER;
    local $COMMIT_SUCCESS_AT = $EXEC_SUCCESS_AT;
    local $COMMIT_SLEEP_TIME = $EXEC_SLEEP_TIME;

    run_update_test(
        use_transaction => 1,
        duration => $COMMIT_SUCCESS_AT * $COMMIT_SLEEP_TIME + (
            # hitting minimum exponential timer sleeps each time
            (1.41 - $COMMIT_SLEEP_TIME) +
            (2.00 - $COMMIT_SLEEP_TIME) +
            (2.83 - $COMMIT_SLEEP_TIME)
        ),
        attempts => $EXEC_SUCCESS_AT * $COMMIT_SUCCESS_AT,
    );
};

subtest 'recoverable_failures_with_longer_pauses' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SLEEP_TIME = 3;

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME,
        attempts => $EXEC_SUCCESS_AT,
    );
};

subtest 'connection_failure_after_update_failure' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 3;
    local $EXEC_SLEEP_TIME = 3;

    $UPDATE_FAILED = 0;
    no warnings 'redefine';
    local *DBIx::Class::Storage::DBI::_connect = \&__connect_test;
    use warnings 'redefine';

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME,
        attempts => $EXEC_SUCCESS_AT,
    );
};

subtest 'connection_failure_before_update_failure' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 2;
    local $EXEC_SLEEP_TIME = 3;

    $UPDATE_FAILED = 1;
    no warnings 'redefine';
    local *DBIx::Class::Storage::DBI::_connect = \&__connect_test;
    use warnings 'redefine';

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME,
        attempts => $EXEC_SUCCESS_AT,
    );
};

subtest 'non_retryable_failure' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SLEEP_TIME = 3;
    local @TEST_ERRORS     = (
        "Duplicate entry '1-1' for key 'PRIMARY'",
    );

    # Also test this setting
    $storage->retries_before_error_prefix(0);

    run_update_test(
        duration  => $EXEC_SLEEP_TIME,
        attempts  => 1,
        exception => qr<Failed dbh_do coderef: Exception not transient, attempts: 1 / 8, timer: [\d\.]+ / 0.0 sec, last exception:.+DBI Exception: DBD::mysql::st execute failed: Duplicate entry .+ for key>,
    );

    $storage->retries_before_error_prefix(1);
};

subtest 'non_retryable_transaction_failure' => sub {
    local $EXEC_COUNTER      = 0;
    local $EXEC_SUCCESS_AT   = 1;
    local $COMMIT_COUNTER    = 0;
    local $COMMIT_SLEEP_TIME = 3;
    local @TEST_ERRORS       = (
        "Duplicate entry '1-1' for key 'PRIMARY'",
    );

    $storage->retries_before_error_prefix(0);

    run_update_test(
        use_transaction => 1,
        duration  => $COMMIT_SLEEP_TIME,
        attempts  => 1,
        exception => qr<Failed txn_do coderef: Exception not transient, attempts: 1 / 8, timer: [\d\.]+ / 0.0 sec, last exception:.+DBI Exception: DBD::mysql::db commit failed: Duplicate entry .+ for key>,
    );

    $storage->retries_before_error_prefix(1);
};

subtest 'ran_out_of_attempts' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 8;
    local $EXEC_SLEEP_TIME = 2;

    # Purposely using legacy attribute shims for testing
    $storage->max_attempts(4);

    run_update_test(
        duration  => 4 * $EXEC_SLEEP_TIME + 0.8,  # ~0.82s sleep on the 4th attempt
        attempts  => 4,
        exception => qr<Failed dbh_do coderef: Out of retries, attempts: 5 / 4, timer: [\d\.]+ / 0.0 sec, last exception:.+DBI Exception: DBD::mysql::st execute failed: Lost connection to MySQL server during query>,
    );

    $storage->max_attempts(8);
};

subtest 'recoverable_failures_with_timeouts' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SLEEP_TIME = 2;

    $timer_opts->{max_actual_duration} = 20;

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME + 0.8,  # ~0.82s sleep on the 4th attempt
        attempts => $EXEC_SUCCESS_AT,
        timeout  => 10,  # half of 20s timeout
    );

    $timer_opts->{max_actual_duration} = 0;
};

subtest 'ran_out_of_time' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 8;
    local $EXEC_SLEEP_TIME = 5;

    $timer_opts->{max_actual_duration} = 22;

    run_update_test(
        duration  => 5 * $EXEC_SLEEP_TIME,
        attempts  => 5,
        timeout   => 11,  # half of 22s timeout
        exception => qr<Failed dbh_do coderef: Out of retries, attempts: 5 / 8, timer: [\d\.]+ / 22.0 sec, last exception:.+DBI Exception: DBD::mysql::st execute failed: WSREP has not yet prepared node for application use>,
    );

    $timer_opts->{max_actual_duration} = 0;
};

subtest 'failure_with_disable_retryable' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 8;
    local $EXEC_SLEEP_TIME = 5;

    $storage->disable_retryable(1);

    run_update_test(
        duration  => 5,
        attempts  => 1,
        exception => qr<DBI Exception: DBD::mysql::st execute failed: Deadlock found when trying to get lock; try restarting transaction>,
    );

    $storage->disable_retryable(0);
};

subtest 'aggressive_timeouts_off' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 1;
    local $EXEC_SLEEP_TIME = 0;
    local $EXEC_UPDATE_SQL = 'SELECT SLEEP(17)';
    local $EXEC_ACTUALLY_EXECUTE = 1;

    $timer_opts->{max_actual_duration} = 22;
    $storage->aggressive_timeouts(0);

    run_update_test(
        duration  => 17,
        attempts  => 1,
        timeout   => 11,  # half of 22s timeout
    );

    $timer_opts->{max_actual_duration} = 0;
    $storage->aggressive_timeouts(0);
};

subtest 'aggressive_timeouts_on' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 8;
    local $EXEC_SLEEP_TIME = 0;
    local $EXEC_UPDATE_SQL = 'SELECT SLEEP(17)';
    local $EXEC_ACTUALLY_EXECUTE = 1;

    $timer_opts->{max_actual_duration} = 22;
    $storage->aggressive_timeouts(1);

    run_update_test(
        duration  => 11 + 5 + 5 + 5,
        attempts  => 4,
        timeout   => 11,  # half of 22s timeout
        exception => qr<Failed dbh_do coderef: Out of retries, attempts: 4 / 8, timer: [\d\.]+ / 22.0 sec, last exception:.+DBI Exception: DBD::mysql::db do failed: MySQL server has gone away>,
    );

    $timer_opts->{max_actual_duration} = 0;
    $storage->aggressive_timeouts(0);
};

subtest 'outside_die_handler_doesnt_trigger_per_retry' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SLEEP_TIME = 2;

    $timer_opts->{max_actual_duration} = 20;

    my $num_of_errors = 0;
    local $SIG{__DIE__} = sub {
        $num_of_errors++;
        die "MyException triggered: $_[0]";
    };

    run_update_test(
        duration => $EXEC_SUCCESS_AT * $EXEC_SLEEP_TIME + 0.8,  # ~0.82s sleep on the 4th attempt
        attempts => $EXEC_SUCCESS_AT,
        timeout  => 10,  # half of 20s timeout
    );

    cmp_ok $num_of_errors, '==', 0, "Outside exception handler didn't catch the DBI error";

    $timer_opts->{max_actual_duration} = 0;
};

subtest 'outside_die_handler_triggers_at_final_exception' => sub {
    local $EXEC_COUNTER    = 0;
    local $EXEC_SUCCESS_AT = 8;
    local $EXEC_SLEEP_TIME = 5;

    $timer_opts->{max_actual_duration} = 22;

    my $num_of_errors = 0;
    local $SIG{__DIE__} = sub {
        $num_of_errors++;
        die "MyException triggered: $_[0]";
    };

    run_update_test(
        duration  => 5 * $EXEC_SLEEP_TIME,
        attempts  => 5,
        timeout   => 11,  # half of 22s timeout
        exception => qr<MyException triggered: Failed dbh_do coderef: Out of retries, attempts: 5 / 8, timer: [\d\.]+ / 22.0 sec, last exception:.+DBI Exception: DBD::mysql::st execute failed: WSREP has not yet prepared node for application use>,
    );

    cmp_ok $num_of_errors, '==', 1, "Outside exception handler catches only the final error" if $IS_MYSQL;

    $timer_opts->{max_actual_duration} = 0;
};

# Small test for this old method
subtest 'is_dbi_error_retryable' => sub {
    ok  $storage->is_dbi_error_retryable('DBI Exception: DBD::mysql::db do failed: MySQL server has gone away'), "Transient error";
    ok !$storage->is_dbi_error_retryable('DBI Exception: DBD::mysql::db do failed: Your foos are barred!'),      "Not a transient error";
};

############################################################

done_testing;
