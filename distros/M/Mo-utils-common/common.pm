package Mo::utils::common;

use base qw(Exporter);
use strict;
use warnings;

use Error::Pure qw(err);
use Readonly;
use Scalar::Util qw(blessed);

Readonly::Array our @EXPORT_OK => qw(check_object);

our $VERSION = 0.01;

sub check_object {
	my ($value, $class, $message, $message_params_ar) = @_;

	if (! blessed($value)) {
		my $err_message = _error_message($message, $message_params_ar);
		err $err_message,

			# Only, if value is scalar.
			(ref $value eq '') ? (
				'Value', $value,
			) : (),

			# Only if value is reference.
			(ref $value ne '') ? (
				'Reference', (ref $value),
			) : (),
	}

	if (! $value->isa($class)) {
		my $err_message = _error_message($message, $message_params_ar);
		err $err_message,
			'Reference', (ref $value),
		;
	}

	return;
}

sub _error_message {
	my ($message, $message_params_ar) = @_;

	if (defined $message_params_ar && ref $message_params_ar ne 'ARRAY') {
		err "Bad definition of $message_params_ar.",
			'Message params array refence', $message_params_ar,
		;
	}

	my $err_message;
	if (defined $message_params_ar) {
		$err_message = sprintf $message, @{$message_params_ar};
	} else {
		$err_message = $message;
	}

	return $err_message;

}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Mo::utils::common - Common subroutines for Mo::utils framework.

=head1 SYNOPSIS

 use Mo::utils::common qw(check_object);

 check_object($value, $class, $message, $message_params_ar);

=head1 SUBROUTINES

=head2 C<check_object>

 check_object($value, $class, $message, $message_params_ar);

Check C<$value> which is instance of C<$class> or not.

Put error (defined by C<$message> and C<$message_params_ar>) if check isn't ok.

Returns undef.

=head1 ERRORS

 check_object():
         I<Create own errors from C<sprintf $message, @{$message_params_ar}>.>
         Bad definition of $message_params_ar.
                 Message params array reference: %s

=head1 EXAMPLE1

=for comment filename=check_object_scalar.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::common qw(check_object);

 $Error::Pure::TYPE = 'AllError';

 # Value to check.
 my $value = 'Foo';

 # Check.
 check_object($value, 'Foo', 'Error: This is not a instance of %s.', ['Foo']);

 # Output:
 # ERROR: Error: This is not a instance of Foo.
 # Value: Foo
 # Mo::utils::common  err                              ../common.pm               20
 # main               Mo::utils::common::check_object  ../check_object_scalar.pl  12

=head1 EXAMPLE2

=for comment filename=check_object_object.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::common qw(check_object);
 use Test::MockObject;

 $Error::Pure::TYPE = 'AllError';

 # Value to check.
 my $value = Test::MockObject->new;

 # Check.
 check_object($value, 'Foo', 'Error: This is not a instance of %s.', ['Foo']);

 # Output:
 # ERROR: Error: This is not a instance of Foo.
 # Reference: Reference: Test::MockObject
 # Mo::utils::common  err                              ../common.pm               35
 # main               Mo::utils::common::check_object  ../check_object_scalar.pl  13

=head1 DEPENDENCIES

L<Error::Pure>,
L<Exporter>,
L<Readonly>,
L<Scalar::Util>.

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Mo-utils-common>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2025-2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
