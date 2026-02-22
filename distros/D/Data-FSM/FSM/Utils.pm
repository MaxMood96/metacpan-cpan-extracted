package Data::FSM::Utils;

use base qw(Exporter);
use strict;
use warnings;

use Error::Pure qw(err);
use List::Util 1.33 qw(none);
use Mo::utils::Array qw(check_array);
use Readonly;

Readonly::Array our @EXPORT_OK => qw(check_transition_objects);

our $VERSION = 0.01;

sub check_transition_objects {
	my ($self, $key, $objects_ar) = @_;

	if (! exists $self->{$key}) {
		return;
	}

	check_array($self, $key);

	if (! defined $objects_ar
		|| ref $objects_ar ne 'ARRAY') {

		err "Parameter '$key' check hasn't defined state objects.";
	}

	foreach my $obj (@{$self->{$key}}) {
		if (none { $obj->from eq $_ } @{$objects_ar}) {
			err "Parameter '$key' contains object which has 'from' object which isn't in defined objects.",
				'Reference', (ref $obj->from),
			;
		}
		if (none { $obj->to eq $_ } @{$objects_ar}) {
			err "Parameter '$key' contains object which has 'to' object which isn't in defined objects.",
				'Reference', (ref $obj->to),
			;
		}
	}

	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Data::FSM::Utils - Utilities for Data::FSM.

=head1 SYNOPSIS

 use Data::FSM::Utils qw(check_transition_objects);

 check_transition_objects($key, $objects_ar);

=head1 SUBROUTINES

=head2 C<check_transition_objects>

 check_transition_objects($key, $objects_ar);

Check parameter defined by C<$key> which is a right object (method from() and
to() contain instance from C<$objects_ar> list).

Put error if check isn't ok.

Returns undef.

=head1 ERRORS

 check_transition_objects():
         From Mo::utils::Array::check_array():
                 Parameter '%s' must be a array.
                         Value: %s
                         Reference: %s
         Parameter '%s' check hasn't defined state objects.
         Parameter '%s' contains object which has 'from' object which isn't in defined objects.
                 Reference: %s
         Parameter '%s' contains object which has 'to' object which isn't in defined objects.
                 Reference: %s

=head1 DEPENDENCIES

L<Error::Pure>,
L<Exporter>,
L<List::Util>,
L<Mo::utils::Array>,
L<Readonly>.

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
