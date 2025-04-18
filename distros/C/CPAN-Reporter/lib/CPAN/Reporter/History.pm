use strict;
package CPAN::Reporter::History;

our $VERSION = '1.2020';

use vars qw/@ISA @EXPORT_OK/;

use Config;
use Carp;
use Fcntl qw/:flock/;
use File::HomeDir ();
use File::Path (qw/mkpath/);
use File::Spec ();
use IO::File ();
use CPAN (); # for printing warnings
use CPAN::Reporter::Config ();

require Exporter;
@ISA = qw/Exporter/;
@EXPORT_OK = qw/have_tested/;

#--------------------------------------------------------------------------#
# Some platforms don't implement flock, so fake it if necessary
#--------------------------------------------------------------------------#

BEGIN {
    eval {
        my $temp_file = File::Spec->catfile(
            File::Spec->tmpdir(), $$ . time()
        );
        my $fh = IO::File->new( $temp_file, "w" );
        flock $fh, LOCK_EX;
        $fh->close;
        unlink $temp_file;
    };
    if ( $@ ) {
        *CORE::GLOBAL::flock = sub (*$) { 1 };
    }
}

#--------------------------------------------------------------------------#
# Back-compatibility checks -- just once per load
#--------------------------------------------------------------------------#


# 0.99_08 changed the history file format and name
# If an old file exists, convert it to the new name and format.  Note --
# someone running multiple installations of CPAN::Reporter might have old
# and new versions running so only convert in the case where the old file
# exists and the new file does not

{
    my $old_history_file = _get_old_history_file();
    my $new_history_file = _get_history_file();
    last if -f $new_history_file || ! -f $old_history_file;

    $CPAN::Frontend->mywarn("CPAN::Reporter: Your history file is in an old format. Upgrading automatically.\n");

    # open old and new files
    my ($old_fh, $new_fh);
    if (! ( $old_fh = IO::File->new( $old_history_file ) ) ) {
        $CPAN::Frontend->mywarn("CPAN::Reporter: error opening old history file: $!\nContinuing without conversion.\n");
        last;
    }
    if (! ($new_fh = IO::File->new( $new_history_file, "w" ) ) ) {
        $CPAN::Frontend->mywarn("CPAN::Reporter: error opening new history file: $!\nContinuing without conversion.\n");
        last;
    }

    print {$new_fh} _generated_by();
    while ( my $line = <$old_fh> ) {
        chomp $line;
        # strip off perl version and convert
        # try not to match 5.1 from "MSWin32-x86-multi-thread 5.1"
        # from really old CPAN::Reporter history formats
        my ($old_version, $perl_patch);
        if ( $line =~ m{ (5\.0\d{2,5}) ?(patch \d+)?\z} ) {
            ($old_version, $perl_patch) = ($1, $2);
            $line =~ s{ (5\.0\d{2,5}) ?(patch \d+)?\z}{};
        }
        my $pv = $old_version ? "perl-" . _perl_version($old_version)
                              : "unknown";
        $pv .= " $perl_patch" if $perl_patch;
        my ($grade_dist, $arch_os) = ($line =~ /(\S+ \S+) (.+)/);
        print {$new_fh} "test $grade_dist ($pv) $arch_os\n";
    }
    close $old_fh;
    close $new_fh;
}


#--------------------------------------------------------------------------#
# Public methods
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# have_tested -- search for dist in history file
#--------------------------------------------------------------------------#

sub have_tested { ## no critic RequireArgUnpacking
    # validate arguments
    croak "arguments to have_tested() must be key value pairs"
      if @_ % 2;

    my $args = { @_ };

    my @bad_params = grep {
        $_ !~ m{^(?:dist|phase|grade|perl|archname|osvers)$} } keys %$args;
    croak "bad parameters for have_tested(): " . join(q{, },@bad_params)
        if @bad_params;


    # DWIM: grades to upper case
    $args->{grade} = uc $args->{grade} if defined $args->{grade};

    # default to current platform
    $args->{perl} = _format_perl_version() unless defined $args->{perl};
    $args->{archname} = _format_archname() unless defined $args->{archname};
    $args->{osvers} = $Config{osvers} unless defined $args->{osvers};

    my @found;
    my $history = _open_history_file('<') or return;
    flock $history, LOCK_SH;
    <$history>; # throw away format line
    while ( defined (my $line = <$history>) ) {
        my $fields = _split_history( $line ) or next;
        push @found, $fields if _match($fields, $args);
    }
    $history->close;
    return @found;
}

