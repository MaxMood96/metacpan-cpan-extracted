#!perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}


use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Perl::Critic::Subset 3.001.006

use Test::Perl::Critic (-profile => "") x!! -e "";

my $filenames = ['lib/Data/Sah/Filter/perl/Unix/check_gid_exists.pm','lib/Data/Sah/Filter/perl/Unix/check_uid_exists.pm','lib/Data/Sah/Filter/perl/Unix/check_unix_group_exists.pm','lib/Data/Sah/Filter/perl/Unix/check_unix_user_exists.pm','lib/Data/Sah/Filter/perl/Unix/convert_gid_to_unix_group.pm','lib/Data/Sah/Filter/perl/Unix/convert_uid_to_unix_user.pm','lib/Data/Sah/Filter/perl/Unix/convert_unix_group_to_gid.pm','lib/Data/Sah/Filter/perl/Unix/convert_unix_user_to_uid.pm','lib/Data/Sah/Filter/perl/Unix/try_convert_gid_to_unix_group.pm','lib/Data/Sah/Filter/perl/Unix/try_convert_uid_to_unix_user.pm','lib/Data/Sah/Filter/perl/Unix/try_convert_unix_group_to_gid.pm','lib/Data/Sah/Filter/perl/Unix/try_convert_unix_user_to_uid.pm','lib/Perinci/Sub/XCompletion/unix_gid.pm','lib/Perinci/Sub/XCompletion/unix_group.pm','lib/Perinci/Sub/XCompletion/unix_group_or_gid.pm','lib/Perinci/Sub/XCompletion/unix_uid.pm','lib/Perinci/Sub/XCompletion/unix_user.pm','lib/Perinci/Sub/XCompletion/unix_user_or_uid.pm','lib/Sah/Schema/unix/dirname.pm','lib/Sah/Schema/unix/filename.pm','lib/Sah/Schema/unix/gid.pm','lib/Sah/Schema/unix/gid/exists.pm','lib/Sah/Schema/unix/groupname.pm','lib/Sah/Schema/unix/groupname/exists.pm','lib/Sah/Schema/unix/pathname.pm','lib/Sah/Schema/unix/pid.pm','lib/Sah/Schema/unix/signal.pm','lib/Sah/Schema/unix/uid.pm','lib/Sah/Schema/unix/uid/exists.pm','lib/Sah/Schema/unix/username.pm','lib/Sah/Schema/unix/username/exists.pm','lib/Sah/SchemaBundle/Unix.pm','lib/Sah/SchemaR/unix/dirname.pm','lib/Sah/SchemaR/unix/filename.pm','lib/Sah/SchemaR/unix/gid.pm','lib/Sah/SchemaR/unix/gid/exists.pm','lib/Sah/SchemaR/unix/groupname.pm','lib/Sah/SchemaR/unix/groupname/exists.pm','lib/Sah/SchemaR/unix/pathname.pm','lib/Sah/SchemaR/unix/pid.pm','lib/Sah/SchemaR/unix/signal.pm','lib/Sah/SchemaR/unix/uid.pm','lib/Sah/SchemaR/unix/uid/exists.pm','lib/Sah/SchemaR/unix/username.pm','lib/Sah/SchemaR/unix/username/exists.pm'];
unless ($filenames && @$filenames) {
    $filenames = -d "blib" ? ["blib"] : ["lib"];
}

all_critic_ok(@$filenames);
