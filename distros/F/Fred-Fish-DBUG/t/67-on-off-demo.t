#!/user/bin/perl

# Program:  67-on-off-demo.t
# This test case makes sure using
#     Fred::Fish::DBUG::ON
# and
#     Fred::Fish::DBUG::OFF
# together in the same program doesn't break things!
# Can't push to CPAN if they don't play together!

use strict;
use warnings;

use Test::More;
use File::Spec;

use Fred::Fish::DBUG::Test;
BEGIN { push (@INC, File::Spec->catdir (".", "t", "off")); }
use helper1234;

my $start_level;

sub my_warn
{
   chomp (my $msg = shift);
   dbug_ok (0, "There was an expected warning! ${msg}");
}

my $fish_module;

BEGIN {
   # Can't use any of the constants defined by this module
   # unless we use them in a separate BEGIN block!

   $fish_module = get_fish_module ();
   my @opts = get_fish_opts ();

   # Not using use_ok() on purpose.  Just a proof of concept
   # on how a module should swap between the two versions
   # of the fish module without using use_ok()!
   # use $fish_module;
   eval "use Fred::Fish::DBUG qw / " . join (" ", @opts) . " /";
   if ( $@ ) {
      dbug_BAIL_OUT ( "Can't load ${fish_module} via Fred::Fish::DBUG qw / " .
                      join (" ", @opts) . " /" );
   }

   dbug_ok (1, "Loaded ${fish_module} using alternate method! " . join (" ", @opts));

   unless (use_ok ( "Fred::Fish::DBUG::Signal" )) {         # Test # 4
      dbug_BAIL_OUT ( "Can't load Fred::Fish::DBUG::Signal" );
  }
}

BEGIN {
   # So can detect if the module generates any unexpected warnings ...
   DBUG_TRAP_SIGNAL ( "__WARN__", DBUG_SIG_ACTION_LOG, \&my_warn );

   # -1 OFF module, 0 turn fish on, 1 turn fish off.
   my $off = ( get_fish_state () == 1 ) ? 1 : 0;
   my $lvl = ( get_fish_state () == -1 ) ? -1 : 1;

   DBUG_PUSH ( get_fish_log(), off => ${off} );

   my $module;

   # The two conflicting test modules ...
   unless ( use_ok ("on_test") ) {      # This module only uses Fred::Fish::DBUG
      dbug_BAIL_OUT ( "Can't load the 'on_test' module!" );
   }
   $module = get_fish_module (__FILE__);
   dbug_is ($fish_module, $module, "Selected correct module ($module vs $fish_module)");

   unless ( use_ok ("off_test") ) {    # This mod only uses Fred::Fish::DBUG:OFF
      dbug_BAIL_OUT ( "Can't load the 'off_test' module!" );
   }
   $module = get_fish_module (__FILE__);
   dbug_is ($fish_module, $module, "Selected correct module ($module vs $fish_module)");

   $module = get_fish_module ( ON_FILE() );
   dbug_ok ( $module =~ m/::ON$/, "Statically linked to ON --> $module");
   $module = get_fish_module ( OFF_FILE() );
   dbug_ok ( $module =~ m/::OFF$/, "Statically linked to OFF --> $module");

   DBUG_ENTER_FUNC ();

   $start_level = test_fish_level ();
   dbug_is ($start_level, $lvl, "In the BEGIN block ...");
   DBUG_PRINT ("PURPOSE", "\nDemonstrates how to swap between Fred::Fish:DBUG::ON & Fred::Fish::DBUG::OFF in your code!\n.");
   $lvl = test_fish_level ();
   dbug_is ($lvl, $start_level, "BEGIN Level Check Worked!");

   dbug_ok ( dbug_active_ok_test () );

   dbug_ok ( 1, "Fish Log: " . DBUG_FILE_NAME() );

   my %usr = find_fish_users ();
   my $cnt = keys %usr;
   dbug_cmp_ok ($cnt, '==', 4, "Found ${cnt} users of DBUG (4).");

   DBUG_VOID_RETURN ();
}


END {
   DBUG_ENTER_FUNC (@_);
   DBUG_VOID_RETURN ();
}

# --------------------------------------
# Start of the main program!
# --------------------------------------
{
   DBUG_ENTER_FUNC (@ARGV);

   dbug_ok (1, "In the MAIN program ...");

   DBUG_PRINT ("----", "%s", "="x70);
   dbug_ok (1, "Calling the ON Module ...");
   ON_PRINT1 (1, 2, 3);
   ON_PRINT2 (4, 5, 6);
   DBUG_PRINT ("----", "%s", "="x70);
   dbug_ok (1, "Calling the OFF Module ...");
   OFF_PRINT1 (1, 2, 3);
   OFF_PRINT2 (4, 5, 6);
   DBUG_PRINT ("----", "%s", "="x70);
   dbug_ok (1, "Back to normal operation ...");

   my $lvl = test_fish_level ();
   dbug_is ($lvl, $start_level, "MAIN Level Check Worked!");

   done_testing ();

   DBUG_LEAVE (0);
}

# -----------------------------------------------

