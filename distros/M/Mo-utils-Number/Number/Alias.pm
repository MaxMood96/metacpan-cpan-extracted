package Mo::utils::Number::Alias;

use base qw(Exporter);
use strict;
use warnings;

use Mo::utils::Number::Range 0.03 qw(check_int_range check_natural_range);
use Readonly;

Readonly::Array our @EXPORT_OK => qw(
	check_int8 check_int16 check_int32 check_int64
	check_uint8 check_uint16 check_uint32 check_uint64
);

our $VERSION = 0.09;

sub check_int8 {
	my ($self, $key) = @_;

	return check_int_range($self, $key, -128, 127);
}

sub check_int16 {
	my ($self, $key) = @_;

	return check_int_range($self, $key, -32768, 32767);
}

sub check_int32 {
	my ($self, $key) = @_;

	return check_int_range($self, $key, -2147483648, 2147483647);
}

sub check_int64 {
	my ($self, $key) = @_;

	return check_int_range($self, $key, -9223372036854775808, 9223372036854775807);
}

sub check_uint8 {
	my ($self, $key) = @_;

	return check_natural_range($self, $key, 0, 255);
}

sub check_uint16 {
	my ($self, $key) = @_;

	return check_natural_range($self, $key, 0, 65535);
}

sub check_uint32 {
	my ($self, $key) = @_;

	return check_natural_range($self, $key, 0, 4294967295);
}

