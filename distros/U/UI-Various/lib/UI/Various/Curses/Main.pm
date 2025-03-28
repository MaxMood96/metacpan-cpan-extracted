package UI::Various::Curses::Main;

# Author, Copyright and License: see end of file

=head1 NAME

UI::Various::Curses::Main - concrete implementation of L<UI::Various::Main>

=head1 SYNOPSIS

    # This module should never be used directly!
    # It is used indirectly via the following:
    use UI::Various::Main;

=head1 ABSTRACT

This module is the specific implementation of L<UI::Various::Main> for
L<Curses::UI>.  It manages and hides everything specific to L<Curses::UI>.

=head1 DESCRIPTION

The documentation of this module is only intended for developers of the
package itself.

=cut

#########################################################################

use v5.14;
use strictures;
no indirect 'fatal';
no multidimensional;
use warnings 'once';

our $VERSION = '1.00';

use Curses::UI;

use UI::Various::core;
use UI::Various::Main;
use UI::Various::Curses::base;

require Exporter;
our @ISA = qw(UI::Various::Main UI::Various::Curses::base);
our @EXPORT_OK = qw();

#########################################################################
#########################################################################

=head1 FUNCTIONS

=cut

#########################################################################

=head2 B<_init> - initialisation

    UI::Various::Curses::Main::_init($self);

=head3 example:

    $_ = UI::Various::core::ui . '::Main::_init';
    {   no strict 'refs';   &$_($self);   }

=head3 parameters:

    $self               reference to object of abstract parent class

=head3 description:

Prepare the interface to L<Curses::UI>.  (It's under L<FUNCTIONS|/FUNCTIONS>
as it's called before the object is re-blessed as
C<UI::Various::Curses::Main>.)

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _init($)
{
    debug(2, __PACKAGE__, '::_init');
    my ($self) = @_;
    ref($self) eq __PACKAGE__  or
	fatal('_1_may_only_be_called_from_itself', __PACKAGE__);

    # can't use accessors as we're not yet correctly blessed:
    $self->{_cui} = Curses::UI->new(-clear_on_exit => 1, -color_support => 1);

    # prepare all possible 216 colours:
    my $col = $self->{_cui}->color;
    local $_;
    foreach my $r (0..5)
    {
	foreach my $g (0..5)
	{
	    foreach my $b (0..5)
	    {
		$_ = (($r * 6) + $g) * 6 + $b;
		$col->define_color('C' . $_,
				   1 + int($r * 998 / 5),
				   1 + int($g * 998 / 5),
				   1 + int($b * 998 / 5));
	    }
	}
    }

    $self->{max_height} = $self->{_cui}->height;
    $self->{max_width} = $self->{_cui}->width;
    # internal flag if Curses::UI's mainloop is currently running:
    $self->{_running} = 0;
}

#########################################################################

=head1 METHODS

=cut

#########################################################################

=head2 B<mainloop> - main event loop of an application

C<Curses>'s concrete implementation of
L<UI::Various::Main::mainloop|UI::Various::Main/mainloop - main event loop
of an application>

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub mainloop($)
{
    my ($self) = @_;
    debug(1, __PACKAGE__, '::mainloop: ', $self->{_again} ? 1 : 0);
    local $_;

    $self->{_again}  and  $self->_cui->reset_curses;
    while ($_ = $self->child)
    {   $_->_prepare;   }
    $self->{_running} = 1;
    $self->{_index} = $self->children - 1;
    $self->_cui->set_binding(sub { $self->_focus(+1); }, "\cN");
    $self->_cui->set_binding(sub { $self->_focus(-1); }, "\cP");
    $self->_cui->mainloop  unless  0 == $self->children;
    delete $self->{_index};
    $self->{_running} = 0;
    $self->_cui->leave_curses;	# re-enable normal terminal
    $self->{_again} = 1;
}

#########################################################################

=head2 B<window> - add new window to application

C<Curses>'s overload of L<UI::Various::Main::window|UI::Various::Main/window
- add new window to application>.  If the C<Mainloop> of L<Curses::UI> is
running, we need to directly prepare and show the window.

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub window($@)
{
    debug(2, __PACKAGE__, '::window');
    my $self = shift;
    local $_ = $self->SUPER::window(@_);
    if ($self->{_running})
    {
	$_->_prepare;
	$self->_focus(0);
    }
    return $_;
}

#########################################################################

=head2 B<dialog> - add new dialog to application

C<Curses>'s overload of L<UI::Various::Main::dialog|UI::Various::Main/dialog
- add new dialog to application>.  If the C<Mainloop> of L<Curses::UI> is
running, we need to directly prepare and show the dialogue.

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub dialog($@)
{
    debug(2, __PACKAGE__, '::dialog');
    my $self = shift;
    local $_ = $self->SUPER::dialog(@_);
    if ($self->{_running})
    {
	$_->_prepare;
	$_->_cui->modalfocus();
	# If Curses is already running we're stuck here until destruction of
	# the dialogue!  Afterwards we update all references and redraw
	# everything:
	$self->_update_all_references;
	$self->_cui->draw;
	$_ = undef;
    }
    return $_;
}

#########################################################################

=head2 B<_focus> - change focus to other top-level UI element

    $self->_focus($index);

=head3 parameters:

    $self               reference to object
    $index              -1/0/+1 index to select other top-level UI element

=head3 description:

Change the focus to previous (C<-1>), next (C<+1>) or newest (C<0>)
(probably) other top-level UI element.

=cut

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub _focus($$)
{
    my ($self, $index) = @_;
    local $_ = $self->children - 1; # maximum index

    if ($index == 1)
    {   $self->{_index} += 1;   }
    elsif ($index == -1)
    {   $self->{_index} -= 1;   }
    else
    {   $self->{_index} = $_;   }

    if ($self->{_index} > $_)
    {   $self->{_index} = 0;   }
    elsif ($self->{_index} < 0)
    {   $self->{_index} = $_;   }

    $self->child($self->{_index})->_cui->focus;
}

1;

#########################################################################
#########################################################################

=head1 SEE ALSO

L<UI::Various>, L<UI::Various::Main>

=head1 LICENSE

Copyright (C) Thomas Dorner.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  See LICENSE file for more details.

=head1 AUTHOR

Thomas Dorner E<lt>dorner (at) cpan (dot) orgE<gt>

=cut
