BEGIN { $| = 1; print "1..1\n" }

use DeyeCloud::Client;

if ($DeyeCloud::Client::VERSION < 0.0001) {
   print STDERR <<EOF;

***
*** WARNING
***
*** old version of DeyeCloud::Client still installed,
*** your perl library is corrupted.
***
*** please manually uninstall older DeyeCloud::Client versions
*** or use "make install UNINST=1" to remove them.
***

EOF
}

print "ok 1\n";
