# Before "./Build install" is performed this script should be runnable with
# "./Build build && ./Build test".
#
# After "./Build install" it should work as "perl 35-tk-5.t".
#
# Without "Build" file it could be called with "perl -I../lib 35-tk-5.t"
# or "perl -Ilib t/35-tk-5.t".  This is also the command needed to find
# out what specific tests failed in a "./Build test" as the later only gives
# you a number and not the description of the test.
#
# For successful run with test coverage use "./Build testcover".

# Note that the original sole test script had to be split up into one part
# per running UI::Various::Tk::mainloop due to sporadic (11%) segmentation
# violations in Tk's internal code.
# An additional forced initialisation did not help as it blocked the
# mainloop.

#########################################################################

use v5.14;
use strictures;
no indirect 'fatal';
no multidimensional;

use Cwd 'abs_path';

use Test::More;
use Test::Output;

BEGIN {
    $ENV{DISPLAY}  or  plan skip_all => 'DISPLAY not found';
    eval { require Tk; };
    $@  and  plan skip_all => 'Perl/Tk not found';
    plan tests => 3;

    # define fixed environment for unit tests:
    delete $ENV{UI};
}

use UI::Various({use => ['Tk']});
diag('UI::Various::Tk has been initialised');	# TODO: temporary diagnostics

#########################################################################
# specific check for problematic configuration, is sub-test as the
# additional check otherwise might affect further tests in some Perl and/or
# Tk versions:
use constant T_PATH => map { s|/[^/]+$||; $_ } abs_path($0);
do(T_PATH . '/functions/sub_perl.pl');
$_ = _sub_perl('require Tk;
		$_ = MainWindow->new();
		$_->fontActual("", "-size");
		$_->destroy;');
if ($_)
{
    diag('Your ', $^O,
	 ' apparently has a strange font configuration (no default font?).',
	 '  This will hurt!');
}
# TODO: temporary check for specific CPAN smoker:
if ($ENV{DISPLAY} =~ m/:121$/)
{
    diag 'extended check for DISPLAY == ', $ENV{DISPLAY};
    diag 'TK has version ', $Tk::VERSION;
    my ($countdown, $pid) = (10, 0);
    while (--$countdown > 0)
    {
	sleep 7  if $countdown < 10;
	open my $ps, '-|', 'ps', 'auxww'  or  die "can't PS: $!\n";
	my $found = 0;
	while (<$ps>)
	{
	    next unless m/[X][a-z].* :121\b/;
	    m/^[^ ]+\s+(\d+).*/  and  $pid = $1;
	    $found++;
	}
	close $ps;
	last if $found > 0;
	diag 'X server not yet running - ', $countdown;
    }
    if ($countdown > 0)
    {   diag 'X server seems to be running with PID ', $pid;   }
    else
    {   diag 'no X server - we will fail';   }
}

####################################
# test unused behaviour (and get 100% coverage):

my $main = UI::Various::Main->new();
my $win1 = UI::Various::Window->new(title => 'hello');
my $dialog = UI::Various::Dialog->new();
my $dialog2 = UI::Various::Dialog->new(height => 5);
my $dialog3 = UI::Various::Dialog->new(height => 5, width => 10);

$_ = @{$main->{children}};
is($_, 4, 'main has correct number of children');
$_ = $win1->title;
is($_, 'hello', 'window constructor sets title');

$_ = $dialog2->top->child(0);

# The following call core-dumps on some of the CPAN test servers in the Tk
# call MainWindow - so far I was not able to reproduce this to track it
# down:
$dialog2->_prepare();

$win1->destroy();
$dialog->destroy();
$dialog2->destroy();

$_ = $dialog3->top->child(0);

$dialog3->_prepare();
$dialog3->destroy();

$_ = @{$main->{children}};
is($_, 0, 'main is clean again');

$main->mainloop();		# an additional empty call just for the coverage
