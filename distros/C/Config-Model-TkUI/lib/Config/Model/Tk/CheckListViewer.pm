#
# This file is part of Config-Model-TkUI
#
# This software is Copyright (c) 2008-2021 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Tk::CheckListViewer 1.379;

use strict;
use warnings;
use Carp;

use base qw/Tk::Frame Config::Model::Tk::AnyViewer/;
use subs qw/menu_struct/;
use Tk::ROText;

Construct Tk::Widget 'ConfigModelCheckListViewer';

my @fbe1 = qw/-fill both -expand 1/;
my @fxe1 = qw/-fill x    -expand 1/;
my @fx   = qw/-fill x/;

sub ClassInit {
    my ( $cw, $args ) = @_;

    # ClassInit is often used to define bindings and/or other
    # resources shared by all instances, e.g., images.

    # cw->Advertise(name=>$widget);
}

sub Populate {
    my ( $cw, $args ) = @_;
    my $leaf = $cw->{leaf} = delete $args->{-item}
        || die "CheckListViewer: no -item, got ", keys %$args;
    my $path = delete $args->{-path}
        || die "CheckListViewer: no -path, got ", keys %$args;
    my $cme_font = delete $args->{-font};

    my $inst = $leaf->instance;

    $cw->add_header( View => $leaf )->pack(@fx);

    my $rt = $cw->Scrolled(
        'ROText',
        -scrollbars => 'osoe',
        -height     => 6,
    )->pack(@fbe1);
    $rt->tagConfigure( 'in', -background => 'black', -foreground => 'white' );

    my %h = $leaf->get_checked_list_as_hash;
    foreach my $c ( $leaf->get_choice ) {
        my $tag = $h{$c} ? 'in' : 'out';
        $rt->insert( 'end', $c . "\n", $tag );
    }

    $cw->add_annotation($leaf)->pack(@fx);
    $cw->add_summary($leaf)->pack(@fx);

    my ( $help_frame, $help_widget ) = $cw->add_help( value => '', 1 );
    $help_frame->pack(@fx);
    $cw->{value_help_widget} = $help_widget;
    $cw->set_value_help( $leaf->get_checked_list );

    $cw->add_description($leaf)->pack(@fbe1);

    $cw->add_info_button()->pack( @fxe1, -side => 'left' );
    $cw->add_editor_button($path)->pack( @fxe1, -side => 'right' );

    $cw->ConfigSpecs(
        -font => [['SELF','DESCENDANTS'], 'font','Font', $cme_font ],

        #-fill   => [ qw/SELF fill Fill both/],
        #-expand => [ qw/SELF expand Expand 1/],
        -relief      => [qw/SELF relief Relief groove/],
        -borderwidth => [qw/SELF borderwidth Borderwidth 2/],
        DEFAULT      => [qw/SELF/],
    );

    $cw->SUPER::Populate($args);
}

sub add_value_help {
    my $cw = shift;

    my $help_frame = $cw->Frame(
        -relief      => 'groove',
        -borderwidth => 2,
    )->pack(@fbe1);
    my $leaf = $cw->{leaf};
    $help_frame->Label( -text => 'value help: ' )->pack( -side => 'left' );
    $help_frame->Label( -textvariable => \$cw->{help} )
        ->pack( -side => 'left', -fill => 'x', -expand => 1 );
}

sub set_value_help {
    my $cw  = shift;
    my @set = @_;

    my @help = grep {defined $_ } map { $cw->{leaf}->get_help($_) } @set ;

    $cw->update_help($cw->{value_help_widget}, join("\n\n", @help));
}

sub cme_object {
    my $cw = shift;
    return $cw->{leaf};
}

1;
