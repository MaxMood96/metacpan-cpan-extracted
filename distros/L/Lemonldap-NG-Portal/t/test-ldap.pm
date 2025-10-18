# Try to launch an LDAP server

use URI::Escape qw/uri_escape/;
use Time::HiRes qw/usleep/;
use POSIX 'strftime';
use Test::More;
use Net::LDAP;
use IPC::Run;

use File::Copy "cp";

my $slapd_bin;
my $slapadd_bin;
my $slapd_schema_dir;
our $slapd_url = 'ldapi://' . uri_escape( $main::tmpDir . '/ldap_socket' );
our $slapd_pid;
our $slapd_harness;

sub legacy_openldap {
    my ($slapd_bin) = @_;

    my $output;
    IPC::Run::run( [ $slapd_bin, '-V' ], "2>", \$output );

    # Debian slapd 2.4 has an empty string as a version number
    my $is_legacy = $output =~ /slapd 2\.4/ or $output =~ /slapd  /;

    return $is_legacy;
}

if ( $ENV{LLNGTESTLDAP} ) {
    $slapd_bin        = $ENV{LLNGTESTLDAP_SLAPD_BIN}   || '/usr/sbin/slapd';
    $slapadd_bin      = $ENV{LLNGTESTLDAP_SLAPADD_BIN} || '/usr/sbin/slapadd';
    $slapd_schema_dir = (
        ( $ENV{LLNGTESTLDAP_SCHEMA_DIR} and -d $ENV{LLNGTESTLDAP_SCHEMA_DIR} )
        ? $ENV{LLNGTESTLDAP_SCHEMA_DIR}
        : -d '/etc/openldap/schema' ? '/etc/openldap/schema'
        :                             '/etc/ldap/schema'
    );

    eval { mkdir "$main::tmpDir/slapd.d" };
    eval { mkdir "$main::tmpDir/data" };
    cp( "t/testslapd/slapd.ldif", "$main::tmpDir/slapd-test.ldif" );
    cp( "t/testslapd/users.ldif", "$main::tmpDir/users.ldif" );
    system(
        "/bin/sed", "-i",
        "s:__SCHEMA_DIR__:$slapd_schema_dir:",
        "$main::tmpDir/slapd-test.ldif"
    );

    # Set expiresoon account to expire in 1 day
    my $twenty_nine_days_ago =
      strftime( "%Y%m%d%H%M%SZ", gmtime( time - 29 * 86400 ) );
    my $twenty_five_days_ago =
      strftime( "%Y%m%d%H%M%SZ", gmtime( time - 25 * 86400 ) );
    system(
        "/bin/sed",
        "-i",
        "-e",
        "s:TWENTYNINEDAYSAGO:$twenty_nine_days_ago:",
        "-e",
        "s:TWENTYFIVEDAYSAGO:$twenty_five_days_ago:",
        "$main::tmpDir/users.ldif"
    );

    # Remove ppolicy schema on newer OpenLDAP versions
    system(
        "/bin/sed",        "-i",
        "/ppolicy.ldif/d", "$main::tmpDir/slapd-test.ldif"
    ) unless legacy_openldap($slapd_bin);

    system(
        "/bin/sed",                       "-i",
        "s:t/testslapd/:$main::tmpDir/:", "$main::tmpDir/slapd-test.ldif"
    );
    system( $slapadd_bin, "-F", "$main::tmpDir/slapd.d", "-n", "0",
        "-l", "$main::tmpDir/slapd-test.ldif" );
    system( $slapadd_bin, "-F", "$main::tmpDir/slapd.d", "-n", "1",
        "-l", "$main::tmpDir/users.ldif" );
    startLdapServer();
}

sub resetLdapData {

    stopLdapServer();
    unlink glob "$main::tmpDir/data/*";
    system( $slapadd_bin, "-F", "$main::tmpDir/slapd.d", "-n", "1",
        "-l", "$main::tmpDir/users.ldif" );
    startLdapServer();
}

sub waitForLdap {
    my $waitloop = 0;
    note "Waiting for LDAP server to be available";
    while ( $waitloop < 100 and !Net::LDAP->new($slapd_url) ) {
        $waitloop++;
        usleep 100000;
    }
    die "Timed out waiting for LDAP server to start" if $waitloop == 100;
    open F, "$main::tmpDir/slapd.pid";
    $slapd_pid = join '', <F>;
    chomp $slapd_pid;
    close F;
    die "Could not find LDAP server PID" unless $slapd_pid;
    note "LDAP server ($slapd_pid) available at $slapd_url";
}

sub stopLdapServer {
    if ( $ENV{LLNGTESTLDAP} ) {
        note "Stopping LDAP server ($slapd_pid)";
        $slapd_harness->kill_kill( grace => 5 );
    }
}

sub startLdapServer {
    note "Starting LDAP server";

    my $loglevel = "0";
    if ( $ENV{DEBUG} or ( $ENV{LLNGLOGLEVEL} || '' ) eq "debug" ) {
        $loglevel = 'stats';
    }
    elsif ( $ENV{LLNGLOGLEVEL} ) {
        $loglevel = 'none';
    }

    if ( $ENV{LLNGTESTLDAP} ) {

        $slapd_harness = IPC::Run::start( [
                $slapd_bin, '-s', '256', '-d', $loglevel, '-h', $slapd_url,

                '-F', "$main::tmpDir/slapd.d"
            ]
        );
    }
    waitForLdap();
}

END {
    stopLdapServer();
}
1;
