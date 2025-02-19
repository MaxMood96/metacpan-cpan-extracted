=head1 NAME

PDL::Graphics::Simple - Simple backend-independent plotting for PDL

=head1 SYNOPSIS

 # Simple interface - throw plots up on-screen, ASAP
 use PDL::Graphics::Simple;
 imag $a;                     # Display an image PDL
 imag $a, 0, 300;             # Display with color range
 line $rrr, $fit;             # Plot a line

 points $rr, $sec;            # Plot points
 hold;                        # Hold graphics so subsequent calls overplot
 line $rrr, $fit;             # Overplot a line in a contrasting color
 release;                     # Release graphics

 # Object interface - simple plotting, to file or screen
 $w = pgswin( size=>[8,4], multi=>[2,2] ); # 2x2 plot grid on an 8"x4" window
 $w = pgswin( size=>[1000,1000,'px'], output=>'plot.png' ); # output to a PNG

 $w->plot( with=>'points', $rr, $sec, with=>'line', $rrr, $fit,
           {title=>"Points and fit", xlabel=>"Abscissa", ylabel=>"Ordinate"});

=head1 DESCRIPTION

PDL can plot through a plethora of external plotting modules.  Each
module tends to be less widely available than Perl itself, and to
require an additional step or two to install.  For simple applications
("throw up an image on the screen", or "plot a curve") it is useful to
have a subset of all plotting capability available in a backend-independent
layer.  PDL::Graphics::Simple provides that capability.

PDL::Graphics::Simple implements all the functionality used in the
PDL::Book examples, with identical syntax.  It also generalizes that
syntax - you can use ::Simple graphics, with slight syntactical
differences, in the same manner that you would use any of the engine
modules.  See the Examples below for details.

The plot you get will always be what you asked for, regardless of
which plotting engine you have installed on your system.

Only a small subset of PDL's complete graphics functionality is
supported -- each individual plotting module has unique advantages and
functionality that are beyond what PDL::Graphics::Simple can do.  Only
2-D plotting is supported.  For 3-D plotting, use
L<PDL::Graphics::Gnuplot> or L<PDL::Graphics::TriD> directly.

When plotting to a file, the file output is not guaranteed to be
present until the plot object is destroyed (e.g. by being undefed or
going out of scope).

=head1 STATE OF DEVELOPMENT

PDL::Graphics::Simple currently supports most of the
planned functionality.  It is being released as a beta
test to determine if it meets users' needs and gain feedback on
the API -- so please give feedback!

=head1 SUPPORTED GRAPHICS ENGINES

PDL::Graphics::Simple includes support for the following graphics
engines.  Additional driver modules can be loaded dynamically; see
C<register>, below.  Each of the engines has unique capabilities and
flavor that are not captured in PDL::Graphics::Simple - you are
encouraged to look at the individual modules for more capability!

=over 3

=item * Gnuplot (via PDL::Graphics::Gnuplot)

Gnuplot is an extremely richly featured plotting package that offers
markup, rich text control, RGB color, and 2-D and 3-D plotting.  Its
output is publication quality.  It is supported on POSIX systems,
MacOS, and Microsoft Windows, and is available from most package
managers.

=item * PGPLOT  (via PDL::Graphics::PGPLOT::Window)

PGPLOT is venerable and nearly as fully featured as Gnuplot for 2-D
plotting.  It lacks RGB color output. It does have rich text control,
but uses simple plotter fonts that are generated internally.  It
is supported on MacOS and POSIX, but is not as widely available as
Gnuplot.

=item * PLplot (via PDL::Graphics::PLplot)

PLplot is a moderately full featured plotting package that
generates publication quality output with a simple high-level interface.
It is supported on MacOS and POSIX.

=item * Prima (via PDL::Graphics::Prima)

Prima is based around a widget paradigm that enables complex
interaction with data in real-time, and it is highly optimized for
that application.  It is not as mature as the other platforms,
particularly for static plot generation to files.  This means that
PDL::Graphics::Simple does not play to its considerable strengths,
although Prima is serviceable and fast in this application.  Please
run the Prima demo in the perldl shell for a better sample of Prima's
capabilities.

=back

=head1 EXAMPLES

PDL::Graphics::Simple can be called using plot-atomic or curve-atomic
plotting styles, using a pidgin form of calls to any of the main
modules.  The examples are divided into Book-like (very simple),
PGPLOT-like (curve-atomic), and Gnuplot-like (plot-atomic) cases.

There are three main styles of interaction with plot objects that
PDL::Graphics::Simple supports, reflective of the pre-existing
modules' styles of interaction.  You can mix-and-match them to match
your particular needs and coding style.  Here are examples showing
convenient ways to call the code.

=head2 First steps (non-object-oriented)

For the very simplest actions there are non-object-oriented shortcuts.
Here are some examples of simple tasks, including axis labels and plot
titles.  These non-object-oriented shortcuts are useful for display
with the default window size.  They make use of a package-global plot
object.

The non-object interface will keep using the last plot engine you used
successfully.  On first start, you can specify an engine with the
environment variable C<PDL_SIMPLE_ENGINE>. As of 1.011, only that will be tried, but
if you didn't specify one, all known engines are tried in alphabetical
order until one works.

The value of C<PDL_SIMPLE_ENGINE> should be the "shortname" of the
engine, currently:

=over

=item C<gnuplot>

=item C<plplot>

=item C<pgplot>

=item C<prima>

=back

=over 3

=item * Load module and create line plots

 use PDL::Graphics::Simple;
 $x = xvals(51)/5;
 $y = $x**3;

 $y->line;
 line( $x, $y );
 line( $x, $y, {title=>"My plot", ylabel=> "Ordinate", xlabel=>"Abscissa"} );

=item * Bin plots

 $y->bins;
 bins($y, {title=>"Bin plot", xl=>"Bin number", yl=>"Count"} );

=item * Point plots

 $y->points;
 points($y, {title=>"Points plot"});

=item * Logarithmic scaling

 line( $y, { log=>'y' } );    # semilog
 line( $y, { log=>'xy' } );   # log-log

=item * Image display

 $im = 10 * sin(rvals(101,101)) / (10 + rvals(101,101));
 imag $im;          # Display image
 imag $im, 0, 1;    # Set lower/upper color range

=item * Overlays

 points($x, $y, {logx=>1});
 hold;
 line($x, sqrt($y)*10);
 release;


=item * Justify aspect ratio

 imag $im, {justify=>1}
 points($x, $y, {justify=>1});

=item * Erase/delete the plot window

 erase();

=back

=head2 Simple object-oriented plotting

