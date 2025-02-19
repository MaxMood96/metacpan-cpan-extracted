#!/usr/bin/perl

use v5.26;
use warnings;

use Test::More;

use Tickit::Test;

use Tickit::Widget::Static;
use Tickit::Widget::VBox;
use Tickit::Widget::Tabbed;

my $win = mk_window;

my $widget = Tickit::Widget::Tabbed->new( tab_position => "top" );

my $tab = $widget->add_tab( my $vbox = Tickit::Widget::VBox->new, label => "tab" );

$widget->set_window( $win );

flush_tickit;

is_display( [ [TEXT("[",fg=>7,bg=>4), TEXT("tab",fg=>14,bg=>4), TEXT("]",fg=>7,bg=>4), TEXT("",bg=>4)],
              [TEXT("")] ],
            'Display initially' );

$vbox->add( Tickit::Widget::Static->new( text => "Static" ) );

flush_tickit;

is_display( [ [TEXT("[",fg=>7,bg=>4), TEXT("tab",fg=>14,bg=>4), TEXT("]",fg=>7,bg=>4), TEXT("",bg=>4)],
              [TEXT("Static")] ],
            'Display after $vbox->add' );

$vbox->add( Tickit::Widget::Static->new( text => "More static" ) );

flush_tickit;

is_display( [ [TEXT("[",fg=>7,bg=>4), TEXT("tab",fg=>14,bg=>4), TEXT("]",fg=>7,bg=>4), TEXT("",bg=>4)],
              [TEXT("Static")],
              [TEXT("More static")] ],
            'Display after $vbox->add again' );

done_testing;
