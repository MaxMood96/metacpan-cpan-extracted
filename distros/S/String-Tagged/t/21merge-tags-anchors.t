#!/usr/bin/perl

use v5.14;
use warnings;

use Test2::V0;

use String::Tagged;

my $str = String::Tagged->new( "Hello, world" );

$str->apply_tag( -1,  6, message => 1 );
$str->apply_tag(  6, -1, message => 1 );

my @tags;

$str->merge_tags( sub { $_[1] == $_[2] } );

undef @tags;
$str->iter_tags( sub { push @tags, [ @_ ] } );
is( \@tags, 
           [
              [ 0, 12, message => 1 ],
           ],
           'tags list after merge' );

$str->insert( 0, "<<" );

undef @tags;
$str->iter_tags( sub { push @tags, [ @_ ] } );
is( \@tags, 
           [
              [ 0, 14, message => 1 ],
           ],
           'tags list after prepend' );

$str->append( ">>" );

undef @tags;
$str->iter_tags( sub { push @tags, [ @_ ] } );
is( \@tags, 
           [
              [ 0, 16, message => 1 ],
           ],
           'tags list after append' );

done_testing;
