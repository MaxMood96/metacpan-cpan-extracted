package Yote::Locker;

use 5.16.0;
use warnings;

use Carp 'longmess';
use Data::Dumper;
use Fcntl qw( :flock );
use File::Path qw(make_path);
use Scalar::Util qw(openhandle);

use vars qw($VERSION);

$VERSION = '0.01';

use constant {
    LOCK_FILE => 0,
    LOCK_FH   => 1,
    IS_LOCKED => 2,
};

sub new {
    my ($pkg, $lockfile) = @_;

    # create the lock file if it does not exist. if it cannot
    # be locked, error out here
    my $lock_fh;
    if (-e $lockfile) {
        $lock_fh = _open ($lockfile, '>' );
        unless (_flock( $lock_fh, LOCK_EX) ) {
            die "cannot open, unable to open lock file '$lockfile' to open store: $! $@";
        }
    } else {
        $lock_fh = _open ($lockfile, '>' );
        unless ($lock_fh = _open ($lockfile, '>' )) {
            die "cannot open, unable to open lock file '$lockfile' to open store: $! $@";
        }
        $lock_fh->autoflush(1);
        unless (_flock( $lock_fh, LOCK_EX) ) {
            die "cannot open, unable to open lock file '$lockfile' to open store: $! $@";
        }
        print $lock_fh "LOCK";
    }
    return bless [
        $lockfile,
        $lock_fh,
        1, #starts locked
    ], $pkg;
}

sub is_locked {
    return shift->[IS_LOCKED];
}

sub lock {
    my $self = shift;

    return 1 if $self->[IS_LOCKED];

    my $lock_fh = _openhandle( $self->[LOCK_FH]);
    unless ($lock_fh) {
        unless ($lock_fh = _open ( $self->[LOCK_FILE], '>' )) {
            die "unable to lock: lock file $self->[LOCK_FILE] : $@ $!";
        }
    }
    $lock_fh->blocking( 1 );
    $self->_log( "$$ try to lock" );
    unless (_flock( $lock_fh, LOCK_EX )) {
        die "unable to lock: cannot open lock file '$self->[LOCK_FILE]' to open store: $! $@";
    }
    $self->_log( "$$ locked" );
    $self->[LOCK_FH] = $lock_fh;
    $self->[IS_LOCKED] = 1;

    return 1;
}


sub unlock {
    my $self = shift;

    $self->[IS_LOCKED] = 0;
    $self->_log( "$$ try to unlock" );
    unless (_flock( $self->[LOCK_FH], LOCK_UN ) ) {
        _err( "unlock", "unable to unlock $@ $!" );
    }
    $self->[LOCK_FH] && $self->[LOCK_FH]->close;
    undef $self->[LOCK_FH];
    $self->_log( "$$ unlocked" );
    1;
}

sub _make_path {
    my( $dir, $err, $msg ) = @_;
    make_path( $dir, { error => $err } );
}

sub _openhandle {
    return openhandle( shift );
}

sub _log {
    # put stuff here to turn on logging
}

sub _err {
    my ($method,$txt) = @_;
    print STDERR Data::Dumper->Dump([longmess]);
    die __PACKAGE__."::$method $txt";
}


sub _open {
    my ($file, $mode) = @_;
    my $fh;
    my $res = CORE::open ($fh, $mode, $file);
    if ($res) {
        $fh->blocking( 1 );
        return $fh;
    }
}

sub _flock {
    my ($fh, $flags) = @_;
    return $fh && flock($fh,$flags);
}

sub DESTROY {
    my $self = shift;
    my $fh = $self->[LOCK_FH];
    if ($fh) {
        close $fh;
    }
}

1;
