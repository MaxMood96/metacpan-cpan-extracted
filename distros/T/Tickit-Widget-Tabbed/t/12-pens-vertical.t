#!/usr/bin/perl

use v5.26;
use warnings;

use Test::More;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::Tabbed;

my $win = mk_window;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "left" );

$widget->add_tab( Tickit::Widget::Static->new( text => "Widget" ), label => "tab" );
my $tab = $widget->add_tab( Tickit::Widget::Static->new( text => "Widget 2" ), label => "othertab" );

is( $widget->lines,  2, '$widget->lines' ); # 2 tabs
is( $widget->cols,  18, '$widget->cols' );  # 8 + 2 + 8

$widget->set_window( $win );

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>4), TEXT(" >>>>>>",fg=>7,bg=>4), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>4)] ],
            'Display initially' );

$widget->set_style(ribbon_bg => 2);

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>2)] ],
            'Display after pen_tabs ->chattr' );

$widget->set_style(active_b => 1);

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2,b=>1), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab  ",fg=>7,bg=>2)] ],
            'Display after pen_active ->chattr' );

$tab->set_pen( Tickit::Pen->new( fg => 1 ) );

flush_tickit;

is_display( [ [TEXT("tab",fg=>14,bg=>2,b=>1), TEXT(" >>>>>>",fg=>7,bg=>2), TEXT("Widget")],
              [TEXT("othertab",fg=>1,bg=>2), TEXT("  ",fg=>7,bg=>2)] ],
            'Display after tab set_pen' );

done_testing;
