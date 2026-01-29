#!/usr/bin/perl

# @author Bodo (Hugo) Barwich
# @version 2026-01-29
# @package Test for the Object::Meta::File::List Module
# @subpackage test_object.t

# This Module runs tests on the Object::Meta::File::List Module
#
#---------------------------------
# Requirements:
# - The Perl Module "Object::Meta::File::List" must be installed
#

use warnings;
use strict;

use Cwd qw(abs_path);

use Test::More;

BEGIN {
    use lib "lib";
    use lib "../lib";
}    #BEGIN

require_ok('Object::Meta::File::List');

use Object::Meta::File::List;
use Object::Meta::File;

my $smodule = "";
my $spath   = abs_path($0);

( $smodule = $spath ) =~ s/.*\/([^\/]+)$/$1/;
$spath =~ s/^(.*\/)$smodule$/$1/;

my $list     = undef;
my $obj      = undef;
my %obj1data = ( 'name'    => 'file1', 'directoryname' => 'directory1', 'field2' => 'value2', 'field3' => 'value3' );
my %obj2data = ( 'name'    => 'file2', 'directoryname' => 'directory4', 'field2' => 'value5', 'field3' => 'value6' );
my %obj3data = ( 'name'    => 'file3', 'directoryname' => 'directory7', 'field2' => 'value8', 'field3' => 'value9' );
my %obj1meta = ( 'updated' => 'new' );
my %obj2meta = ( 'updated' => 'new' );
my %obj3meta = ( 'updated' => 'updated' );

subtest 'Constructor' => sub {

    #------------------------
    #Test: 'Constructor'

    subtest 'empty list' => sub {
        $list = Object::Meta::File::List->new();

        is( ref $list, 'Object::Meta::File::List', "List 'Object::Meta::File::List': created correctly" );

        is( $list->getIndexField(),      'hash', "Index Field 'hash' as expected" );
        is( $list->getMetaObjectCount(), 0,      "List is empty as expected" );
        is( $list->getMetaObject(0),     undef,  "Object with Index '0': does not exist as expected" );
    };
};

subtest 'Name Index' => sub {

    #------------------------
    #Test: 'Indices'

    subtest 'name index with fix value' => sub {
        $list = Object::Meta::File::List->new();

        is( ref $list, 'Object::Meta::File::List', "List 'Object::Meta::File::List': created correctly" );

        is( $list->getMetaObjectCount(), 0,     "List is empty as expected" );
        is( $list->getMetaObject(0),     undef, "Object with Index '0': does not exist as expected" );

        # Create an Index dirrectly with the createIndex() method
        $list->createIndex( 'indexname' => 'new', 'checkfield' => 'updated', 'checkvalue' => 'new', 'meta' => 1 );

        # Primary Index was created automatically
        is( $list->getIndexField(), 'hash', "Index Field 'hash' as expected" );

        $obj = Object::Meta::File->new(%obj1data);

        $obj->setMeta(%obj1meta);

        $list->Add($obj);

        $obj = Object::Meta::File->new(%obj2data);

        $obj->setMeta(%obj2meta);

        $list->Add($obj);

        $obj = Object::Meta::File->new(%obj3data);

        $obj->setMeta(%obj3meta);

        $list->Add($obj);

        is( $list->getIdxMetaObjectCount(),      3, "Indexed Objects: Count '3'" );
        is( $list->getIdxMetaObjectCount('new'), 2, "Objects with Meta Field 'new': Count '2'" );

        # Find instance by its 'name' field
        $obj = $list->getMetaObjectbyName('file2');

        is( $obj->getName(),          'file2',       "Name Indexed: Instance 'file2' returned" );
        is( $obj->getDirectoryName(), 'directory4/', "Name Indexed: Field 'directoryname' set correctly" );
    };
};

done_testing();
