#!/usr/bin/perl

use v5.26;
use warnings;

use Test2::V0;

use Tickit::Test;

use Tickit::Widget::Scroller;
use Tickit::Widget::Scroller::Item::Text;

my ( $term, $rootwin ) = mk_term_and_window;
my $win = $rootwin->make_sub( 0, 0, 5, 40 );

my $scroller = Tickit::Widget::Scroller->new(
   gravity => "bottom",
);

$scroller->push( Tickit::Widget::Scroller::Item::Text->new( "A line of content at line $_" ) ) for 1 .. 10;

$scroller->set_window( $win );

$scroller->scroll( +3 );

flush_tickit;

is_display( [ "A line of content at line 4",
              "A line of content at line 5",
              "A line of content at line 6",
              "A line of content at line 7",
              "A line of content at line 8", ],
            'Display initially' );

$term->clear;
$win->resize( 7, 40 );

flush_tickit;

is_display( [ "A line of content at line 2",
              "A line of content at line 3",
              "A line of content at line 4",
              "A line of content at line 5",
              "A line of content at line 6",
              "A line of content at line 7",
              "A line of content at line 8", ],
            'Display after resize more lines' );

$term->clear;
$win->resize( 5, 40 );

flush_tickit;

is_display( [ "A line of content at line 4",
              "A line of content at line 5",
              "A line of content at line 6",
              "A line of content at line 7",
              "A line of content at line 8", ],
            'Display after resize fewer lines' );

$term->clear;
$win->resize( 5, 20 );

flush_tickit;

is_display( [ "line 6",
              "A line of content at",
              "line 7",
              "A line of content at",
              "line 8", ],
            'Display after resize fewer columns' );

$term->clear;
$win->resize( 15, 40 );

flush_tickit;

is_display( [ "A line of content at line 1",
              "A line of content at line 2",
              "A line of content at line 3",
              "A line of content at line 4",
              "A line of content at line 5",
              "A line of content at line 6",
              "A line of content at line 7",
              "A line of content at line 8",
              "A line of content at line 9",
              "A line of content at line 10" ],
            'Display after resize too big' );

$term->clear;
$win->resize( 5, 40 );

flush_tickit;

is_display( [ "A line of content at line 6",
              "A line of content at line 7",
              "A line of content at line 8",
              "A line of content at line 9",
              "A line of content at line 10" ],
            'Display after shrink from resize too big' );

done_testing;
