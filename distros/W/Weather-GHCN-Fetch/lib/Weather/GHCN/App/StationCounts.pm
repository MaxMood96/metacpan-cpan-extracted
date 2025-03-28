# ghcn_station_counts - Count stations in ghcn_fetch station output

## no critic (Documentation::RequirePodAtEnd)

=head1 NAME

Weather::GHCN::App::StationCounts - Count stations in Weather::GHCN::Fetch station output

=head1 VERSION

version v0.0.011

=head1 SYNOPSIS

    use Weather::GHCN::App::StationCounts;

    Weather::GHCN::App::StationCounts->run( \@ARGV );

See ghcn_station_counts -help for details.

=cut

########################################################################
# Pragmas
########################################################################

# these are needed because perlcritic fails to detect that Object::Pad handles these things
## no critic [ProhibitVersionStrings]
## no critic [RequireUseWarnings]

use v5.18;  # minimum for Object::Pad

package Weather::GHCN::App::StationCounts;

our $VERSION = 'v0.0.011';

use feature 'signatures';
no  warnings 'experimental::signatures';

########################################################################
# perlcritic rules
########################################################################

## no critic [ErrorHandling::RequireCarping]
## no critic [Modules::ProhibitAutomaticExportation]
## no critic [Subroutines::ProhibitSubroutinePrototypes]

# due to use of postfix dereferencing, we have to disable these warnings
## no critic [References::ProhibitDoubleSigils]


########################################################################
# Export
########################################################################

require Exporter;

use base 'Exporter';

our @EXPORT = ( 'run' );

########################################################################
# Libraries
########################################################################
use Getopt::Long    qw( GetOptionsFromArray );
use Pod::Usage;
use Const::Fast;
use Hash::Wrap      {-lvalue => 1, -defined => 1, -as => '_wrap_hash'};
use Const::Fast;
use English         qw( -no_match_vars );

use if $OSNAME eq 'MSWin32', 'Win32::Clipboard';

########################################################################
# Global delarations
########################################################################

# is it ok to use Win32::Clipboard?
our $USE_WINCLIP = $OSNAME eq 'MSWin32';

my $Opt;

########################################################################
# Constants
########################################################################

const my $EMPTY  => q();        # empty string
const my $SPACE  => q( );       # space character
const my $COMMA  => q(,);       # comma character
const my $DASH   => q(-);       # dash character
const my $TAB    => qq(\t);     # tab character
const my $TRUE   => 1;          # perl's usual TRUE
const my $FALSE  => not $TRUE;  # a dual-var consisting of '' and 0

const my $RANGE_RE     => qr{ \d{4} ( [-] \d{4} )? }xms;
const my $RANGELIST_RE => qr{ $RANGE_RE ( [,] $RANGE_RE )* }xms;
const my $FIXABLE_RE   => qr{ \A [\d,-]{4} \Z }xms;

########################################################################
# Script Mainline
########################################################################
__PACKAGE__->run( \@ARGV ) unless caller;

#-----------------------------------------------------------------------

=head1 SUBROUTINES

=head2 run ($progname, $argv_aref)

Encapsulates the mainline logic so this module can be used in a test
script.  An application script merely needs to use this module and
then call:

    Weather::GHCN::App::StationCounts->run( \@ARGV );

See ghcn_station_counts -help for details.

=cut

sub run ($progname, $argv_aref) {

    my %count;

    $Opt = get_options($argv_aref);

    ## no critic [RequireBriefOpen]
    my ( $output, $new_fh, $old_fh );
    if ( $Opt->outclip and $USE_WINCLIP ) {
        open $new_fh, '>', \$output
            or die 'Unable to open buffer for write';
        $old_fh = select $new_fh;  ## no critic (ProhibitOneArgSelect)
    }

    my @files = $argv_aref->@*;
    @files = ($DASH) unless @files;

    foreach my $file (@files) {
        my $fh;
        if ($file eq $DASH) {
            $fh = *STDIN;
        } else {
            open $fh, '<', $file or die;
        }

        read_data( $fh, \%count );
    }

    say join "\t", qw(Year Decade Stn_Count);

    foreach my $yr (sort { $a <=> $b } keys %count) {
        my $stn_count = keys %{ $count{$yr} };
        ## no critic [ProhibitMagicNumbers]
        my $decade = (substr $yr, 0, 3) . '0s';
        say sprintf "%3d\t%s\t%d", $yr, $decade, $stn_count;
    }

WRAP_UP:
    # send output to the Windows clipboard
    if ( $Opt->outclip and $USE_WINCLIP ) {
        Win32::Clipboard->new()->Set( $output );
        select $old_fh; ## no critic [ProhibitOneArgSelect]
    }


    return;
}

