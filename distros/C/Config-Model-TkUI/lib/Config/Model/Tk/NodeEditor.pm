#
# This file is part of Config-Model-TkUI
#
# This software is Copyright (c) 2008-2021 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Tk::NodeEditor 1.379;

use strict;
use warnings;
use Carp;

use Tk::Pane;
use Tk::Balloon;
use Text::Wrap;
use Config::Model::Tk::NoteEditor;

use base qw/Config::Model::Tk::NodeViewer/;
use subs qw/menu_struct/;

Construct Tk::Widget 'ConfigModelNodeEditor';

my @fbe1 = qw/-fill both -expand 1/;
my @fxe1 = qw/-fill x    -expand 1/;
my @fx   = qw/-fill x    -expand 0/;

my $logger = Log::Log4perl::get_logger("Tk::NodeEditor");

sub ClassInit {
    my ( $cw, $args ) = @_;

    # ClassInit is often used to define bindings and/or other
    # resources shared by all instances, e.g., images.

    # cw->Advertise(name=>$widget);
}

sub Populate {
    my ( $cw, $args ) = @_;
    my $node = $cw->{node} = delete $args->{-item}
        || die "NodeViewer: no -item, got ", keys %$args;
    $cw->{path} = delete $args->{-path};
    $cw->{store_cb} = delete $args->{-store_cb} || die __PACKAGE__, "no -store_cb";
    my $cme_font = $cw->{my_font} = delete $args->{-font};

    $cw->add_header( Edit => $node )->pack(@fx);

    $cw->Label( -text => $node->composite_name . ' node elements' )->pack();

    $cw->{pane} = $cw->Scrolled(qw/Pane -scrollbars osow -sticky senw/);
    $cw->{pane}->pack(@fbe1);

    $cw->fill_pane;

    # insert a widget for "accepted" elements
    my @rexp = $node->accept_regexp;
    if (@rexp) {
        $cw->add_accept_entry(@rexp);
    }

    # add adjuster
    #require Tk::Adjuster;
    #$cw -> Adjuster()->pack(-fill => 'x' , -side => 'top') ;

    $cw->ConfigModelNoteEditor( -object => $node )->pack;
    $cw->add_info_button()->pack( @fxe1, qw/-anchor n/ );

    if ( $node->parent ) {
        $cw->add_summary($node)->pack(@fx);
        $cw->add_description($node)->pack(@fbe1);
    }
    else {
        $cw->add_help( class => $node->get_help )->pack(@fx);
    }

    $cw->ConfigSpecs(-font => [['SELF','DESCENDANTS'], 'font','Font', $cme_font ],);

    # don't call directly SUPER::Populate as it's NodeViewer's populate
    $cw->Tk::Frame::Populate($args);

    # TODO: above is a hack. The required methods of NodeViewer and
    # AnyViewer should be moved into a role. Question: how can roles
    # be done with Tk ??
}

sub reload {
    goto &fill_pane;
}

