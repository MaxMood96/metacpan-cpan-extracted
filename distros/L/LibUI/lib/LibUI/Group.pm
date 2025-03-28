package LibUI::Group 0.02 {
    use 5.008001;
    use strict;
    use warnings;
    use Affix;
    use parent 'LibUI::Control';
    #
    affix( LibUI::lib(), [ 'uiGroupMargined', 'margined' ],
        [ InstanceOf ['LibUI::Group'] ] => Int );
    affix(
        LibUI::lib(),
        [ 'uiGroupSetChild',           'setChild' ],
        [ InstanceOf ['LibUI::Group'], InstanceOf ['LibUI::Control'] ] => Void
    );
    affix(
        LibUI::lib(),
        [ 'uiGroupSetMargined',        'setMargined' ],
        [ InstanceOf ['LibUI::Group'], Int ] => Void
    );
    affix(
        LibUI::lib(),
        [ 'uiGroupSetTitle',           'setTitle' ],
        [ InstanceOf ['LibUI::Group'], Str ] => Void
    );
    affix( LibUI::lib(), [ 'uiGroupTitle', 'title' ], [ InstanceOf ['LibUI::Group'] ] => Str );
    affix( LibUI::lib(), [ 'uiNewGroup', 'new' ], [ Void, Str ] => InstanceOf ['LibUI::Group'] );
};
1;
#
__END__

=pod

=encoding utf-8

=head1 NAME

LibUI::Group - Control Container that Adds a Label to the Contained Child
Control

=head1 SYNOPSIS

    use LibUI ':all';
    use LibUI::Group;
    use LibUI::HBox;
    use LibUI::Window;
    use LibUI::ColorButton;
    use LibUI::Label;
    Init && die;
    my $window = LibUI::Window->new( 'Hi', 320, 100, 0 );
    $window->setMargined( 1 );
    my $group  = LibUI::Group->new('Color Pickers');
    my $box    = LibUI::HBox->new;
    my $cbtn_l = LibUI::ColorButton->new();
    my $cbtn_r = LibUI::ColorButton->new();
    sub colorChanged {
        warn sprintf '#%02X%02X%02X%02X', map { $_ * 255 } shift->color();
    }
    $cbtn_l->onChanged( \&colorChanged, $cbtn_l );
    $cbtn_r->onChanged( \&colorChanged, $cbtn_r );
    $box->append( $_, 1 ) for $cbtn_l, $cbtn_r;
    $group->setChild($box);
    $window->setChild($group);
    $window->onClosing(
        sub {
            Quit();
            return 1;
        },
        undef
    );
    $window->show;
    Main();

=head1 DESCRIPTION

A LibUI::Group object represents a control container that adds a label to the
contained child control.

This control is a great way of grouping related controls in combination with
L<LibUI::HBox> and L<LibUI::VBox>.

A visual box will or will not be drawn around the child control dependent on
the underlying OS implementation.

=head1 Functions

Not a lot here but... well, it's just a tab box.

=head2 C<new( ... )>

    my $grp = LibUI::Group->new( 'Login' );

Creates a new LibUI::Group.

=head2 C<margined( )>

    if( $grp->margined( ) ) {
        ...;
    }

Returns whether or not the group has a margin.

=head2 C<setMargined( ... )>

    $grp->setMargined( 1 );

Sets whether or not the group has a margin.

The margin size is determined by the OS defaults.

Expected parameters include:

=over

=item C<$margin> - boolean value

=back

=head2 C<setChild( ... )>

    $grp->append( $box );

Sets the group's child.

Expected parameters include:

=over

=item C<$child> - LibUI::Control instance

=back

=head2 C<delete( ... )>

    $grp->delete( $index );

Removes the control at C<$index>.

Note: The control is neither destroyed nor freed.

=head2 C<title( )>

    my $text = $grp->title( );

Returns the group title.

=head2 C<setTitle( ... )>

    $grp->setTitle( $text . '*' );

Sets the group title.

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=cut