########################################################################
# Script-specific Subroutines
########################################################################

=head2 read_data( $fh, \%count )

From the file handle $fh, read a list of stations in the format
generated by Fetch.pm, and count the stations that were active in any
given year.

=cut

sub read_data ($fh, $count_href) {
    my $lineno = 0;

    while ( my $data = <$fh> ) {
        chomp $data;
        next if $data =~ m{ \A \s* \Z }xms;

        my ($stnid, $co, $state, $active) = split m{\t}xms, $data;

        $lineno++;
        if ($lineno == 1) {
            die '*E* invalid input data'
                unless  $stnid eq 'StationId' and $active eq 'Active';
            next;
        }

        last if not $active;

        my @rangelist = parse_active_range($stnid, $active);

        next unless @rangelist;

        foreach my $range (@rangelist) {
            my ($from, $to) = split m{-}xms, $range;

            $to //= $from;

            foreach my $yr ($from..$to) {
                $count_href->{$yr}{$stnid}++;
            }
        }
    }

    return;
}

=head2 parse_active_range ($stnid, $active)

Sometime the active range in data retreived from the NOAA station
inventory is malformed. This routine tries to spot these malformed
ranges and fix them.

=cut

sub parse_active_range ($stnid, $active) {

    if ( $active =~ m{ \A \d\d,\d\d\d,\d\d\d \Z }xms ) {
        # misplaced commas, but we can fix it
        my $s = $active;
        $s =~ s{ [,] }{}xmsg;
        if ( $s =~ m{ (\d\d\d\d) (\d\d\d\d) }xms ) {
            $active = $1 . $DASH . $2;
        }
    }

    if ( $active !~ m{ \A $RANGELIST_RE \Z }xms ) {
        warn "*W* unrecognized range list at stnid $stnid: $active\n";
        return;
    }

    my @rangelist = split $COMMA, $active;

    return @rangelist;
}


########################################################################
# Script-standard Subroutines
########################################################################

=head2 get_options ( \@argv )

get_options encapsulates everything we need to process command line
options, or to set options when invoking this script from a test script.

Normally it's called by passing a reference to @ARGV; from a test script
you'd set up a local array variable to specify the options.

By convention, you should set up a file-scoped lexical variable named
$Opt and set it in the mainline using the return value from this function.
Then all options can be accessed used $Opt->option notation.

=cut

sub get_options ($argv_aref) {

    my @options = (
        'outclip',              # output data to the Windows clipboard
        'debug',                # enable debug() statements on stderr
        'help','usage|?',       # help
    );

    my %opt;

    # create a list of option key names by stripping the various adornments
    my @keys = map { (split m{ [!+=:|] }xms)[0] } grep { !ref  } @options;
    # initialize all possible options to undef
    @opt{ @keys } = ( undef ) x @keys;

    GetOptionsFromArray($argv_aref, \%opt, @options)
        or pod2usage(2);

    # Make %opt into an object and name it the same as what we usually
    # call the global options object.  Note that this doesn't set the
    # global -- the script will have to do that using the return value
    # from this function.  But, what this does is allow us to call
    # $Opt->help and other option within this function using the same
    # syntax as what we use in the script.  This is handy if you need
    # to rename option '-foo' to '-bar' because you can do a find/replace
    # on '$Opt->foo' and you'll get any instances of it here as well as
    # in the script.

    ## no critic [Capitalization]
    ## no critic [ProhibitReusedNames]
    my $Opt = _wrap_hash \%opt;

    pod2usage(1)             if $Opt->usage;
    pod2usage(-verbose => 2) if $Opt->help;


    return $Opt;
}

1;  # needed in case we import this as a module (e.g. for testing)

=head1 AUTHOR

Gary Puckering (jgpuckering@rogers.com)

=head1 LICENSE AND COPYRIGHT

Copyright 2022, Gary Puckering

=cut

