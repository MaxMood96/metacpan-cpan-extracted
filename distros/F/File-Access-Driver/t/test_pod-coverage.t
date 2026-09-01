#!/usr/bin/perl

# @author Bodo (Hugo) Barwich
# @version 2026-01-29
# @package Test for the POD Coverage
# @subpackage t/test_pod-coverage.t

# This Module checks the POD Coverage for all modules in the project
#
#---------------------------------
# Requirements:
# - The Perl Module "Pod::Coverage" must be installed
#

use warnings;
use strict;

use Cwd qw(abs_path);
use File::Find;

use Test::More;
use Test::Pod;
use Pod::Coverage;

BEGIN {
    use lib "lib";
    use lib "../lib";
}    #BEGIN

my $smodule = "";
my $spath   = abs_path($0);

( $smodule = $spath ) =~ s/.*\/([^\/]+)$/$1/;
$spath =~ s/^(.*\/)$smodule$/$1/;

my @modules_found = ();
my $module_name   = undef;

sub module_files {
    if ( -f $_ && $File::Find::name =~ qr/(.+).pm$/i ) {
        $module_name = $1;
        $module_name =~ s#^lib/##;
        $module_name =~ s#/#::#g;

        push @modules_found, ($module_name);
    }
}

# Find all Perl Modules
find( { wanted => \&module_files, follow => 0 }, 'lib' );

print "# Found Modules:\n", join( "\n", @modules_found ), "\n";

# The known modules in the project
my %modules_expected = (
    'File::Access::Driver' => {
        package            => 'File::Access::Driver',
        file               => 'lib/File/Access/Driver.pm',
        expected_coverage  => 0.44,
        expected_uncovered => {
            setContentArray  => 0,
            appendLine       => 0,
            writeLine        => 0,
            writeContent     => 0,
            getReportString  => 0,
            getErrorString   => 0,
            getErrorCode     => 0,
            setContent       => 0,
            getContent       => 0,
            getContentArray  => 0,
            readContent      => 0,
            readContentArray => 0,
            isBuffered       => 0,
            isPersistent     => 0,
            getFileSize      => 0,
            setFileTime      => 0,
            getFileTime      => 0,
            Write            => 0,
            Read             => 0,
            changeFileName   => 0
        }
    },
);

subtest 'Module POD Coverage' => sub {
    for $module_name (@modules_found) {

        subtest "Module '$module_name'" => sub {
            pod_file_ok( $modules_expected{$module_name}{file}, "Module '$module_name': POD is valid" );

            isnt( $modules_expected{$module_name}, undef, "Module '$module_name': Coverage as expected" );

            # Check the POD Coverage
            my $coverage = Pod::Coverage->new( %{ $modules_expected{$module_name} } );

            is(
                sprintf( '%.2f', $coverage->coverage() ),
                sprintf( '%.2f', $modules_expected{$module_name}{expected_coverage} ),
                "Module '$module_name': Coverage '$modules_expected{$module_name}{expected_coverage}' as expected"
            );

            my @methods_uncovered = $coverage->uncovered();

            for my $method (@methods_uncovered) {
                isnt( $modules_expected{$module_name}{expected_uncovered}{$method},
                    undef, "Method '$module_name :: $method ()' is uncovered as expected" );
            }
        };

    }
};

done_testing();
