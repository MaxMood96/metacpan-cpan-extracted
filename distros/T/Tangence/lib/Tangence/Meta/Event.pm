#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2011-2024 -- leonerd@leonerd.org.uk

use v5.26;
use warnings;
use Object::Pad 0.800 ':experimental(adjust_params)';

package Tangence::Meta::Event 0.33;
class Tangence::Meta::Event :strict(params);

=head1 NAME

C<Tangence::Meta::Event> - structure representing one C<Tangence> event

=head1 DESCRIPTION

This data structure object stores information about one L<Tangence> class
event. Once constructed, such objects are immutable.

=cut

=head1 CONSTRUCTOR

=cut

=head2 new

   $event = Tangence::Meta::Event->new( %args )

Returns a new instance initialised by the given arguments.

=over 8

=item class => Tangence::Meta::Class

Reference to the containing class

=item name => STRING

Name of the event

=item arguments => ARRAY

Optional ARRAY reference containing arguments as
L<Tangence::Meta::Argument> references.

=back

=cut

field $class :param :weak :reader;
field $name  :param       :reader;
field @arguments;

ADJUST :params (
   :$arguments = undef,
) {
   @arguments = $arguments->@* if $arguments;
}

=head1 ACCESSORS

=cut

=head2 class

   $class = $event->class

Returns the class the event is a member of

=cut

=head2 name

   $name = $event->name

Returns the name of the class

=cut

=head2 arguments

   @arguments = $event->arguments

Return the arguments in a list of L<Tangence::Meta::Argument> references.

=cut

method arguments { @arguments }

=head2 argtypes

   @argtypes = $event->argtypes

Return the argument types in a list of strings.

=cut

method argtypes
{
   return map { $_->type } @arguments;
}

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>

=cut

0x55AA;
