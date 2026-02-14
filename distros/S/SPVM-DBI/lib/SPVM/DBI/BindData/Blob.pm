package SPVM::DBI::BindData::Blob;

1;

=encoding utf8

=head1 Name

SPVM::DBI::BindData::Blob - A Data Container for Binary Large Objects (BLOB)

=head1 Description

L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> class in L<SPVM> represents a data container for Binary Large Objects (BLOB).

When binding parameters to a statement, this class is used to explicitly indicate that a C<string> should be treated as a BLOB type by the database driver, rather than a normal character string.

This class implements L<Stringable|SPVM::Stringable> interface.

=head1 Usage

  use DBI::BindData::Blob;

  # Create a new BLOB data container with binary string
  my $blob_data = DBI::BindData::Blob->new($binary_string);
  
  # Use it in statement binding
  $st->bind_param(1, $blob_data);

=head1 Interfaces

L<Stringable|SPVM::Stringable>

=head1 Fields

=head2 value

C<has value : rw string;>

The binary data value represented as a string.

=head1 Class Methods

=head2 new

C<static method new : L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> ($binary: string = undef);>

Creates a new L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> object with the given binary $binary.

=head1 Instance Methods

=head2 to_string

C<method to_string : string ();>

Returns the L</"value"> field. This method is used for stringification and fulfills the L<Stringable|SPVM::Stringable> interface.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::St|SPVM::DBI::St>, L<Stringable|SPVM::Stringable>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