#--------------------------------------------------------------------------#
# Private methods
#--------------------------------------------------------------------------#

#--------------------------------------------------------------------------#
# _format_history --
#
# phase grade dist-version (perl-version patchlevel) archname osvers
#--------------------------------------------------------------------------#

sub _format_history {
    my ($result) = @_;
    my $phase = $result->{phase};
    my $grade = uc $result->{grade};
    my $dist_name = $result->{dist_name};
    my $perlver = "perl-" . _format_perl_version();
    my $osvers = $Config{osvers};
    my $archname = _format_archname();
    return "$phase $grade $dist_name ($perlver) $archname $osvers\n";
}

#--------------------------------------------------------------------------#
# _format_archname --
#
# appends info about taint being disabled to Config.pm's archname
#--------------------------------------------------------------------------#

sub _format_archname {
    my $archname = $Config{archname};
    # `taint_disabled` is correctly set as of perl-blead@da791ecc, which will
    # be in 5.37.12 and later. Before then it is always false (indeed,
    # non-existent) and the only way to check whether taint is disabled is to
    # check the ccflags. Before that and its related commits (see
    # https://github.com/Perl/perl5/pull/20983) were merged it was impossible
    # to build a clean perl with taint support disabled that passed all its own
    # tests.
    if($Config{taint_disabled}) {
        $archname .= '-silent' if($Config{taint_disabled} eq 'silent');
        $archname .= '-no-taint-support';
    }
    return $archname;
}

#--------------------------------------------------------------------------#
# _format_perl_version
#--------------------------------------------------------------------------#

sub _format_perl_version {
    my $pv = _perl_version();
    $pv .= " patch $Config{perl_patchlevel}"
        if $Config{perl_patchlevel};
    return $pv;
}

sub _generated_by {
  return "# Generated by CPAN::Reporter "
    . "$CPAN::Reporter::History::VERSION\n";
}

#--------------------------------------------------------------------------#
# _get_history_file
#--------------------------------------------------------------------------#

sub _get_history_file {
    return File::Spec->catdir(
        CPAN::Reporter::Config::_get_config_dir(), "reports-sent.db"
    );
}

#--------------------------------------------------------------------------#
# _get_old_history_file -- prior to 0.99_08
#--------------------------------------------------------------------------#

sub _get_old_history_file {
    return File::Spec->catdir(
        CPAN::Reporter::Config::_get_config_dir(), "history.db"
    );
}

#--------------------------------------------------------------------------#
# _is_duplicate
#--------------------------------------------------------------------------#

sub _is_duplicate {
    my ($result) = @_;
    my $log_line = _format_history( $result );
    my $history = _open_history_file('<') or return;
    my $found = 0;
    flock $history, LOCK_SH;
    while ( defined (my $line = <$history>) ) {
        if ( $line eq $log_line ) {
            $found++;
            last;
        }
    }
    $history->close;
    return $found;
}

#--------------------------------------------------------------------------#
# _match
#--------------------------------------------------------------------------#

sub _match {
    my ($fields, $search) = @_;
    for my $k ( keys %$search ) {
        next if $search->{$k} eq q{}; # empty string matches anything
        return unless $fields->{$k} eq $search->{$k};
    }
    return 1; # all keys matched
}

#--------------------------------------------------------------------------#
# _open_history_file
#--------------------------------------------------------------------------#

sub _open_history_file {
    my $mode = shift || '<';
    my $history_filename = _get_history_file();
    my $file_exists = -f $history_filename;

    # shortcut if reading and doesn't exist
    return if ( $mode eq '<' && ! $file_exists );

    # open it in the desired mode
    my $history = IO::File->new( $history_filename, $mode )
        or $CPAN::Frontend->mywarn("CPAN::Reporter: couldn't open history file "
        . "'$history_filename': $!\n");

    # if writing and it didn't exist before, initialize with header
    if ( substr($mode,0,1) eq '>' && ! $file_exists ) {
        print {$history} _generated_by();
    }

    return $history;
}

#--------------------------------------------------------------------------#
# _perl_version
#--------------------------------------------------------------------------#