sub fill_pane {
    my $cw = shift;

    my $node     = $cw->{node};
    my $elt_pane = $cw->{pane};

    my %is_elt_drawn = map { ( $_ => 1 ) } keys %{ $cw->{elt_widgets} || {} };

    my $prev_elt;
    my $font = $cw->{my_font}; #cget('-font');

    foreach my $c ( $node->get_element_name() ) {
        if ( delete $is_elt_drawn{$c} ) {
            $prev_elt = $c;
            next;
        }

        my $type     = $node->element_type($c);
        my $elt_path = $cw->{path} . '.' . $c;

        my @after = defined $prev_elt ? ( -after => $cw->{elt_widgets}{$prev_elt} ) : ();
        $prev_elt = $c;
        my $f = $elt_pane->Frame( -relief => 'groove', -borderwidth => 1 );
        $f->pack( -side => 'top', @fx, @after );

        $cw->{elt_widgets}{$c} = $f;
        my $label = $f->Label( -text => $c, -font => $font, -width => 22, -anchor => 'w' );
        $label->pack(qw/-side left -fill x -anchor w/);

        my $help = $node->get_help_as_text( summary => $c ) || $node->get_help_as_text( description => $c );
        $cw->Balloon( -state => 'balloon' )->attach( $label, -msg => wrap( '', '', $help ) );

        if ( $type eq 'leaf' ) {
            my $leaf      = $node->fetch_element($c);
            my $v         = $node->fetch_element_value( name => $c, check => 'no' );
            my $store_sub = sub {
                $leaf->store($v);
                $cw->{store_cb}->($elt_path);
                $cw->fill_pane;
            };
            my $v_type = $leaf->value_type;

            if ( $v_type =~ /integer|number|uniline/ ) {
                my $e = $f->Entry( -textvariable => \$v )->pack( qw/-side left -anchor w/, @fxe1 );
                $e->bind( "<Return>"   => $store_sub );
                $e->bind( "<FocusOut>" => $store_sub );
                next;
            }

            if ( $v_type =~ /boolean/ ) {
                my $e = $f->Checkbutton( -variable => \$v, -font => $font, -command => $store_sub )
                    ->pack(qw/-side left -anchor w/);
                next;
            }

            if ( $v_type =~ /enum|reference/ ) {
                my @choices = $leaf->get_choice;
                require Tk::BrowseEntry;
                my $e = $f->BrowseEntry(
                    -variable  => \$v,
                    -font => $font,
                    -browsecmd => $store_sub,
                    -choices   => \@choices
                )->pack( qw/-side left -anchor w/, @fxe1 );
                next;
            }
        }

        # add button to launch dedicated editor
        my $obj      = $node->fetch_element($c);
        my $edit_sub = sub {
            # it would be better for tkui ui to pass this as a callback
            # note that storing tkui object in a sub widget creates issues with tk
            $cw->parent->parent->parent->parent->create_element_widget( 'edit', $elt_path, $obj );
        };
        my $edb = $f->Button(
            -text    => '...',
            -font => $font,
            -command => $edit_sub
        );
        $edb->pack( -anchor => 'w' );

        my $content =
              $type eq 'leaf' ? $obj->fetch( check => 'no' ) || ''
            : $type eq 'node' ? $node->config_class_name
            :                   $type;
        $cw->Balloon( -state => 'balloon' )->attach( $edb, -msg => wrap( '', '', $content ) );
    }

    # destroy leftover widgets (may occur with warp mechanism)
    foreach my $widget ( keys %is_elt_drawn) {
        my $w = delete $cw->{elt_widgets}{$widget};
        $w->destroy;
    }
}

sub add_accept_entry {
    my ( $cw, @rexp ) = @_;

    my $node = $cw->{node};
    my $f = $cw->Frame( -relief => 'groove', -borderwidth => 1 );
    $f->pack( -side => 'top', @fx );

    my $font = $cw->{my_font}; #cget('-font');

    my $accepted = '';
    my $accept_label = $f->Label(
        -text => 'accept : /' . join( '/, /', @rexp ) . '/',
        -font => $font
    );
    $cw->Balloon(-state => 'balloon')->attach(
        $accept_label,
        -msg => qq!Add a parameter not yet known by the model and hit <Return>.\n!
        . qq!This parameter must satisfy the Perl regexp shown after "accept:".!
    );
    $accept_label->pack;

    my $e = $f->Entry( -textvariable => \$accepted, -font => $font)->pack( qw/-side left -anchor w/, @fxe1 );
    my $sub = sub {
        return unless $accepted;
        my $ok = 0;
        map { $ok++ if $accepted =~ /^$_$/ } @rexp;
        if ( not $ok ) {
            die "Cannot accept $accepted, it does not match any accepted regexp\n";
        }
        $node->fetch_element($accepted);
        $cw->{store_cb}->();
        $cw->fill_pane;
        $cw->{pane}->yview( moveto => 1 );
    };

    $e->bind( "<Return>" => $sub );
}

1;