More functionality is accessible through direct use of the PDL::Graphics::Simple
object.  You can set plot size, direct plots to files, and set up multi-panel plots.

The constructor accepts window configuration options that set the plotting
environment, including size, driving plot engine, output, and multiple
panels in a single window.

For interactive/display plots, the plot is rendered immediately, and lasts until
the object is destroyed.  For file plots, the file is not guaranteed to exist
and be correct until the object is destroyed.

The basic plotting method is C<plot>.  C<plot> accepts a collection of
arguments that describe one or more "curves" (or datasets) to plot,
followed by an optional plot option hash that affects the entire plot.
Overplotting is implemented via plot option, via a held/released state
(as in PGPLOT), and via a convenience method C<oplot> that causes the
current plot to be overplotted on the previous one.

Plot style (line/points/bins/etc.) is selected via the C<with> curve option.
Several convenience methods exist to create plots in the various styles.

=over 3

=item * Load module and create basic objects

 use PDL::Graphics::Simple;
 $x = xvals(51)/5;
 $y = $x**3;

 $win = pgswin();                       # plot to a default-shape window
 $win = pgswin( size=>[4,3] );          # size is given in inches by default
 $win = pgswin( size=>[10,5,'cm'] );    # You can feed in other units too
 $win = pgswin( out=>'plot.ps' );       # Plot to a file (type is via suffix)
 $win = pgswin( engine=>'gnuplot' );    # Pick a particular plotting engine
 $win = pgswin( multi=>[2,2] );         # Set up for a 2x2 4-panel plot

=item * Simple plots with C<plot>

 $win->plot( with=>'line', $x, $y, {title=>"Simple line plot"} );
 $win->plot( with=>'errorbars', $x, $y, sqrt($y), {title=>"Error bars"} );
 $win->plot( with=>'circles', $x, $y, sin($x)**2 );

=item * Plot overlays

 # All at once
 $win->plot( with=>'line', $x, $y,   with=>'circles', $x, $y/2, sqrt($y)  );

 # Using oplot (IDL-style; PLplot-style)
 $win->plot(  with=>'line', $x, $y );
 $win->oplot( with=>'circles', $x, $y/2, sqrt($y) );

 # Using object state (PGPLOT-style)
 $win->line(  $x, $y );
 $win->hold;
 $win->circles( $x, $y/2, sqrt($y) );
 $win->release;

=back


=head1 FUNCTIONS

=cut

package PDL::Graphics::Simple;

use strict;
use warnings;
use PDL;
use PDL::Options q/iparse/;
use File::Temp qw/tempfile tempdir/;
use Scalar::Util q/looks_like_number/;

our $VERSION = '1.016';
$VERSION =~ s/_//g;

##############################
# Exporting
use base 'Exporter';
our @EXPORT = qw(pgswin line points bins imag cont hold release erase);
our @EXPORT_OK = (@EXPORT, qw(image plot));

our $API_VERSION = '1.012'; # PGS version where that API started

##############################
# Configuration

# Knowledge base containing found info about each possible backend
our $mods = {};
our $mod_abbrevs = undef;
our $last_successful_type = undef;
our $global_plot = undef;

# lifted from PDL::Demos::list
sub _list_submods {
  my @d = @_;
  my @found;
  my %found_already;
  foreach my $path ( @INC ) {
    next if !-d (my $dir = File::Spec->catdir( $path, @d ));
    my @c = do { opendir my $dirfh, $dir or die "$dir: $!"; grep !/^\./, readdir $dirfh };
    for my $f (grep /\.pm$/ && -f File::Spec->catfile( $dir, $_ ), @c) {
      $f =~ s/\.pm//;
      my $found_mod = join "::", @d, $f;
      next if $found_already{$found_mod}++;
      push @found, $found_mod;
    }
    for my $t (grep -d $_->[1], map [$_, File::Spec->catdir( $dir, $_ )], @c) {
      my ($subname, $subd) = @$t;
      # one extra level
      my @c = do { opendir my $dirfh, $subd or die "$subd: $!"; grep !/^\./, readdir $dirfh };
      for my $f (grep /\.pm$/ && -f File::Spec->catfile( $subd, $_ ), @c) {
        $f =~ s/\.pm//;
        my $found_mod = join "::", @d, $subname, $f;
        next if $found_already{$found_mod}++;
        push @found, $found_mod;
      }
    }
  }
  @found;
}

for my $module (_list_submods(qw(PDL Graphics Simple))) {
  (my $file = $module) =~ s/::/\//g;
  require "$file.pm";
}
$mod_abbrevs ||= _make_abbrevs($mods); # Deal with abbreviations.

=head2 show

=for usage

 PDL::Graphics::Simple::show

=for ref

C<show> lists the supported engines and a one-line synopsis of each.

=cut
sub show {
    my $format = "%-10s %-30s %-s\n";
    printf($format, "NAME","Module","(synopsis)");
    printf($format, "----","------","----------");
    for my $engine( sort keys %$mods ) {
	printf($format, $engine, $mods->{$engine}->{engine}, $mods->{$engine}->{synopsis});
    }
    print "\n";
}

##############################
# Constructor - scan through registered subclasses and generate the correct one.

=head2 pgswin - exported constructor

=for usage

 $w = pgswin( %opts );

=for ref

C<pgswin> is a constructor that is exported by default into the using package. Calling
C<pgswin(%opts)> is exactly the same as calling C<< PDL::Graphics::Simple->new(%opts) >>.


=head2 new

=for usage

 $w = PDL::Graphics::Simple->new( %opts );

=for ref

C<new> is the main constructor for PDL::Graphics::Simple.  It accepts a list of options
about the type of window you want:

=over 3

=item engine

If specified, this must be one of the supported plotting engines.  You
can use a module name or the shortened name.  If you don't give one,
the constructor will try the last one you used, or else scan through
existing modules and pick one that seems to work.  It will first check
the environment variable C<PDL_SIMPLE_ENGINE>, and as of 1.011, only that will be tried, but
if you didn't specify one, all known engines are tried in alphabetical
order until one works.

=item size

This is a window size as an ARRAY ref containing [width, height,
units].  If no units are specified, the default is "inches".  Accepted
units are "in","pt","px","mm", and "cm". The conversion used for pixels
is 100 px/inch.

=item type

This describes the kind of plot to create, and should be either "file"
or "interactive" - though only the leading character is checked.  If
you don't specify either C<type> or C<output> (below), the default is
"interactive". If you specify only C<output>, the default is "file".

=item output

