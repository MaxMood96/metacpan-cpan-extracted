#! perl

use Test2::V0;
use Env qw( @PATH );


use File::Which 'which';
use Action::Retry 'retry';
use Child 'child';

BEGIN {
    $ENV{XPA_METHOD} = $^O eq 'MSWin32' ? 'localhost' : 'local';
}

use IPC::XPA;
use Alien::XPA;

sub xpamb_is_running;
sub shutdown_xpamb;

push @PATH, Alien::XPA->bin_dir;

bail_out( "can't find $_ executable" )
  foreach grep { !defined which( $_ ) } qw( xpamb xpaset xpaaccess );

shutdown_xpamb if xpamb_is_running;

my $child;
my $nserver = 0;

if ( $^O eq 'MSWin32' ) {
    require Win32::Process;
    use subs qw( Win32::Process::NORMAL_PRIORITY_CLASS Win32::Process::CREATE_NO_WINDOW);
    Win32::Process::Create( $child, which( 'xpamb' ),
        'xpamb', 0, Win32::Process::NORMAL_PRIORITY_CLASS | Win32::Process::CREATE_NO_WINDOW, q{.} )
      || die $^E;
}
else {
    $child = child { exec {'xpamb'} 'xpamb' };
}

my $TSTART = time;
diag( 'waiting to contact launched xpamb' );
bail_out( sprintf( 'unable to access launched xpamb after %f seconds', time - $TSTART ) )
  unless
  retry {    ## no critic (ControlStructures::ProhibitNegativeExpressionsInUnlessAndUntilConditions)
    die unless xpamb_is_running;
}            # try every 0.25 seconds for 15 seconds. Try to be nice to CPAN testers.
strategy => { Constant => { sleep_time => 250, max_retries_number => 15_000 / 250 } };
diag( sprintf( 'accessed launched xpamb after %f seconds', time - $TSTART ) );

is( ( $nserver = keys %{ { access( 'XPAMB:*', 'gs' ) } } ), 1, 'expected number of xpamb servers' );

# try a lookup
subtest lookup => sub {

    my @res;
    ok( lives { @res = IPC::XPA->NSLookup( 'xpamb', 'ls' ) }, 'nslookup' )
      or do { diag $@; return; };

    is( scalar @res, 1, 'correct number of servers' );
};

# create a handle

my $xpa = IPC::XPA->Open( { verify => 'true' } );
ok( defined $xpa, 'Open' );

# send xpamb some data
my $name = 'IPC::XPA';
my $data = "IPC::XPA Test Data\n";

subtest 'Set -data' => sub {
    my %res;
    ok( lives { %res = $xpa->Set( 'xpamb', "-data $name", $data ) }, 'Set data' )
      or diag $@;

    my $error = _xpa_error( %res );
    is( $error, undef, 'no errors' )
      or diag $error;

    is( keys %res, $nserver, "Set to $nserver servers" );
};

subtest 'Get -data' => sub {
    my %res;
    ok( lives { %res = $xpa->Get( 'xpamb', "-data $name" ) }, 'Get data' )
      or diag $@;

    my $error = _xpa_error( %res );
    is( $error, undef, 'no errors' )
      or diag $error;

    is( keys %res, $nserver, "Get from $nserver servers" );

    my $rdata = ( values %res )[0]->{buf};
    is( $rdata, $data, 'retrieved data' );
};

subtest 'Set -del' => sub {
    my %res;
    ok( lives { %res = $xpa->Set( 'xpamb', "-del $name" ) }, 'Set -del' )
      or diag $@;
    my $error = _xpa_error( %res );
    is( $error, undef, 'no errors' )
      or diag $error;

    is( keys %res, $nserver, "Set to $nserver servers" );

    ok( lives { %res = $xpa->Get( 'xpamb', "-data $name" ) }, 'Get data' )
      or diag $@;
    like( _xpa_error( %res ), qr/unknown xpamb entry: $name/, 'deleted' );
};

# see if an xpamb instance is already running check both via our
# XS interface as well as via the command line.
sub xpamb_is_running {
    my ( $xs_is_running, $cli_is_running );

    retry {
        my %res = access( 'XPAMB:*', 'gs' );
        $xs_is_running = !!keys %res;
        my $run = run( 'xpaaccess', 'XPAMB:*' );
        $cli_is_running = $run->out =~ 'yes';
        die if $xs_is_running != $cli_is_running;
    };

    bail_out( 'xpamb_is_running: XS and CLI return different results' )
      unless $xs_is_running == $cli_is_running;
    return $xs_is_running;
}

sub shutdown_xpamb {
    my $xpamb_is_running;

    # first try using XS
    retry {
        $xpamb_is_running = xpamb_is_running();
        return unless $xpamb_is_running;

        my $xpa = IPC::XPA->Open( { verify => 'true' } );
        return if !defined $xpa;

        $xpa->Set( 'xpamb', '-exit' );
        die;
    };

    return unless $xpamb_is_running;
    diag 'unable to use XS to shutdown xpamb';

    # now try using the xpaset executable
    retry {
        $xpamb_is_running = xpamb_is_running();
        return unless $xpamb_is_running;
        run( 'xpaset', qw [ -p xpamb -exit ] );
        die;
    };

    return unless $xpamb_is_running;

    diag 'unable to use xpaset to shutdown xpamb';

    # be firm if necessary
    if ( defined $child ) {

        diag( 'force remove our xpamb' );

        retry {

            if ( $^O eq 'MSWin32' ) {
                use subs qw( Win32::Process::STILL_ACTIVE );
                $child->GetExitCode( my $exitcode );
                $child->Kill( 0 ) if $exitcode == Win32::Process::STILL_ACTIVE;
            }

            else {
                $child->kill( 9 ) unless $child->is_complete;
            }

            if ( run( 'xpaaccess', 'XPAMB:*' )->out !~ 'yes' ) {
                $xpamb_is_running = 0;
                return;
            }
            die;
        };
    }

    bail_out( 'unable to remove xpamb' )
      if $xpamb_is_running;
}

{
    package MyRun;
    use Capture::Tiny qw( capture );

    sub new {
        my ( $class, @args ) = @_;
        my ( $out, $err, $exit ) = capture { system { $args[0] } @args; $?; };

        my $signal = $exit & 127;
        my $core   = $exit & 128;
        $exit = $exit >> 8;

        return bless {
            cmd    => \@args,
            out    => $out,
            err    => $err,
            exit   => $exit,
            signal => $signal,
            $core  => $core,
        }, $class;
    }

    sub out    { $_[0]->{out} }
    sub err    { $_[0]->{err} }
    sub exit   { $_[0]->{exit} }                  ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    sub core   { $_[0]->{core} }
    sub signal { $_[0]->{signal} }
    sub cmd    { join q{ }, @{ $_[0]->{cmd} } }

    sub stringify {
        sprintf "cmd: %s\nexit: %d\ncore; %s\nsignal: %s\nstdout: %s\nstderr: %s\n",
          $_[0]->cmd,
          $_[0]->exit,
          $_[0]->core,
          $_[0]->signal,
          $_[0]->out,
          $_[0]->err;
    }
}

END {
    shutdown_xpamb;
}

done_testing;

sub run { MyRun->new( @_ ) }

sub access {
    my %res   = IPC::XPA->Access( @_ );
    my $error = _xpa_error( %res );
    bail_out( "error in XPAACCESS: $error" )
      if defined $error;
    return %res;
}

sub _xpa_error {
    my ( %res ) = @_;
    my @msgs    = map $_->{message}, grep defined $_->{message}, values %res;
    return join( q{ }, @msgs ) if @msgs;
    return;
}
