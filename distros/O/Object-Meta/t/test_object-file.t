#!/usr/bin/perl

# @author Bodo (Hugo) Barwich
# @version 2026-01-29
# @package Test for the Object::Meta::File Module
# @subpackage t/test_object-file.t

# This Module runs tests on the Object::Meta::File Module
#
#---------------------------------
# Requirements:
# - The Perl Module "Object::Meta::File" must be installed
#

use warnings;
use strict;

use Cwd         qw(abs_path);
use Digest::MD5 qw(md5_hex);

use Test::More;

BEGIN {
    use lib "lib";
    use lib "../lib";
}    #BEGIN

require_ok('Object::Meta::File');

use Object::Meta::File;

my $smodule = "";
my $spath   = abs_path($0);

( $smodule = $spath ) =~ s/.*\/([^\/]+)$/$1/;
$spath =~ s/^(.*\/)$smodule$/$1/;

my $obj     = undef;
my %objdata = ( 'name' => 'file1', 'directoryname' => 'directory1', 'field2' => 'value2', 'field3' => 'value3' );
my $objhash = md5_hex('file1');

subtest 'Constructors' => sub {

    #------------------------
    #Test: 'Constructors'

    subtest 'empty object' => sub {
        $obj = Object::Meta::File->new();

        is( ref $obj, 'Object::Meta::File', "object 'Object::Meta::File': created correctly" );

        is( $obj->getIndexField(),     'hash', "Field 'hash': is index field as expected" );
        is( $obj->getName(),           '',     "Field 'name': is empty as expected" );
        is( $obj->getDirectoryName(),  '',     "Field 'directoryname': is empty as expected" );
        is( $obj->get( 'field2', '' ), '',     "Field 'field2': does not exist as expected" );
    };
    subtest 'object from data' => sub {
        $obj = Object::Meta::File->new(%objdata);

        is( ref $obj, 'Object::Meta::File', "object 'Object::Meta::File': created correctly" );

        is( $obj->getIndexField(),    'hash',        "Field 'hash': is index field as expected" );
        is( $obj->getName(),          'file1',       "Field 'name': set correctly" );
        is( $obj->getDirectoryName(), 'directory1/', "Field 'directoryname': set correctly" );
        is( $obj->getIndexValue(),    $objhash,      "Field 'hash': has the index value" );

        foreach ( keys %objdata ) {
            if ( $_ ne 'directoryname' ) {
                is( $obj->get( $_, '' ), $objdata{$_}, "Field '$_': added correctly" );
            }
        }
    };
    subtest 'object from name' => sub {
        my $obj2hash = md5_hex('file2');

        $obj = Object::Meta::File->new( 'name' => 'file2', 'directoryname' => 'directory2' );

        is( ref $obj, 'Object::Meta::File', "object 'Object::Meta::File': created correctly" );

        is( $obj->getName(),          'file2',       "Field 'name': set correctly" );
        is( $obj->getDirectoryName(), 'directory2/', "Field 'directoryname': set correctly" );
        is( $obj->getIndexValue(),    $obj2hash,     "Field 'hash': has the index value" );
    };
};

subtest 'Set Name' => sub {

    #------------------------
    #Test: 'Set Name'

    subtest 'object set data' => sub {
        $obj = Object::Meta::File->new();

        is( ref $obj, 'Object::Meta::File', "object 'Object::Meta::File': created correctly" );

        $obj->set(%objdata);

        is( $obj->getName(),          'file1',       "Field 'name': set correctly" );
        is( $obj->getDirectoryName(), 'directory1/', "Field 'directoryname': set correctly" );
        is( $obj->getIndexValue(),    $objhash,      "Field 'hash': has the index value" );

        foreach ( keys %objdata ) {
            if ( $_ ne 'directoryname' ) {
                is( $obj->get( $_, '' ), $objdata{$_}, "Field '$_': added correctly" );
            }
        }
    };
    subtest 'object set name' => sub {
        my $obj3hash = md5_hex('file3');

        $obj = Object::Meta::File->new();

        is( ref $obj, 'Object::Meta::File', "object 'Object::Meta::File': created correctly" );

        $obj->setName('file3');
        $obj->setDirectoryName('directory3');

        is( $obj->getName(),          'file3',       "Field 'name': set correctly" );
        is( $obj->getDirectoryName(), 'directory3/', "Field 'directoryname': set correctly" );
        is( $obj->getIndexValue(),    $obj3hash,     "Field 'hash': has the index value" );
    };
};

done_testing();