This should be a window number or name for interactive plots, or a
file name for file plots.  The default file name is "plot.png" in the
current working directory.  Individual plotting modules all support at
least '.png', '.pdf', and '.ps' -- via format conversion if necessary.
Most other standard file types are supported but are not guaranteed to
work.

=item multi

This enables plotting multiple plots on a single screen.  You feed in
a single array ref containing (nx, ny).  Subsequent calls to plot
send graphics to subsequent locations on the window.  The ordering
is always horizontal first, and left-to-right, top-to-bottom.

B<NOTE> for multiplotting: C<oplot> does not work and will cause an
exception. This is a limitation imposed by Gnuplot.

=back

=cut

our $new_defaults = {
    engine => '',
    size => [8,6,'in'],
    type => '',
    output => '',
    multi => undef
};

sub pgswin { __PACKAGE__->new(@_) }

sub _translate_new {
  my $opt_in = shift;
  $opt_in = {} unless(defined($opt_in));
  $opt_in = { $opt_in, @_ } if !ref $opt_in;
  my $opt = { iparse( $new_defaults, $opt_in ) };

  ##############################
  # Pick out a working plot engine...
  unless ($opt->{engine}) {
    # find the first working subclass...
    unless ($last_successful_type) {
      my @try = $ENV{'PDL_SIMPLE_ENGINE'} || sort keys %$mods;
      attempt: for my $engine( @try ) {
        print "Trying $engine ($mods->{$engine}->{engine})...";
        my $s;
        my $a = eval { $mods->{$engine}{module}->can('check')->() };
        if ($@) {
          chomp $@;
          $s = "$@";
        } else {
          $s = ($a ? "ok" : "nope");
        }
        print $s."\n";
        if ($a) {
          $last_successful_type = $engine;
          last attempt;
        }
      }
      barf "Sorry, all known plotting engines failed. Install one and try again"
        unless $last_successful_type;
    }
    $opt->{engine} = $last_successful_type;
  }

  my $engine = $mod_abbrevs->{lc($opt->{engine})};
  unless(defined($engine) and defined($mods->{$engine})) {
      barf "$opt->{engine} is not a known plotting engine. Use PDL::Graphics::Simple::show() for a list";
  }
  $last_successful_type = $opt->{engine};

  my $size = _regularize_size($opt->{size},'in');

  my $type = $ENV{PDL_SIMPLE_OUTPUT} ? 'f' : $opt->{type};
  my $output = $ENV{PDL_SIMPLE_OUTPUT} || $opt->{output};
  unless ($type) {
      # Default to file if output looks like a filename; to interactive otherwise.
      $type = (  ($output =~ m/\.(\w{2,4})$/) ? 'f' : 'i'  );
  }
  unless ($type =~ m/^[fi]/i) {
      barf "$type is not a known output type (must be 'file' or 'interactive')";
  }

  # Default to 'plot.png'  if no output is specified.
  $output ||= $type eq 'f' ? "plot.png" : "";

  # Hammer it into a '.png' if no suffix is specified
  if ( $type =~ m/^f/i and $output !~ m/\.(\w{2,4})$/ ) {
      $output .= ".png";
  }

  # Error-check multi
  if( defined($opt->{multi}) ) {
      if(  ref($opt->{multi}) ne 'ARRAY'  or  @{$opt->{multi}} != 2  ) {
          barf "PDL::Graphics::Simple::new: 'multi' option requires a 2-element ARRAY ref";
      }
      $opt->{multi}[0] ||= 1;
      $opt->{multi}[1] ||= 1;
  }

  my $params = { size=>$size, type=>$type, output=>$output, multi=>$opt->{multi} };
  ($engine, $params);
}

sub new {
  my $pkg = shift;
  my ($engine, $params) = &_translate_new;
  my $obj = $mods->{$engine}{module}->new($params);
  bless { engine=>$engine, params=>$params, obj=>$obj }, $pkg;
}

=head2 plot

=for usage

 $w = PDL::Graphics::Simple->new( %opts );
 $w->plot($data);

=for ref

C<plot> plots zero or more traces of data on a graph.  It accepts two kinds of
options: plot options that affect the whole plot, and curve options
that affect each curve.  The arguments are divided into "curve blocks", each
of which contains a curve options hash followed by data.

If the last argument is a hash ref, it is always treated as plot options.
If the first and second arguments are both hash refs, then the first argument
is treated as plot options and the second as curve options for the first curve
block.

=head3 Plot options:

=over 3

=item oplot

If this is set, then the plot overplots a previous plot.

=item title

If this is set, it is a title for the plot as a whole.

=item xlabel

If this is set, it is a title for the X axis.

=item ylabel

If this is set, it is a title for the Y axis.

=item xrange

If this is set, it is a two-element ARRAY ref containing a range for
the X axis.  If it is clear, the axis is autoscaled.

=item yrange

If this is set, it is a two-element ARRAY ref containing a range for
the Y axis.  If it is clear, the axis is autoscaled.

=item logaxis

This should be empty, "x", "y", or "xy" (case and order insensitive).
Named axes are scaled logarithmically.

=item crange

If this is set, it is a two-element ARRAY ref containing a range for
color values, full black to full white.  If it is clear, the engine or
plot module is responsible for setting the range.

=item wedge

