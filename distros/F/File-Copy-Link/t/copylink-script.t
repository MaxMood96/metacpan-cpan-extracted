#!perl
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl copylink.t'

use strict;
use warnings;

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;

BEGIN {
    require './t/can_symlink.pl';
    if ( !can_symlink() ) {
        plan skip_all => skip_symlink_message();
    }
    plan tests => 6;
    require './blib/script/copylink';
}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use File::Compare;
use File::Temp qw(tempdir);
use File::Spec;

my $dir = tempdir;

my $file = File::Spec->catfile( $dir, 'file.txt' );
my $link = File::Spec->catfile( $dir, 'link.lnk' );

open my $fh, q{>}, $file or die;
print {$fh} "text\n" or die;
close $fh            or die;

die $! if not( symlink 'file.txt', $link );
die    if not( -l $link );
die    if compare( $file, $link );

open $fh, q{>>}, $file or die;
print {$fh} "more\n"        or die;
close $fh                   or die;
not compare( $file, $link ) or die;

my $warn;
my $main;
{
    local $SIG{__WARN__} = sub { $warn .= $_[0]; };
    local @ARGV = ($link);
    $main = eval { main(); 1; };
}

ok( $main,  q{copylink script} );
ok( !$warn, q{copylink script - no warnings} ); 
ok( !( -l $link ),            q{not a link} );
ok( !compare( $file, $link ), q{compare file and copy} );

open $fh, q{>>}, $file or die;
print {$fh} qq{more\n} or die;
close $fh              or die;

compare( $file, $link ) or die;
unlink $file            or die;

ok( -e $link, q{copy not deleted} );
unlink $link or die;
ok( !( -e $link ), q{copy deleted} );

# $Id$
