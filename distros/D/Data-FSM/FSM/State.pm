package Data::FSM::State;

use strict;
use warnings;

use Mo qw(build is);
use Mo::utils 0.06 qw(check_bool check_length);
use Mo::utils::Number qw(check_positive_natural);

our $VERSION = 0.01;

has id => (
	is => 'ro',
);

has initial => (
	is => 'ro',
);

has name => (
	is => 'ro',
);

sub BUILD {
	my $self = shift;

	# Check 'id'.
	check_positive_natural($self, 'id');

	# Check 'inital'.
	if (! defined $self->{'initial'}) {
		$self->{'initial'} = 0;
	}
	check_bool($self, 'initial');

	# Check 'name'.
	check_length($self, 'name', 100);

	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Data::FSM::State - Data object for Finite State Machine state.

=head1 SYNOPSIS

 use Data::FSM::State;

 my $obj = Data::FSM::State->new(%params);
 my $id = $obj->id;
 my $initial = $obj->initial;
 my $name = $obj->name;

=head1 METHODS

=head2 C<new>

 my $obj = Data::FSM::State->new(%params);

Constructor.

=over 8

=item * C<id>

FSM state id.
The id is positive natural number.

It's optional.

Default value is undef.

=item * C<initial>

FSM state initial flag.

Default value is 0.

=item * C<name>

FSM state name.
The length of name is 100 characters.

Default value is undef.

=back

Returns instance of object.

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

=head1 ERRORS

 new():
         From Mo::Utils::check_bool():
                 Parameter 'initial' must be a bool (0/1).
                         Value: %s

         From Mo::Utils::check_length():
                 Parameter 'name' has length greater than '100'.
                         Value: %s

         From Mo::utils::Number::check_positive_natural():
                 Parameter 'id' must be a positive natural number.
                         Value: %s

=head1 EXAMPLE

=for comment filename=create_and_print_fsm_state.pl

 use strict;
 use warnings;

 use Data::FSM::State;

 my $obj = Data::FSM::State->new(
         'id' => 7,
         'initial' => 0,
         'name' => 'From',
 );

 # Print out.
 print 'Id: '.$obj->id."\n";
 print 'Initial: '.$obj->initial."\n";
 print 'Name: '.$obj->name."\n";

 # Output:
 # Id: 7
 # Initial: 0
 # Name: From

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
