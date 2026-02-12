package SPVM::DBI::Data;

1;

=encoding utf8

=head1 Name

SPVM::DBI::Data - Data Container for Special Types

=head1 Description

L<DBI::Data|SPVM::DBI::Data> class in L<SPVM> represents a data container for special types that cannot be represented by basic types like C<int> or C<double>.

This class holds a value as a C<string> and a C<type_id> to indicate how the value should be interpreted (e.g., as a large integer or a high-precision decimal).

This class implements L<Stringable|SPVM::Stringable> interface.

=head1 Usage

  use DBI::Data;

  # Create a new data container
  my $data = DBI::Data->new;
  $data->set_type_id(DBI::Data->TYPE_ID_BIG_INT);
  $data->set_value("123456789012345678901234567890");
  
  # Stringification
  my $string_value = $data->to_string;

=head1 Interfaces

L<Stringable|SPVM::Stringable>

=head1 Enumerations

The following type IDs are defined in the C<enum> section:

=over 4

=item * C<TYPE_ID_UNKNOWN> (0)

The data type is unknown.

=item * C<TYPE_ID_BLOB> (1)

The data is a Binary Large Object (BLOB).

=item * C<TYPE_ID_BIG_INT> (2)

The data is a large integer (e.g., C<Math::BigInt> in Perl).

=item * C<TYPE_ID_BIG_FLOAT> (3)

The data is a high-precision floating-point number (e.g., C<Math::BigFloat> in Perl).

=back

=head1 Fields

=head2 type_id

C<has type_id : rw int;>

An ID that represents the data type. One of the values defined in the L</"Enumerations"> section.

=head2 value

C<has value : rw string;>

The data value represented as a string.

=head1 Class Methods

=head2 new

C<static method new : L<DBI::Data|SPVM::DBI::Data> ()>

Creates a new L<DBI::Data|SPVM::DBI::Data> object.

=head1 Instance Methods

=head2 to_string

C<method to_string : string ()>

Returns the L</"value"> field. This method is intended to be used for stringification.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::St|SPVM::DBI::St>, L<Stringable|SPVM::Stringable>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
