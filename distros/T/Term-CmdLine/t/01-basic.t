#!perl
# Basic functionality test - creates ONE Term::CmdLine instance
use 5.010;
use strict;
use warnings;
use Test::More tests => 10;
use File::Temp qw(tempfile);

BEGIN {
  use_ok ('Term::CmdLine');
}

# Test object creation (only create ONE instance due to Term::ReadLine::Gnu limitation)
my ($fh, $histfile) = tempfile ();
close $fh;

my $cmdline = Term::CmdLine->new ($histfile);
isa_ok ($cmdline, 'Term::CmdLine', 'Created CmdLine object');

# Test set_prompt
my $old_prompt = $cmdline->set_prompt ('test>');
is ($cmdline->{prompt}, 'test>', 'Prompt was set correctly');

# Test set_cmds
my %test_cmds = (
  foo => {
    help        => 'foo command',
    description => 'Test foo command',
  },
  bar => {
    help        => 'bar command',
    description => 'Test bar command',
  },
);

$cmdline->set_cmds (%test_cmds);

# Test variable management
$cmdline->_set ('testvar', 'testvalue');
is ($cmdline->_get ('testvar'),
  'testvalue', 'Variable set and retrieved correctly');

# Test interpolation
my $result = $cmdline->_interpolate ('Value is $testvar');
is ($result, 'Value is testvalue', 'Variable interpolation works');

# Test multiple variables
$cmdline->_set ('var1', 'hello');
$cmdline->_set ('var2', 'world');
$result = $cmdline->_interpolate ('$var1 $var2');
is ($result, 'hello world', 'Multiple variable interpolation');

# Test undefined variable
$result = $cmdline->_interpolate ('Value: $undefined');
is ($result, 'Value: ', 'Undefined variable becomes empty');

# Test variable deletion
$cmdline->_set ('tempvar', 'temp');
is ($cmdline->_get ('tempvar'), 'temp', 'Temp variable set');
$cmdline->_set ('tempvar', undef);
is ($cmdline->_get ('tempvar'), undef, 'Temp variable deleted');

# Test history file
ok (-f $histfile, 'History file was created');

# Cleanup
unlink $histfile;

diag ('');
diag ('All basic tests passed!');
diag ('For interactive testing, create a script using Term::CmdLine');
diag ('to test command completion, history navigation, etc.');
