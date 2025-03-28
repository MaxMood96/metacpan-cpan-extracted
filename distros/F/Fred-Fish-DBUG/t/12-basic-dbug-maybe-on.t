#!/user/bin/perl

# Program:  12-basic-dbug-maybe-on.t
#   Does a very basic fish trace with fish conditionally on or off.
#   Uses the same environment variable, FISH_OFF_FLAG, as used in helper1234.pm.
#   If set to a non-zero value OFF is used.  Otherwise ON is used.

# NOTE 1: Keep all the t/*-basic-*.t programs in sync.
#         They should all perform the excact same tests with the only
#         differences being in the BEGIN blocks!  All that is basically
#         being tested is some trivial functionality to make sure each
#         tested module has no compile issues!

# NOTE 2: t/*-basic-help.t does basically the same thing but is the
#         first test to use t/off/helper1234 for dynamic tests.

use strict;
use warnings;

use Test::More tests => 11;
use File::Basename;
use File::Spec;

my $start_level;

sub my_warn
{
   BAIL_OUT ( "An Unexpected Warning was trapped!");
   exit (0);
}

sub ok2
{
   DBUG_ENTER_BLOCK ("Test::More::ok", @_);
   my $status = shift || 0;
   my $msg    = shift;

   my $res = ok ( $status, $msg );
   DBUG_RETURN ($res);
}

sub is2
{
   DBUG_ENTER_BLOCK ("Test::More::is", @_);
   my ($got, $expected, $msg) = @_;
   my $res = is ($got, $expected, $msg);
   DBUG_RETURN ($res);
}

BEGIN {
   # Can't use any of the constants defined by this module
   # unless we use them in a separate BEGIN block!

   # Swap the value so on_if_set works as expected.
   $ENV{FISH_OFF_FLAG} = ! $ENV{FISH_OFF_FLAG};

   unless (use_ok ( "Fred::Fish::DBUG", qw ( on_if_set FISH_OFF_FLAG ) )) {
      BAIL_OUT ( "Can't load Fred::Fish::DBUG" );
      exit (0);
   }
   unless (use_ok ( "Fred::Fish::DBUG::Signal" )) {         # Test # 2
      BAIL_OUT ( "Can't load Fred::Fish::DBUG::Signal" );
      exit (0);
  }
}

BEGIN {
   my $fish = $0;
   $fish =~ s/[.]t$//;
   $fish .= ".fish.txt";

   $fish = File::Spec->catfile (dirname ($fish), "fish", basename ($fish));

   # Make sure DIE is trapped in case future changes no longer trap by default!
   DBUG_TRAP_SIGNAL ("__DIE__", DBUG_SIG_ACTION_DIE );

   # So can detect if the module generates any warnings ...
   DBUG_TRAP_SIGNAL ( "__WARN__", DBUG_SIG_ACTION_LOG, \&my_warn );

   unlink ($fish);
   DBUG_PUSH ( $fish );

   DBUG_ENTER_FUNC ();

   my $lvl = -1;    # Says dbug_level() is broken for this test!
   my $mod = Fred::Fish::DBUG::dbug_module_used ();
   unless ( $ENV{FISH_OFF_FLAG} ) {
      is2 ($mod, "Fred::Fish::DBUG::OFF", "Inherited from $mod");  # Test # 2
      ok2 (! DBUG_ACTIVE(), "Fish is turned OFF via FISH_OFF_FLAG."); # Test # 3
      $lvl = -1;    # Says dbug_level() is broken for this test!
   } else {
      is2 ($mod, "Fred::Fish::DBUG::ON", "Inherited from $mod");   # Test # 2
      ok2 (DBUG_ACTIVE(), "Fish is turned ON via FISH_OFF_FLAG.");    # Test # 3
      $lvl = 1;    # Says dbug_level() works for this test!
   }
   # Test # 4 ...
   $start_level = Fred::Fish::DBUG::dbug_level ();
   is2 ($start_level, $lvl, "In the BEGIN block ...");

   my $f = DBUG_FILE_NAME ();                      # Test # 5
   ok2 (1, "Fish File: $f");

   DBUG_VOID_RETURN ();
}


END {
   DBUG_ENTER_FUNC (@_);

   my $end_level = Fred::Fish::DBUG::dbug_level ();
   is2 ($end_level, $start_level, "In the END block ...");     # Test # 10

   DBUG_VOID_RETURN ();
}

# --------------------------------------
# Start of the main program!
# --------------------------------------
{
   DBUG_ENTER_FUNC (@ARGV);

   ok2 (1, "In the MAIN program ...");  # Test # 6 ...

   # -----------------------------------
   # Test # 7 & 8 ...
   # -----------------------------------
   my $msg = "Hello World!\n";
   my $ans = DBUG_PRINT ("INFO", "%s", $msg);
   is2 ($ans, $msg, "The print statement returned the formatted string!");

   $ans = DBUG_PRINT ("INFO", $msg);
   is2 ($ans, $msg, "The print statement returned the formatted string again!");

   # Test # 9 ...
   is2 (Fred::Fish::DBUG::dbug_level(), $start_level, "Level Check");

   DBUG_MODULE_LIST ();

   DBUG_LEAVE (0);
}

# -----------------------------------------------