sub check_uint64 {
	my ($self, $key) = @_;

	return check_natural_range($self, $key, 0, 18446744073709551615);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Mo::utils::Number::Alias - Mo number utilities, aliases.

=head1 SYNOPSIS

 use Mo::utils::Number::Alias qw(
         check_int8 check_int16 check_int32 check_int64
         check_uint8 check_uint16 check_uint32 check_uint64
 );

 check_int8($self, $key);
 check_int16($self, $key);
 check_int32($self, $key);
 check_int64($self, $key);
 check_uint8($self, $key);
 check_uint16($self, $key);
 check_uint32($self, $key);
 check_uint64($self, $key);

=head1 DESCRIPTION

Mo number aliases utilities for checking of data objects.

=head1 SUBROUTINES

=head2 C<check_int8>

 check_int8($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of integer numbers (-128, ... -2, -1, 0, 1, 2, ..., 127).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_int16>

 check_int16($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of integer numbers (-32768, ... -2, -1, 0, 1, 2, ..., 32767).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_int32>

 check_int32($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of integer numbers (-2147483648, ... -2, -1, 0, 1, 2, ..., 2147483647).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_int64>

 check_int64($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of integer numbers (-9223372036854775808, ... -2, -1, 0, 1, 2, ..., 9223372036854775807).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_uint8>

 check_uint8($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of natural numbers (0, 1, 2, ..., 255).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_uint16>

 check_uint16($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of natural numbers (0, 1, 2, ..., 65535).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_uint32>

 check_uint32($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of natural numbers (0, 1, 2, ..., 4294967295).
Value could be undefined or doesn't exist.

Returns undef.

=head2 C<check_uint64>

 check_uint64($self, $key);

I<Since version 0.09.>

Check parameter defined by C<$key> if it's in range of natural numbers (0, 1, 2, ..., 18446744073709551615).
Value could be undefined or doesn't exist.

Returns undef.

=head1 ERRORS

 check_int8():
         From Mo::utils::Number::Range::check_int_range():
                 Parameter '%s' must be a integer.
                         Value: %s
                 Parameter '%s' must be a integer between -128 and 127.
                         Value: %s

 check_int16():
         From Mo::utils::Number::Range::check_int_range():
                 Parameter '%s' must be a integer.
                         Value: %s
                 Parameter '%s' must be a integer between -32768 and 32767.
                         Value: %s

 check_int32():
         From Mo::utils::Number::Range::check_int_range():
                 Parameter '%s' must be a integer.
                         Value: %s
                 Parameter '%s' must be a integer between -2147483648 and 2147483647.
                         Value: %s

 check_int64():
         From Mo::utils::Number::Range::check_int_range():
                 Parameter '%s' must be a integer.
                         Value: %s
                 Parameter '%s' must be a integer between -9223372036854775808 and 9223372036854775807.
                         Value: %s

 check_uint8():
         From Mo::utils::Number::Range::check_natural_range():
                 Parameter '%s' must be a natural number.
                         Value: %s
                 Parameter '%s' must be a natural number between 0 and 255.
                         Value: %s

 check_uint16():
         From Mo::utils::Number::Range::check_natural_range():
                 Parameter '%s' must be a natural number.
                         Value: %s
                 Parameter '%s' must be a natural number between 0 and 65535.
                         Value: %s

 check_uint32():
         From Mo::utils::Number::Range::check_natural_range():
                 Parameter '%s' must be a natural number.
                         Value: %s
                 Parameter '%s' must be a natural number between 0 and 4294967295.
                         Value: %s

 check_uint64():
         From Mo::utils::Number::Range::check_natural_range():
                 Parameter '%s' must be a natural number.
                         Value: %s
                 Parameter '%s' must be a natural number between 0 and 18446744073709551615.
                         Value: %s

=head1 EXAMPLE1

=for comment filename=check_int8_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_int8);

 my $self = {
         'key' => -2,
 };
 check_int8($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE2

=for comment filename=check_int8_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_int8);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => -300,
 };
 check_int8($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a integer between -128 and 127.

=head1 EXAMPLE3

=for comment filename=check_int16_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_int16);

 my $self = {
         'key' => -2,
 };
 check_int16($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE4

=for comment filename=check_int16_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_int16);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => -300000,
 };
 check_int16($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a integer between -32768 and 32767.

=head1 EXAMPLE5

=for comment filename=check_int32_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_int32);

 my $self = {
         'key' => -2,
 };
 check_int32($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE6

=for comment filename=check_int32_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_int32);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => -30000000000,
 };
 check_int32($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a integer between -2147483648 and 2147483647.

=head1 EXAMPLE7

=for comment filename=check_int64_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_int64);

 my $self = {
         'key' => -2,
 };
 check_int64($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE8

=for comment filename=check_int64_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_int64);
 use Math::BigInt;

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => Math::BigInt->new(-30000000000000000000),
 };
 check_int64($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a integer between -9223372036854775808 and 9223372036854775807.

=head1 EXAMPLE9

=for comment filename=check_uint8_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_uint8);

 my $self = {
         'key' => 2,
 };
 check_uint8($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE10

=for comment filename=check_uint8_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_uint8);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => 300,
 };
 check_uint8($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 255.

=head1 EXAMPLE11

=for comment filename=check_uint16_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_uint16);

 my $self = {
         'key' => 60000,
 };
 check_uint16($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE12

=for comment filename=check_uint16_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_uint16);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => 300000,
 };
 check_uint16($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 65535.

=head1 EXAMPLE13

=for comment filename=check_uint32_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_uint32);

 my $self = {
         'key' => 3000000000,
 };
 check_uint32($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE14

=for comment filename=check_uint32_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_uint32);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => 300000000000,
 };
 check_uint32($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 4294967295.

=head1 EXAMPLE15

=for comment filename=check_uint64_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Number::Alias qw(check_uint64);

 my $self = {
         'key' => 200000000000,
 };
 check_uint64($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE16

=for comment filename=check_uint64_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Number::Alias qw(check_uint64);
 use Math::BigInt;

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => Math::BigInt->new(30000000000000000000),
 };
 check_uint64($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [...Range.pm:?] Parameter 'key' must be a natural number between 0 and 18446744073709551615.

=head1 DEPENDENCIES

L<Exporter>,
L<Mo::utils::Number::Range>,
L<Readonly>.

=head1 SEE ALSO

=over

=item L<Mo::utils::Number>

Mo number utilities.

=item L<Mo>

Micro Objects. Mo is less.

=item L<Mo::utils>

Mo utilities.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Mo-utils-Number>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2024-2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.09

=cut
