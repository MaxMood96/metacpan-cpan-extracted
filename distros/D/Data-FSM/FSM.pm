package Data::FSM;

use strict;
use warnings;

use Data::FSM::Utils qw(check_transition_objects);
use Mo qw(build default is);
use Mo::utils::Array qw(check_array_object);
use Mo::utils::Number qw(check_positive_natural);

our $VERSION = 0.01;

has id => (
	is => 'ro',
);

has states => (
	default => [],
	is => 'ro',
);

has transitions => (
	default => [],
	is => 'ro',
);

sub BUILD {
	my $self = shift;

	# Check 'id'.
	check_positive_natural($self, 'id');

	# Check 'states'.
	check_array_object($self, 'states', 'Data::FSM::State');

	# Check 'transitions'.
	check_array_object($self, 'transitions', 'Data::FSM::Transition');
	check_transition_objects($self, 'transitions', $self->states);

	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Data::FSM - Data object for Finite State Machine.

=head1 SYNOPSIS

 use Data::FSM;

 my $obj = Data::FSM->new(%params);
 my $id = $obj->id;
 my $states_ar = $obj->states;
 my $transitions_ar = $obj->transitions;

=head1 METHODS

=head2 C<new>

 my $obj = Data::FSM->new(%params);

Constructor.

=over 8

=item * C<id>

FSM id.

It's optional.

Default value is undef.

=item * C<states>

Reference to array with L<Data::FSM::State> instances.

Default value is [].

=item * C<transitions>

Reference to array with L<Data::FSM::Transition> instances.
The used states in transition must be a in C<states> values.

Default value is [].

=back

Returns instance of object.

=head2 C<id>

 my $id = $obj->id;

Get FSM id.

Returns number.

=head2 C<states>

 my $states_ar = $obj->states;

Get list of FSM states.

Returns reference to array with L<Data::FSM::State> instances.

=head2 C<transition>

 my $transitions_ar = $obj->transitions;

Get list of FSM transitions.

Returns reference to array with L<Data::FSM::Transition> instances.

=head1 ERRORS

 new():
         From Data::FSM::Utils::check_transition_objects():
                 Parameter 'transitions' check hasn't defined state objects.
                 Parameter 'transitions' contains object which has 'from' object which isn't in defined objects.
                         Reference: %s
                 Parameter 'transitions' contains object which has 'to' object which isn't in defined objects.
                         Reference: %s

         From Mo::utils::Array::check_array_object():
                 Parameter 'states' must be a array.
                         Value: %s
                         Reference: %s
                 Parameter 'states' with array must contain 'Data::FSM::State' objects.
                         Value: %s
                         Reference: %s
                 Parameter 'transitions' must be a array.
                         Value: %s
                         Reference: %s
                 Parameter 'transitions' with array must contain 'Data::FSM::Transition' objects.
                         Value: %s
                         Reference: %s

         From Mo::utils::Number::check_positive_natural():
                 Parameter 'id' must be a positive natural number.
                         Value: %s

=head1 EXAMPLE

=for comment filename=create_and_print_fsm.pl

 use strict;
 use warnings;

 use Data::FSM;
 use Data::FSM::State;
 use Data::FSM::Transition;

 my $state1 = Data::FSM::State->new(
         'name' => 'From',
 );
 my $state2 = Data::FSM::State->new(
         'name' => 'To',
 );
 my $fsm = Data::FSM->new(
         'id' => 7,
         'states' => [
                 $state1,
                 $state2,
         ],
         'transitions' => [
                 Data::FSM::Transition->new(
                         'from' => $state1,
                         'to' => $state2,
                 ),
         ],
 );

 # Print out.
 print 'Id: '.$fsm->id."\n";
 print "States:\n";
 foreach my $state (@{$fsm->states}) {
         print '- '.$state->name."\n";
 }
 print "Transitions:\n";
 foreach my $transition (@{$fsm->transitions}) {
         print '- '.$transition->from->name.' -> '.$transition->to->name."\n";
 }

 # Output:
 # Id: 7
 # States:
 # - From
 # - To
 # Transitions:
 # - From -> To

=head1 DEPENDENCIES

L<Data::FSM::Utils>,
L<Mo>,
L<Mo::utils::Array>,
L<Mo::utils::Number>.

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Data-FSM>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2025-2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