sub _perl_version {
    my $ver = shift || "$]";
    $ver =~ qr/(\d)\.(\d{3})(\d{0,3})/;
    my ($maj,$min,$pat) = (0 + ($1||0), 0 + ($2||0), 0 + ($3||0));
    my $pv;
    if ( $min < 6 ) {
        $pv = $ver;
    }
    else {
        $pv = "$maj\.$min\.$pat";
    }
    return $pv;
}

#--------------------------------------------------------------------------#
# _record_history
#--------------------------------------------------------------------------#

sub _record_history {
    my ($result) = @_;
    my $log_line = _format_history( $result );
    my $history = _open_history_file('>>') or return;

    flock( $history, LOCK_EX );
    seek( $history, 0, 2 ); # seek to end of file
    $history->print( $log_line );
    flock( $history, LOCK_UN );

    $history->close;
    return;
}

#--------------------------------------------------------------------------#
# _split_history
#
# splits lines created with _format_history. Returns hash ref with
#   phase, grade, dist, perl, platform
#--------------------------------------------------------------------------#

sub _split_history {
    my ($line) = @_;
    chomp $line;
    my %fields;
    @fields{qw/phase grade dist perl archname osvers/} =
        $line =~ m{
            ^(\S+) \s+              # phase
             (\S+) \s+              # grade
             (\S+) \s+              # dist
             \(perl- ([^)]+) \) \s+ # (perl-version-patchlevel)
             (\S+) \s+              # archname
             (.+)$                  # osvers
        }xms;

    # return nothing if parse fails
    return if scalar keys %fields == 0;# grep { ! defined($_) } values %fields;
    # otherwise return hashref
    return \%fields;
}

1;

# ABSTRACT: Read or write a CPAN::Reporter history log

__END__

=pod

=encoding UTF-8

=head1 NAME

CPAN::Reporter::History - Read or write a CPAN::Reporter history log

=head1 VERSION

version 1.2020

=head1 SYNOPSIS

     use CPAN::Reporter::History 'have_tested';
 
     @results = have_tested( dist => 'Dist-Name-1.23' );

=head1 DESCRIPTION

Interface for interacting with the CPAN::Reporter history file.  Most methods
are private for use only within CPAN::Reporter itself.  However, a public
function is provided to query the history file for results.

=head1 USAGE

The following function is available.  It is not exported by default.

=head2 C<<< have_tested() >>>

     # all reports for Foo-Bar-1.23
     @results = have_tested( dist => 'Foo-Bar-1.23' );
 
     # all NA reports
     @results = have_tested( grade => 'NA' );
 
     # all reports on the current Perl/platform
     @results = have_tested();

Searches the CPAN::Reporter history file for records exactly matching search
criteria, given as pairs of field-names and desired values.

Ordinary search criteria include:

=over

=item *

C<<< dist >>> -- the distribution tarball name without any filename suffix; from
a C<<< CPAN::Distribution >>> object, this is provided by the C<<< base_id >>> method.

=item *

C<<< phase >>> -- phase the report was generated during: either 'PL',
'make' or 'test'

=item *

C<<< grade >>> -- CPAN Testers grade: 'PASS', 'FAIL', 'NA' or 'UNKNOWN'; Also may
be 'DISCARD' for any failing reports not sent due to missing prerequisites

=back

Without additional criteria, a search will be limited to the current
version of Perl and the current architecture and OS version.
Additional criteria may be specified explicitly or, by specifying the empty
string, C<<< q{} >>>, will match that field for I<any> record.

     # all reports for Foo-Bar-1.23 on any version of perl
     # on the current architecture and OS version
     @results = have_tested( dist => 'Foo-Bar-1.23', perl => q{} );

These additional criteria include:

=over

=item *

C<<< perl >>> -- perl version and possible patchlevel; this will be
dotted decimal (5.6.2) starting with version 5.6, or will be numeric style as
given by C<<< $] >>> for older versions; if a patchlevel exists, it must be specified
similar to "5.11.0 patch 12345"

=item *

C<<< archname >>> -- platform architecture name as given by $Config{archname}

=item *

C<<< osvers >>> -- operating system version as given by $Config{osvers}

=back

The function returns an array of hashes representing each test result, with
all of the fields listed above.

=head1 SEE ALSO

=over

=item *

L<CPAN::Reporter>

=item *

L<CPAN::Reporter::FAQ>

=back

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2023 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut
