package Data::FSM::Transition;

use strict;
use warnings;

use Mo qw(build is);
use Mo::utils 0.12 qw(check_code check_isa check_length check_required);
use Mo::utils::Number qw(check_positive_natural);

our $VERSION = 0.01;

has callback => (
	is => 'ro',
);

has from => (
	is => 'ro',
);

has id => (
	is => 'ro',
);

has name => (
	is => 'ro',
);

has to => (
	is => 'ro',
);

sub BUILD {
	my $self = shift;

	# Check 'callback'.
	check_code($self, 'callback');

	# Check 'from'.
	check_required($self, 'from');
	check_isa($self, 'from', 'Data::FSM::State');

	# Check 'id'.
	check_positive_natural($self, 'id');

	# Check 'name'.
	check_length($self, 'name', 100);

	# Check 'to'.
	check_required($self, 'to');
	check_isa($self, 'to', 'Data::FSM::State');

	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Data::FSM::Transition - Data object for Finite Transition Machine transition.

=head1 SYNOPSIS

 use Data::FSM::Transition;

 my $obj = Data::FSM::Transition->new(%params);
 my $callback = $obj->callback;
 my $from = $obj->from;
 my $id = $obj->id;
 my $name = $obj->name;
 my $to = $obj->to;

=head1 METHODS

=head2 C<new>

 my $obj = Data::FSM::Transition->new(%params);

Constructor.

=over 8

=item * C<callback>

Transition callback.

It's optional.

Default value is undef.

=item * C<from>

L<Data::FSM::State> state object.

It's required.

Default value is undef.

=item * C<id>

FSM state id.
The id is positive natural number.

It's optional.

Default value is undef.

=item * C<name>

FSM state name.
The length of name is 100 characters.

Default value is undef.

=item * C<to>

L<Data::FSM::State> state object.

It's required.

Default value is undef.

=back

Returns instance of object.

=head2 C<callback>

 my $callback = $obj->callback;

Get transition callback.

Returns reference to code.

=head2 C<from>

 my $from = $obj->from;

Get state object from which transition starts.

Returns L<Data::FSM::State> instance.

=head2 C<id>

 my $id = $obj->id;

Get FSM state id.

Returns positive natural number.

=head2 C<initial>

 my $initial = $obj->initial;

Get inital flag..

Returns boolean (0/1).

=head2 C<name>

 my $name = $obj->name;

Get FSM state name.

Returns string.

=head2 C<to>

 my $to = $obj->to;

Get state object from which transition ends.

Returns L<Data::FSM::State> instance.

=head1 ERRORS

 new():
         From Mo::Utils::check_code():
                 Parameter '%s' must be a code.
                         Value: %s

         From Mo::utils::check_code():
                 Parameter '%s' must be a '%s' object.
                         Value: %s
                         Reference: %s

         From Mo::Utils::check_length():
                 Parameter 'name' has length greater than '100'.
                         Value: %s

         From Mo::utils::check_required():
                 Parameter '%s' is required.

         From Mo::utils::Number::check_positive_natural():
                 Parameter 'id' must be a positive natural number.
                         Value: %s

=head1 EXAMPLE

=for comment filename=create_and_print_fsm_transition.pl

 use strict;
 use warnings;

 use Data::FSM::Transition;
 use Data::FSM::State;

 my $locked = Data::FSM::State->new(
         'name' => 'Locked',
 );
 my $unlocked = Data::FSM::State->new(
         'name' => 'Unlocked',
 );
 my $obj = Data::FSM::Transition->new(
         'callback' => sub {
                 my $self = shift;
                 print 'Id: '.$self->id."\n";
         },
         'from' => $locked,
         'id' => 7,
         'name' => 'Coin',
         'to' => $unlocked,
 );

 # Print out.
 print 'Id: '.$obj->id."\n";
 print 'From: '.$obj->from->name."\n";
 print 'To: '.$obj->from->name."\n";
 print 'Name: '.$obj->name."\n";

 # Output:
 # Id: 7
 # From: Locked
 # To: Locked
 # Name: Coin

=head1 DEPENDENCIES

L<Mo>,
L<Mo::utils>,
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
