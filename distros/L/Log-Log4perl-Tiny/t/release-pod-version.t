
BEGIN {
  unless ($ENV{RELEASE_TESTING}) {
    print qq{1..0 # SKIP these tests are for release candidate testing\n};
    exit
  }
}

use strict;
use Test::More tests => 1;
use Log::Log4perl::Tiny;

(my $filename = $INC{'Log/Log4perl/Tiny.pm'}) =~ s{pm$}{pod};

my $pod_version;

{
   open my $fh, '<', $filename
     or BAIL_OUT "can't open '$filename'";
   binmode $fh, ':raw';
   local $/;
   my $module_text = <$fh>;
   ($pod_version) = $module_text =~ m{
      ^This\ document\ describes\ Log::Log4perl::Tiny\ version\ (.*?)\.$
   }mxs;
}

is $pod_version, $Log::Log4perl::Tiny::VERSION, 'version in POD';
