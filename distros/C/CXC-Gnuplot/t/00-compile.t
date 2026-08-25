use 5.006;
use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Compile 2.058

use Test::More;

plan tests => 76 + ($ENV{AUTHOR_TESTING} ? 1 : 0);

my @module_files = (
    'CXC/Gnuplot.pm',
    'CXC/Gnuplot/V0.pm',
    'CXC/Gnuplot/V0/Axis.pm',
    'CXC/Gnuplot/V0/AxisFormat.pm',
    'CXC/Gnuplot/V0/AxisLabel.pm',
    'CXC/Gnuplot/V0/AxisMinorTics.pm',
    'CXC/Gnuplot/V0/AxisRange.pm',
    'CXC/Gnuplot/V0/AxisTics.pm',
    'CXC/Gnuplot/V0/Bound.pm',
    'CXC/Gnuplot/V0/Bound/Numeric.pm',
    'CXC/Gnuplot/V0/Bound/TimeDate.pm',
    'CXC/Gnuplot/V0/Color.pm',
    'CXC/Gnuplot/V0/ColorSpec.pm',
    'CXC/Gnuplot/V0/CoordOffset2D.pm',
    'CXC/Gnuplot/V0/CoordOffset3D.pm',
    'CXC/Gnuplot/V0/CoordPosition2D.pm',
    'CXC/Gnuplot/V0/CoordPosition3D.pm',
    'CXC/Gnuplot/V0/CoordValue.pm',
    'CXC/Gnuplot/V0/Font.pm',
    'CXC/Gnuplot/V0/Key.pm',
    'CXC/Gnuplot/V0/Key/Title.pm',
    'CXC/Gnuplot/V0/Label.pm',
    'CXC/Gnuplot/V0/LiteralDataValue.pm',
    'CXC/Gnuplot/V0/Margin.pm',
    'CXC/Gnuplot/V0/MultiPlot.pm',
    'CXC/Gnuplot/V0/MultiPlot/Margins.pm',
    'CXC/Gnuplot/V0/MultiPlot/Title.pm',
    'CXC/Gnuplot/V0/Range.pm',
    'CXC/Gnuplot/V0/TermOptions.pm',
    'CXC/Gnuplot/V0/Terminal.pm',
    'CXC/Gnuplot/V0/Terminal/cairo.pm',
    'CXC/Gnuplot/V0/Terminal/pdfcairo.pm',
    'CXC/Gnuplot/V0/Terminal/pngcairo.pm',
    'CXC/Gnuplot/V0/Timestamp.pm',
    'CXC/Gnuplot/V0/Title.pm',
    'CXC/Gnuplot/V0/Types.pm',
    'CXC/Gnuplot/V0/Util.pm',
    'CXC/Gnuplot/V1.pm',
    'CXC/Gnuplot/V1/Axis.pm',
    'CXC/Gnuplot/V1/AxisFormat.pm',
    'CXC/Gnuplot/V1/AxisLabel.pm',
    'CXC/Gnuplot/V1/AxisMinorTics.pm',
    'CXC/Gnuplot/V1/AxisRange.pm',
    'CXC/Gnuplot/V1/AxisTics.pm',
    'CXC/Gnuplot/V1/Base.pm',
    'CXC/Gnuplot/V1/Bound.pm',
    'CXC/Gnuplot/V1/Bound/Numeric.pm',
    'CXC/Gnuplot/V1/Bound/TimeDate.pm',
    'CXC/Gnuplot/V1/Color.pm',
    'CXC/Gnuplot/V1/ColorSpec.pm',
    'CXC/Gnuplot/V1/CoordOffset2D.pm',
    'CXC/Gnuplot/V1/CoordOffset3D.pm',
    'CXC/Gnuplot/V1/CoordPosition2D.pm',
    'CXC/Gnuplot/V1/CoordPosition3D.pm',
    'CXC/Gnuplot/V1/CoordValue.pm',
    'CXC/Gnuplot/V1/Font.pm',
    'CXC/Gnuplot/V1/Key.pm',
    'CXC/Gnuplot/V1/Key/Title.pm',
    'CXC/Gnuplot/V1/Label.pm',
    'CXC/Gnuplot/V1/LiteralDataValue.pm',
    'CXC/Gnuplot/V1/Margin.pm',
    'CXC/Gnuplot/V1/MultiPlot.pm',
    'CXC/Gnuplot/V1/MultiPlot/Margins.pm',
    'CXC/Gnuplot/V1/MultiPlot/Title.pm',
    'CXC/Gnuplot/V1/Range.pm',
    'CXC/Gnuplot/V1/Role/Clone.pm',
    'CXC/Gnuplot/V1/TermOptions.pm',
    'CXC/Gnuplot/V1/Terminal.pm',
    'CXC/Gnuplot/V1/Terminal/cairo.pm',
    'CXC/Gnuplot/V1/Terminal/pdfcairo.pm',
    'CXC/Gnuplot/V1/Terminal/pngcairo.pm',
    'CXC/Gnuplot/V1/TerminalBase.pm',
    'CXC/Gnuplot/V1/Timestamp.pm',
    'CXC/Gnuplot/V1/Title.pm',
    'CXC/Gnuplot/V1/Types.pm',
    'CXC/Gnuplot/V1/Util.pm'
);



# no fake home requested

my @switches = (
    -d 'blib' ? '-Mblib' : '-Ilib',
);

use File::Spec;
use IPC::Open3;
use IO::Handle;

open my $stdin, '<', File::Spec->devnull or die "can't open devnull: $!";

my @warnings;
for my $lib (@module_files)
{
    # see L<perlfaq8/How can I capture STDERR from an external command?>
    my $stderr = IO::Handle->new;

    diag('Running: ', join(', ', map { my $str = $_; $str =~ s/'/\\'/g; q{'} . $str . q{'} }
            $^X, @switches, '-e', "require q[$lib]"))
        if $ENV{PERL_COMPILE_TEST_DEBUG};

    my $pid = open3($stdin, '>&STDERR', $stderr, $^X, @switches, '-e', "require q[$lib]");
    binmode $stderr, ':crlf' if $^O eq 'MSWin32';
    my @_warnings = <$stderr>;
    waitpid($pid, 0);
    is($?, 0, "$lib loaded ok");

    shift @_warnings if @_warnings and $_warnings[0] =~ /^Using .*\bblib/
        and not eval { +require blib; blib->VERSION('1.01') };

    if (@_warnings)
    {
        warn @_warnings;
        push @warnings, @_warnings;
    }
}



is(scalar(@warnings), 0, 'no warnings found')
    or diag 'got warnings: ', ( Test::More->can('explain') ? Test::More::explain(\@warnings) : join("\n", '', @warnings) ) if $ENV{AUTHOR_TESTING};