If this is set, then image plots get a scientific colorbar on the
right side of the plot.  (You can also say "colorbar", "colorbox", or "cb" if
you're more familiar with Gnuplot).

=item justify

If this is set to a true value, then the screen aspect ratio is adjusted
to keep the Y axis and X axis scales equal -- so circles appear circular, and
squares appear square.

=item legend (EXPERIMENTAL)

The "legend" plot option is intended for full support but it is currently
experimental:  it is not fully implemented in all the engines, and
implementation is more variable than one would like in the engines that
do support it.

This controls whether and where a plot legend should be placed.  If
you set it, you supply a combination of 't','b','c','l', and 'r':
indicating top, bottom, center, left, right position for the plot
legend.  For example, 'tl' for top left, 'tc' for center top, 'c' or
'cc' for dead center.  If left unset, no legend will be plotted.  If
you set it but don't specify a position (or part of one), it defaults
to top and left.

If you supply even one 'key' curve option in the curves, legend defaults
to the value 'tl' if it isn't specified.

=back

=head3 Curve options:

=over 3

=item with

This names the type of curve to be plotted.  See below for supported curve types.

=item key

This gives a name for the following curve, to be placed in a master plot legend.
If you don't specify a name but do call for a legend, the curve will be named
with the plot type and number (e.g. "line 3" or "points 4").

=item width

This lets you specify the width of the line, as a multiplier on the standard
width the engine uses.  That lets you pick normal-width or extra-bold lines
for any given curve.  The option takes a single positive natural number.

=item style

You can specify the line style in a very limited way -- as a style
number supported by the backend.  The styles are generally defined by
a mix of color and dash pattern, but the particular color and dash
pattern depend on the engine in use. The first 30 styles are
guaranteed to be distinguishable. This is useful to produce, e.g.,
multiple traces with the same style. C<0> is a valid value.

=back

=head3 Curve types supported

=over 3

=item points

This is a simple point plot.  It takes 1 or 2 columns of data.

=item lines

This is a simple line plot. It takes 1 or 2 columns of data.

=item bins

Stepwise line plot, with the steps centered on each X value.  1 or 2 columns.

=item errorbars

Simple points-with-errorbar plot, with centered errorbars.  It takes 2
or 3 columns, and the last column is the absolute size of the errorbar (which
is centered on the data point).

=item limitbars

Simple points-with-errorbar plot, with asymmetric errorbars.  It takes
3 or 4 columns, and the last two columns are the absolute low and high
values of the errorbar around each point (specified relative to the
origin, not relative to the data point value).

=item circles

Plot unfilled circles.  Requires 2 or 3 columns of data; the last
column is the radius of each circle.  The circles are circular in
scientific coordinates, not necessarily in screen coordinates (unless
you specify the "justify" plot option).

=item image

This is a monochrome or RGB image.  It takes a 2-D or 3-D array of
values, as (width x height x color-index).  Images are displayed in
a sepiatone color scale that enhances contrast and preserves intensity
when converted to grayscale.  If you use the convenience routines
(C<image> or C<imag>), the "justify" plot option defaults to 1 -- so
the image will be displayed with square pixel aspect.  If you use
C<< plot(with=>'image' ...) >>, "justify" defaults to 0 and you will have
to set it if you want square pixels.

For RGB images, the numerical values need to be in the range 0-255,
as they are interpreted as 8 bits per plane colour values. E.g.:

  $w = pgswin(); # plot to a default-shape window
  $w->image( pdl(xvals(9,9),yvals(9,9),rvals(9,9))*20 );

  # or, from an image on disk:
  $image_data = rpic( 'my-image.png' )->mv(0,-1); # need RGB 3-dim last
  $w->image( $image_data );

If you have a 2-D field of values that you would like to see with a heatmap:

  use PDL::Graphics::ColorSpace;
  sub as_heatmap {
    my ($d) = @_;
    my $max = $d->max;
    die "as_heatmap: can't work if max == 0" if $max == 0;
    $d /= $max; # negative OK
    my $hue   = (1 - $d)*240;
    $d = cat($hue, pdl(1), pdl(1));
    (hsv_to_rgb($d->mv(-1,0)) * 255)->byte->mv(0,-1);
  }
  $w->image( as_heatmap(rvals 300,300) );

=item contours

As of 1.012. Draws contours. Takes a 2-D array of values, as (width x
height), and optionally a 1-D vector of contour values.

=item fits

As of 1.012. Displays an image from an ndarray with a FITS header.
Uses C<CUNIT[12]> etc to make X & Y axes including labels.

=item polylines

As of 1.012. Draws polylines, with 2 arguments (C<$xy>, C<$pen>).
The "pen" has value 0 for the last point in that polyline.

  use PDL::Transform::Cartography;
  use PDL::Graphics::Simple qw(pgswin);
  $coast = earth_coast()->glue( 1, scalar graticule(15,1) );
  $w = pgswin();
  $w->plot(with => 'polylines', $coast->clean_lines);

=item labels

This places text annotations on the plot.  It requires three input
arguments: the X and Y location(s) as PDLs, and the label(s) as a list
ref.  The labels are normally left-justified, but you can explicitly
set the alignment for each one by beginning the label with "<" for
left "|" for center, and ">" for right justification, or a single " "
to denote default justification (left).

=back

=cut

# Plot options have a bunch of names for familiarity to different package users.
# They're hammered into a single simplified set for transfer to the engines.

our $plot_options = PDL::Options->new( {
    oplot=> 0,
    title => undef,
    xlabel=> undef,
    ylabel=> undef,
    legend => undef,
    xrange=> undef,
    yrange=> undef,
    logaxis=> "",
    crange=> undef,
    bounds=> undef,
    wedge => 0,
    justify=>undef,
    });

$plot_options->synonyms( {
  cbrange=>'crange',
  replot=>'oplot',
  xtitle=>'xlabel',
  ytitle=>'ylabel',
  key=>'legend',
  colorbar=>'wedge',
  colorbox=>'wedge',
  cb=>'wedge',
  logscale => 'logaxis',
});
our $plot_types = {
  points    => { args=>[1,2], ndims=>[1]   },
  polylines => { args=>[1,2], ndims=>[1,2] },
  lines     => { args=>[1,2], ndims=>[1]   },
  bins      => { args=>[1,2], ndims=>[1]   },
  circles   => { args=>[2,3], ndims=>[1]   },
  errorbars => { args=>[2,3], ndims=>[1]   },
  limitbars => { args=>[3,4], ndims=>[1]   },
  image     => { args=>[1,3], ndims=>[2,3] },
  fits      => { args=>[1],   ndims=>[2,3] },
  contours  => { args=>[1,2], ndims=>[2]   },
  labels    => { args=>[3],   ndims=>[1]   },
};
our $plot_type_abbrevs = _make_abbrevs($plot_types);

our $curve_options = PDL::Options->new( {
  with => 'lines',
  key  => undef,
  style => undef,
  width => undef
});
$curve_options->synonyms( {
  legend =>'key',
  name=>'key'
});
$curve_options->incremental(0);

sub _fits_convert {
  my ($data, $opts) = @_;
  eval "use PDL::Transform";
  barf "PDL::Graphics::Simple: couldn't load PDL::Transform for 'with fits' option: $@" if $@;
  barf "PDL::Graphics::Simple: 'with fits' needs an image, RGB triplet, or RGBA quad" unless $data->ndims==2 || ($data->ndims==3 && ($data->dim(2)==4 || $data->dim(2)==3 || $data->dim(2)==1));
  my $h = $data->gethdr;
  barf "PDL::Graphics::Simple: 'with fits' expected a FITS header"
    unless $h && ref $h eq 'HASH' && !grep !$h->{$_}, qw(NAXIS NAXIS1 NAXIS2);
  # Now update plot options to set the axis labels, if they haven't been updated already...
  my %new_opts = %$opts;
  for ([qw(xlabel CTYPE1 X CUNIT1 (pixels))],
    [qw(ylabel CTYPE2 Y CUNIT2 (pixels))],
  ) {
    my ($label, $type, $typel, $unit, $unitdef) = @$_;
    next if defined $new_opts{$label};
    $new_opts{$label} = join(" ",
      $h->{$type} || $typel,
      $h->{$unit} ? "($h->{$unit})" : $unitdef
    );
  }
  my @dims01 = map $data->dim($_), 0,1;
  $data = $data->map(t_identity(), \@dims01, $h); # resample removing rotation etc
  my ($xcoords, $ycoords) = ndcoords(@dims01)->apply(t_fits($data->hdr, {ignore_rgb=>1}))->mv(0,-1)->dog;
  $new_opts{xrange} = [$xcoords->minmax] if !grep defined, @{$new_opts{xrange}};
  $new_opts{yrange} = [$ycoords->minmax] if !grep defined, @{$new_opts{yrange}};
  ('image', \%new_opts, $data, $xcoords, $ycoords);
}

sub _translate_plot {
  my ($held, $keys) = (shift, shift);

  ##############################
  # Trap some simple errors
  barf "plot: requires at least one argument to plot!" if !@_;
  barf "plot: requires at least one argument to plot, in addition to plot options"
    if @_ == 1 and ref($_[0]) eq 'HASH';
  barf "Undefined value given in plot args" if grep !defined(), @_;

  ##############################
  # Collect plot options.  These can be in a leading or trailing
  # hash ref, with the leading overriding the trailing one.  If the first
  # two elements are hash refs, then the first is plot options and
  # the second is curve options, otherwise we treat the first as curve options.
  # A curve option hash is required for every curve.
  my $po = {};

  while (ref($_[-1]) eq 'HASH') {
      my $h = pop;
      @$po{keys %$h} = values %$h;
  }

  if (ref($_[0]) eq 'HASH'   and    ref($_[1]) eq 'HASH') {
      my $h = shift;
      @$po{keys %$h} = values %$h;
  }

  my $called_from_imag = delete $po->{called_from_imag};

  $po = $plot_options->options($po);
  $po->{oplot} = 1 if $held;

  ##############################
  # Check the plot options for correctness.

  ### bounds is a synonym for xrange/yrange together.
  ### (dcm likes it)
  if (defined($po->{bounds})) {
    barf "Bounds option must be a 2-element ARRAY ref containing (xrange, yrange)"
      if !ref($po->{bounds}) or ref($po->{bounds}) ne 'ARRAY' or @{$po->{bounds}} != 2;
    for my $t ([0,'xrange'], [1, 'yrange']) {
      my ($i, $r) = @$t;
      next if !defined $po->{bounds}[$i];
      warn "WARNING: bounds overriding $r since both were specified\n"
        if defined $po->{$r};
      $po->{$r} = $po->{bounds}[$i];
    }
  }

  for my $r (grep defined($po->{$_}), qw(xrange yrange)) {
    barf "Invalid ".(uc substr $r, 0, 1)." range (must be a 2-element ARRAY ref with differing values)"
      if !ref($po->{$r}) or ref($po->{$r}) ne 'ARRAY' or @{$po->{$r}} != 2
        or $po->{$r}[0] == $po->{$r}[1];
  }

  if( defined($po->{wedge}) ) {
      $po->{wedge} = !!$po->{wedge};
  }

  if( length($po->{logaxis}) ) {
      if($po->{logaxis} =~ m/[^xyXY]/) {
          barf "logaxis must be X, Y, or XY (case insensitive)";
      }
      $po->{logaxis} =~ tr/XY/xy/;
      $po->{logaxis} =~ s/yx/xy/;
  }

  unless($po->{oplot}) {
      $keys = [];
  }

  $po->{justify} //= ($called_from_imag ? 1 : 0);

  ##############################
  # Parse out curve blocks and check each one for existence.
  my @blocks = ();
  my $xminmax = [undef,undef];
  my $yminmax = [undef,undef];

  while( @_ ) {
    my $co = {};
    my @args = ();

    if (ref $_[0] eq 'HASH') {
      $co = shift;
    } else {
      # Attempt to parse out curve option hash entries from an inline hash.
      # Keys must exist and not be refs and contain at least one letter.
      while( @_  and  !ref($_[0]) and $_[0] =~ m/[a-zA-Z]/ ) {
        my $a = shift;
        my $b = shift;
        $co->{$a} = $b;
      }
    }

    ##############################
    # Parse curve options and expand into standard form so we can find "with".
    $curve_options->options({key=>undef});
    my %co2 = %{$curve_options->options( $co )};

    my $ptn = $plot_type_abbrevs->{ $co2{with} };
    barf "Unknown plot type $co2{with}"
      unless defined($ptn) and defined($plot_types->{$ptn});

    if($co2{key} and !defined($po->{legend})) {
        $po->{legend} = 'tl';
    }

    unless( $ptn eq 'labels' ) {
        my $ptns = $ptn;
        $ptns=~s/s$//;
        push @$keys, $co2{key} // sprintf "%s %d",$ptns,1+@$keys;
    }

    my $pt = $plot_types->{$co2{with} = $ptn};

    ##############################
    # Snarf up the other arguments.

    while( @_ and  (  UNIVERSAL::isa($_[0], 'PDL') or
                      looks_like_number($_[0])  or
                      ref $_[0] eq 'ARRAY'
                      )
        )  {
        push @args, shift;
    }

    ##############################
    # Most array refs get immediately converted to
    # PDLs.  But the last argument to a "with=labels" curve
    # needs to be left as an array ref. If it's a PDL we throw
    # an error, since that's a common mistake case.
    if ( $ptn eq 'labels' ) {
      barf "Last argument to 'labels' plot type must be an array ref!"
        if ref($args[-1]) ne 'ARRAY';
      $_ = PDL->pdl($_) for grep !UNIVERSAL::isa($_,'PDL'), @args[0..$#args-1];
    } else {
      $_ = PDL->pdl($_) for grep !UNIVERSAL::isa($_,'PDL'), @args;
    }

    ##############################
    # Now check options
    barf "plot style $ptn requires ".join(" or ", @{$pt->{args}})." columns; you gave ".(0+@args)
      if !grep @args == $_, @{$pt->{args}};

    if ($ptn eq 'contours' and @args == 1) {
      my $cntr_cnt = 9;
      push @args, zeroes($cntr_cnt)->xlinvals($args[-1]->minmax);
    } elsif ($ptn eq 'polylines' and @args == 1) {
      barf "Single-arg form of '$ptn' must have dim 0 of 3"
        if $args[0]->dim(0) != 3;
      @args = ($args[0]->slice('0:1'), $args[0]->slice('(2)'));
    } elsif (defined($pt->{args}[1])) { # Add an index variable if needed
      barf "First arg to '$ptn' must have at least $pt->{ndims}[0] dims"
        if $args[0]->ndims < $pt->{ndims}[0];
      if ( $pt->{args}[1] - @args == 2 ) {
        my @dims = ($args[0]->dims)[0,1];
        unshift @args, xvals(@dims), yvals(@dims);
      }
      if ( $pt->{args}[1] - @args == 1 ) {
        unshift @args, xvals($args[0]);
      }
    }

    if ($ptn eq 'contours') { # not supposed to be compatible
      barf "Wrong dims for contours: need 2-D values, 1-D contour values"
        unless $args[0]->ndims == 2 and $args[1]->ndims == 1;
      ($xminmax, $yminmax) = ([0, $args[0]->dim(0)-1], [0, $args[0]->dim(1)-1]);
    } elsif ($ptn eq 'polylines') { # not supposed to be compatible
      barf "Wrong dims for contours: need 2-D values, 1-D contour values"
        unless $args[0]->ndims == 2 and $args[1]->ndims == 1;
      ($xminmax, $yminmax) = map [$_->minmax], $args[0]->using(0,1);
    } else {
      # Check that the PDL arguments all agree in a threading sense.
      # Since at least one type of args has an array ref in there, we have to
      # consider that case as a pseudo-PDL.
      my $dims = do {
        local $PDL::undefval = 1;
        pdl([map [ ref($_) eq 'ARRAY' ? 0+@{$_} : $_->dims ], @args]);
      };
      my $dmax = $dims->mv(1,0)->maximum;
      barf "Data dimensions do not agree in plot: $dims vs max=$dmax"
        unless ( ($dims==1) | ($dims==$dmax) )->all;

      # Check that the number of dimensions is correct...
      barf "Data dimension (".$dims->dim(0)."-D PDLs) is not correct for plot type $ptn (all dims=$dims)"
        if $dims->dim(0) != $pt->{ndims}[0] and
          (!defined($pt->{ndims}[1]) or $dims->dim(0) != $pt->{ndims}[1]);

      if (@args > 1) {
        # Accumulate x and y ranges...
        my $dcorner = pdl(0,0);
        # Deal with half-pixel offset at edges of images
        if ($args[0]->dims > 1) {
          my $xymat = pdl(
            [ ($args[0]->slice("(1),(0)")-$args[0]->slice("(0),(0)")),
              ($args[0]->slice("(0),(1)")-$args[0]->slice("(0),(0)")) ],
            [ ($args[1]->slice("(1),(0)")-$args[1]->slice("(0),(0)")),
              ($args[1]->slice("(0),(1)")-$args[1]->slice("(0),(0)")) ]
          );
          $dcorner = ($xymat x pdl(0.5,0.5)->slice("*1"))->slice("(0)")->abs;
        }
        for my $t ([0, qr/x/, $xminmax], [1, qr/y/, $yminmax]) {
          my ($i, $re, $var) = @$t;
          my @minmax = $args[$i]->minmax;
          $minmax[0] -= $dcorner->at($i);
          $minmax[1] += $dcorner->at($i);
          if ($po->{logaxis} =~ $re) {
            if ($minmax[1] > 0) {
              $minmax[0] = $args[0]->where( ($args[0]>0) )->min if $minmax[0] <= 0;
            } else {
              $minmax[0] = $minmax[1] = undef;
            }
          }
          $var->[0] = $minmax[0] if defined($minmax[0])
            and ( !defined($var->[0]) or $minmax[0] < $var->[0] );
          $var->[1] = $minmax[1] if defined($minmax[1])
            and ( !defined($var->[1]) or $minmax[1] > $var->[1] );
        }
      }
    }

    # Push the curve block to the list.
    unshift @args, \%co2;
    push @blocks, \@args;
  }

  ##############################
  # Deal with context-dependent defaults.

  for my $t (['xrange',$xminmax], ['yrange',$yminmax]) {
    my ($r, $var) = @$t;
    $po->{$r}[0] //= $var->[0];
    $po->{$r}[1] //= $var->[1];
    my $defined_range_vals = grep defined, @{$po->{$r}}[0,1];
    next if !$defined_range_vals;
    barf "got 1 defined value for '$r'" if $defined_range_vals < 2;
    if ($po->{$r}[0] == $po->{$r}[1]) {
      $po->{$r}[0] -= 0.5;
      $po->{$r}[1] += 0.5;
    }
  }

  for my $t (grep $po->{logaxis} =~ $_->[1], ['xrange', qr/x/], ['yrange', qr/y/]) {
    my ($r) = @$t;
    barf "logarithmic ".(uc substr $r, 0, 1)." axis requires positive limits ($r is [$po->{$r}[0],$po->{$r}[1]])"
      if $po->{$r}[0] <= 0 or $po->{$r}[1] <= 0;
  }
  ($keys, $po, @blocks);
}

sub plot {
  my $obj = &_invocant_or_global;
  my @args = _translate_plot(@$obj{qw(held keys)}, @_);
  barf "Can't oplot in multiplot" if $obj->{params}{multi} and $args[1]{oplot};
  $obj->{obj}{keys} = $obj->{keys} = shift @args;
  $obj->{obj}->plot(@args);
}

=head2 oplot

=for usage

 $w = PDL::Graphics::Simple->new( %opts );
 $w->plot($data);
 $w->oplot($more_data);

=for ref

C<oplot> is a convenience interface.  It is exactly
equivalent to C<plot> except it sets the plot option C<oplot>,
so that the plot will be overlain on the previous one.

=cut

sub oplot {
    push @_, {} if ref($_[-1]) ne 'HASH';
    $_[-1]{oplot} = 1;
    plot(@_);
}

=head2 line, points, bins, image, imag, cont

=for usage

 # Object-oriented convenience
 $w = PDL::Graphics::Simple->new( % opts );
 $w->line($data);

 # Very Lazy Convenience
 $a = xvals(50);
 lines $a;
 $im = sin(rvals(100,100)/3);
 imag $im;
 imag $im, 0, 1, {title=>"Bullseye?", j=>1};

=for ref

C<line>, C<points>, and C<image> are convenience
interfaces.  They are exactly equivalent to C<plot> except that
they set the default "with" curve option to the appropriate
plot type.

C<imag> is even more DWIMMy for PGPLOT users or PDL Book readers:
it accepts up to three non-hash arguments at the start of the
argument list.  The second and third are taken to be values for
the C<crange> plot option.

C<cont> resembles the PGPLOT function.

=cut

sub _translate_convenience {
  my $type = shift;
  my @args = @_;
  barf "Not enough args to PDL::Graphics::Simple::$type()" if( @args < 1 );
  if( ref($args[0]) eq 'HASH' ) {
    if( ref($args[1]) eq 'HASH' ) {
      $args[1]->{with} = $type;
    } else {
      $args[0]->{with} = $type;
    }
  } else {
    unshift(@args, 'with', $type);
  }
  @args;
}

sub _convenience_plot {
  my $type = shift;
  my $me = &_invocant_or_global;
  my @args = _translate_plot(@$me{qw(held keys)}, _translate_convenience($type, @_));
  $me->{obj}{keys} = $me->{keys} = shift @args;
  $me->{obj}->plot(@args);
}

sub line { _convenience_plot( 'line',   @_ ); }
*PDL::lines  = *lines = *PDL::line   = \&line;

sub bins { _convenience_plot( 'bins',   @_ ); }
*PDL::bins   = \&bins;

sub points { _convenience_plot( 'points', @_ ); }
*PDL::points = \&points;

sub image { _convenience_plot( 'image',  @_, {called_from_imag=>1}); }
# Don't PDL-namespace image since it's so different from imag.

sub cont { _convenience_plot( 'contours', @_ ); }

sub _translate_imag {
  my $me = &_invocant_or_global;
  my $data = shift;
  my $crange = [];
  unless(ref($_[0]) eq 'HASH') {
    $crange->[0] = shift;
    unless(ref($_[0]) eq 'HASH') {
      $crange->[1] = shift;
    }
  }
  # Try to put the crange into the plot options, if they are present
  unless( ref($_[$#_]) eq 'HASH' ) {
    push @_, {};
  }
  $_[$#_]->{crange} = $crange;
  ($me, $data, @_, {called_from_imag=>1});
}

sub imag { _convenience_plot( 'image',  &_translate_imag ); }
*PDL::imag = \&imag;

=head2 erase

=for usage

 use PDL::Graphics::Simple qw/erase hold release/;
 line xvals(10), xvals(10)**2 ;
 sleep 5;
 erase;

=for ref

C<erase> removes a global plot window.  It should not be called as a method.
To remove a plot window contained in a variable, undefine it.

=cut

our $global_object;

sub erase {
    my $me = shift;
    if(defined($me)) {
	barf "PDL::Graphics::Simple::erase: no arguments, please";
    }
    if(defined($global_object)) {
	undef $global_object;
    }
}

=head2 hold

=for usage

 use PDL::Graphics::Simple;
 line xvals(10);
 hold;
 line xvals(10)**0.5;

=for ref

Causes subsequent plots to be overplotted on any existing one.  Called
as a function with no arguments, C<hold> applies to the global object.
Called as an object method, it applies to the object.

=cut

sub hold {
    my $me = shift;
    if(defined($me) and UNIVERSAL::isa($me,"PDL::Graphics::Simple")) {
	$me->{held} =1;
    } elsif(defined($global_object)) {
	$global_object->{held}=1;
    } else {
	barf "Can't hold a nonexistent window!";
    }
}

=head2 release

=for usage

 use PDL::Graphics::Simple;
 line xvals(10);
 hold;
 line xvals(10)**0.5;
 release;
 line xvals(10)**0.5;

=for ref

Releases a hold placed by C<hold>.

=cut

sub release {
    my $me = shift;
    if(defined($me) and UNIVERSAL::isa($me,"PDL::Graphics::Simple")) {
	$me->{held} = 0;
    } elsif(defined($global_object)) {
	$global_object->{held} = 0;
    } else {
	barf "Can't release a nonexistent window!";
    }
}

##############################
# Utilities.


sub _invocant_or_global {
  return shift if UNIVERSAL::isa($_[0], "PDL::Graphics::Simple");
  return $global_object if defined $global_object;
  $global_object = pgswin();
}


### Units table - cheesy but also horrible.
our $units = {
    'inch'=>1,
    'inc'=>1,
    'in' =>1,
    'i' => 1,
    'char'=>16,
    'cha'=>16,
    'ch'=>16,
    'c'=>16,
    'points'=>72,
    'point'=>72,
    'poin'=>72,
    'poi'=>72,
    'po'=>72,
    'pt'=>72,
    'px'=>100,
    'pixels'=>100,
    'pixel'=>100,
    'pixe'=>100,
    'pix'=>100,
    'pi'=>100,
    'p'=>100,
    'mm' => 25.4,
    'cm' => 2.54
};

### regularize_size -- handle the various cases for the size option to new.
sub _regularize_size {
    my $size = shift;
    my $unit = shift;

    $unit =~ tr/A-Z/a-z/;
    barf "size specifier unit '$unit' is unrecognized" unless($units->{$unit});

    unless(ref($size)) {
	$size = [ $size, $size, 'in' ];
    } elsif(ref($size) ne 'ARRAY') {
	barf "size option requires an ARRAY ref or scalar";
    }
    barf "size array must have at least one element" unless(@{$size});
    $size->[1] = $size->[0]     if(@{$size}==1);
    $size->[2] = 'in'           if(@{$size}==2);
    barf "size array can have at most three elements" if(@{$size}>3);
    barf "size array unit '$unit' is unrecognized" unless($units->{$unit});
    barf "new: size must be nonnegative" unless( $size->[0] > 0   and   $size->[1] > 0 );

    my $ret = [];
    $ret->[0] = $size->[0] / $units->{$size->[2]} * $units->{$unit};
    $ret->[1] = $size->[1] / $units->{$size->[2]} * $units->{$unit};
    $ret->[2] = $unit;
    return $ret;
}

##########
# make_abbrevs - generate abbrev hash for module list.  Cheesy but fast to code.
sub _make_abbrevs {
    my $hash = shift;
    my $abbrevs = {};
    my %ab = ();
    for my $k(keys %$hash) {
	my $s = $k;
	while(length($s)) {
	    push @{$ab{$s}},$k;
	    chop $s;
	}
    }
    for my $k(keys %ab) {
	$abbrevs->{$k} = $ab{$k}->[0] if( @{$ab{$k}} == 1);
    }
    return $abbrevs;
}

=head2 register

=for usage

 PDL::Graphics::Simple::register( \%description );

=for ref

This is the registration mechanism for new driver methods for
C<PDL::Graphics::Simple>.  Compliant drivers should announce
themselves at compile time by calling C<register>, passing
a hash ref containing the following keys:

=over

=item shortname

This is the short name of the engine, by which users refer to it colloquially.

=item module

This is the fully qualified package name of the module itself.

=item engine

This is the fully qualified package name of the Perl API for the graphics engine.

=item synopsis

This is a brief string describing the backend

=item pgs_api_version

This is a one-period version number of PDL::Graphics::Simple against which
the module has been tested.  A warning will be thrown if the version isn't the
same as C<$PDL::Graphics::Simple::API_VERSION>.

That value will only change when the API changes, allowing the modules
to be released independently, rather than with every version of
PDL::Graphics::Simple as up to 1.010.

=back

=cut

sub register {
    my $mod = shift;
    my $module = $mod->{module};
    barf __PACKAGE__."::register: \\%description from ".caller()." looks fishy, no 'module' key found; I give up" unless defined $module;
    for (qw/shortname engine synopsis pgs_api_version/) {
	barf __PACKAGE__."::register: \\%description from $module looks fishy, no '$_' key found; I give up"
	    unless defined $mod->{$_};
    }
    warn __PACKAGE__."::register: $module is out of date (mod='$mod->{pgs_api_version}' PGS='$API_VERSION') - winging it"
	unless $mod->{pgs_api_version} eq $API_VERSION;
    $mods->{$mod->{shortname}} = $mod;
}


=head1 IMPLEMENTATION

PDL::Graphics::Simple defines an object that represents a plotting
window/interface.  When you construct the object, you can either
specify a backend or allow PDL::Graphics::Simple to find a backend
that seems to work on your system.  Subsequent plotting commands are
translated and passed through to that working plotting module.

PDL::Graphics::Simple calls are dispatched in a two-step process. The
main module curries the arguments, parsing them into a regularized
form and carrying out DWIM optimizations. The regularized arguments
are passed to implementation classes that translate them into the APIs of their
respective plot engines.  The classes are very simple and implement
only a few methods, outlined below.  They are intended only to be
called by the PDL::Graphics::Simple driver, which limits the need for
argument processing, currying, and parsing. The classes are thus
responsible only for converting the regularized parameters to plot
calls in the form expected by their corresponding plot modules.

PDL::Graphics::Simple works through a call-and-dispatch system rather
than taking full advantage of inheritance.  That is for two reasons:
(1) it makes central control mildly easier going forward, since calls
are dispatched through the main module; and (2) it makes the
non-object-oriented interface easier to implement since the main
interface modules are in one place and can access the global object
easily.

=head2 Interface class methods

Each interface module supports the following methods:

=cut

# Note that these are =head3; that means they won't be indexed by PDL::Doc,
# which is a Good Thing as they are internal routines.

=head3 check

C<check> attempts to load the relevant engine module and test that it
is working.  In addition to returning a boolean value indicating
success if true, it registers its success or failure in
the main $mods hash, under the "ok" flag.  If there is a failure that
generates an error message, the error is logged under the "msg" flag.

C<check> accepts one parameter, "force".  If it is missing or false,
and "ok" is defined, check just echoes the prior result.  If it is
true, then check actually checks the status regardless of the "ok"
flag.

=head3 new

C<new> creates and returns an appropriate plot object, or dies on
failure.

Each C<new> method should accept the following options, defined as in
the description for PDL::Graphics::Simple::new (above).  There is
no need to set default values as all arguments should be set to
reasonable values by the superclass.

For file output, the method should autodetect file type by dot-suffix.
At least ".png" and ".ps" should be supported.

Required options: C<size>, C<type>, C<output>, C<multi>.

=head3 plot

C<plot> generates a plot.  It should accept a standardized collection
of options as generated by the PDL::Graphics::Simple plot method:
standard plot options as a hash ref, followed by a list of curve
blocks.  It should render either a full-sized plot that fills the plot
window or, if the object C<multi> option was set on construction, the
current subwindow.  For interactive plot types it should act as an
atomic plot operation, displaying the complete plot.  For file plot
types the atomicity is not well defined, since multiplot grids may
be problematic, but the plot should be closed as soon as practical.

The plot options hash contains the plot options listed under C<plot>,
above, plus one additional flag - C<oplot> - that indicates the new
data is to be overplotted on top of whatever is already present in the
plotting window.  All options are present in the hash. The C<title>,
C<xlabel>, C<ylabel>, and C<legend> options default to undef, which
indicates the corresponding plot feature should not be rendered.  The
C<oplot>, C<xrange>, C<yrange>, C<crange>, C<wedge>, and C<justify>
parameters are always both present and defined.

If the C<oplot> plot option is set, then the plot should be overlain on
a previous plot, not losing any range settings, nor obeying any given.
B<NOTE> that if any data given to the original plot or any overplots might
be changed before plot updates happen, it is the user's responsibility
to pass in copies, since some engines (Prima and Gnuplot) only store
data by reference for performance reasons.
Otherwise the module should display a fresh plot.

Each curve block consists of an ARRAY ref with a hash in the 0 element
and all required data in the following elements, one PDL per
(ordinate/abscissa).  For 1-D plot types (like points and lines) the
PDLs must be 1D.  For image plot types the lone PDL must be 2D
(monochrome) or 3D(RGB).

The hash in the curve block contains the curve options for that
particular curve.  They are all set to have reasonable default values.
The values passed in are C<with> and C<key>.  If the C<legend>
option is undefined, then the curve should not be placed into a plot
legend (if present).

=head1 ENVIRONMENT

Setting some environment variables affects operation of the module:

=head2 PDL_SIMPLE_ENGINE

See L</new>.

=head2 PDL_SIMPLE_DEVICE

If this is a meaningful thing for the given engine, this value will be
used instead of the driver module guessing.

=head2 PDL_SIMPLE_OUTPUT

Overrides passed-in arguments, to create the given file as output.
If it contains C<%d>, then with Gnuplot that will be replaced with an
increasing number (an amazing L<PDL::Graphics::Gnuplot> feature).

=head1 TO-DO

Deal with legend generation.  In particular: adding legends with multi-call
protocols is awkward and leads to many edge cases in the internal protocol.
This needs more thought.

=head1 REPOSITORY

L<https://github.com/PDLPorters/PDL-Graphics-Simple>

=head1 AUTHOR

Craig DeForest, C<< <craig@deforest.org> >>


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Craig DeForest

This program is free software; you can redistribute it and/or modify
it under the terms of either: the Gnu General Public License v1 as
published by the Free Software Foundation; or the Perl Artistic
License included with the Perl language.

see http://dev.perl.org/licenses/ for more information.

=cut

1;
