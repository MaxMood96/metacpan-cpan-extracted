package SPVM::DBI::St;

1;

=encoding utf8

=head1 Name

SPVM::DBI::St - Statement Handle

=head1 Description

L<DBI::St|SPVM::DBI::St> class in L<SPVM> represents a statement handle. This class is a base class for statement handles, and each method is expected to be overridden in child classes like L<DBI::St::SQLite|SPVM::DBI::St::SQLite>.

=head1 Usage

A statement handle is typically created by calling the L<prepare|SPVM::DBI/"prepare"> method of a database handle (L<DBI|SPVM::DBI>).

  # Create a statement handle
  my $sth = $dbh->prepare($ctx, "SELECT id, name FROM users WHERE id = ?");
  
  # Execute with bind values
  $sth->execute($ctx, [(object)1]);
  
  # Fetch rows
  while (my $row = $sth->fetch($ctx)) {
    my $id = $row->[0]->(int);
    my $name = $row->[1]->(string);
  }
  
  # Finish explicitly
  $sth->finish;

Binary Data:

  my $binary_data = "abc\0\1\2";
  my $blob = DBI->blob($binary_data);
  
  my $sth_insert = $dbh->prepare($ctx, "INSERT INTO images (data) VALUES (?)");
  $sth_insert->execute($ctx, [(object)$blob]);

=head1 Fields

=head2 Database

C<has Database : ro L<DBI|SPVM::DBI>;>

The database handle that created this statement handle.

=head2 Statement

C<has Statement : ro string;>

The SQL statement string.

=head1 Instance Methods

=head2 NUM_OF_FIELDS

C<method NUM_OF_FIELDS : int ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns the number of fields (columns) in the result set.

=head2 NAME

C<method NAME : string[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns an array of column names.

=head2 NULLABLE

C<method NULLABLE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns an array indicating if each column is nullable.

=head2 TYPE

C<method TYPE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns an array of column types.

=head2 PRECISION

C<method PRECISION : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns an array of column precision values.

=head2 SCALE

C<method SCALE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns an array of column scale values.

=head2 execute

C<method execute : long ($ctx : L<Go::Context|SPVM::Go::Context>, $bind_values : object[] = undef)>

Executes the prepared statement and return the number of affected rows, or -1 if unknown.

=head2 fetch

C<method fetch : object[] ($ctx : L<Go::Context|SPVM::Go::Context>, $bind_columns : object[] = undef, $ret_row : object[] = undef)>

Fetches the next row of data from the result set.

Arguments:

=over 4

=item * C<$ctx> : L<Go::Context|SPVM::Go::Context>

The context for goroutine-like execution and cancellation.

=item * C<$bind_columns> : object[] (Optional)

An array of objects used as persistent buffers for column values.

=over 8

=item * If a slot is C<undef>, the driver creates a new object (e.g., C<Int>, C<String>) and stores it in this array.

=item * If a slot already contains an object, the driver reuses it by updating its value (mutable update), which avoids new memory allocations.

=back

=item * C<$ret_row> : object[] (Optional)

An array to store the result of the current row (the pointers to objects in C<$bind_columns> or C<undef> for C<NULL>).

=over 8

=item * If this argument is C<undef>, the driver creates a new array for the row.

=item * If an array is provided, the driver fills it and returns it.

=back

=back

Return Value:

Returns the fetched row as an array of objects.

=over 8

=item * If C<$ret_row> was provided, that same array is returned (with updated values).

=item * If C<$ret_row> was C<undef>, a newly allocated array is returned.

=item * Returns C<undef> when there are no more rows.

=back

=head2 rows

C<method rows : long ($ctx : L<Go::Context|SPVM::Go::Context>)>

Returns the number of rows affected by the last execute.

=head2 finish

C<method finish : void ()>

Indicates that no more data will be fetched from this statement handle before it is prepared again or destroyed. 

=head2 DESTROY

C<method DESTROY : void ()>

The destructor. Calls L</"finish"> method.

=head1 For Driver Authors

=head2 Extending DBI::St

The following example shows how to implement a specific database statement handle (DBD) by extending the L<DBI::St|SPVM::DBI::St> class.

  class DBD::MyDriver::St extends DBI::St {
    
    # Overriding the execute method
    method execute : long ($ctx : Go::Context, $bind_values : object[] = undef) {
      
      # Implement the logic to execute the prepared statement.
      # Return the number of affected rows, or -1 if unknown.
      # ...
    }
    
    # Overriding the fetch method
    method fetch : object[] ($ctx : Go::Context, $bind_columns : object[] = undef, $ret_row : object[] = undef) {
      
      # Implement the logic to fetch one row.
      # Use $bind_columns and $ret_row to minimize memory allocations.
      # ...
    }
  }

=head2 Abstract Methods

The following methods are intended to be overridden in child classes. If a method is not overridden, it throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception with SQLSTATE "IM001" (Driver does not support this function) to indicate that the driver implementation is missing:

L</"NUM_OF_FIELDS">, L</"NAME">, L</"NULLABLE">, L</"TYPE">, L</"PRECISION">, L</"SCALE">, L</"execute">, L</"fetch">, L</"rows">, L</"finish">.

=head2 Overriding Instance Methods

=head3 option_names

=head2 option_names

C<protected method option_names : string[] ()>

Returns the valid option names for this statement handle. Override this method if your statement handle supports specific options. These names are used to validate the options passed to L<DBI#prepare_common|SPVM::DBI/"prepare_common"> method.

=head2 Type Mapping Matrix

The mapping depends on the SPVM type and the target database column type. Driver authors must follow these rules to ensure data integrity and consistent behavior.

=head3 Bind Values (SPVM to SQL)

The driver must cast the SPVM value to the appropriate C type according to the target database column.

=over 2

=item * B<SPVM C<byte> (signed 8-bit)>

=over 4

=item * To 8-bit Signed Column --E<gt> Cast to C<int8_t>

=item * To 8-bit Unsigned Column --E<gt> Cast to C<uint8_t>

=item * To 16-bit Signed Column --E<gt> Cast to C<int16_t>

=item * To 16-bit Unsigned Column --E<gt> Cast to C<uint16_t>

=item * To 32-bit Signed Column --E<gt> Cast to C<int32_t>

=item * To 32-bit Unsigned Column --E<gt> Cast to C<uint32_t>

=item * To 64-bit Signed Column --E<gt> Cast to C<int64_t>

=item * To 64-bit Unsigned Column --E<gt> Cast to C<uint64_t>

=back

=item * B<SPVM C<short> (signed 16-bit)>

=over 4

=item * To 8-bit Signed Column --E<gt> Cast to C<int8_t>

=item * To 8-bit Unsigned Column --E<gt> Cast to C<uint8_t>

=item * To 16-bit Signed Column --E<gt> Cast to C<int16_t>

=item * To 16-bit Unsigned Column --E<gt> Cast to C<uint16_t>

=item * To 32-bit Signed Column --E<gt> Cast to C<int32_t>

=item * To 32-bit Unsigned Column --E<gt> Cast to C<uint32_t>

=item * To 64-bit Signed Column --E<gt> Cast to C<int64_t>

=item * To 64-bit Unsigned Column --E<gt> Cast to C<uint64_t>

=back

=item * B<SPVM C<int> (signed 32-bit)>

=over 4

=item * To 8-bit Signed Column --E<gt> Cast to C<int8_t>

=item * To 8-bit Unsigned Column --E<gt> Cast to C<uint8_t>

=item * To 16-bit Signed Column --E<gt> Cast to C<int16_t>

=item * To 16-bit Unsigned Column --E<gt> Cast to C<uint16_t>

=item * To 32-bit Signed Column --E<gt> Cast to C<int32_t>

=item * To 32-bit Unsigned Column --E<gt> Cast to C<uint32_t>

=item * To 64-bit Signed Column --E<gt> Cast to C<int64_t>

=item * To 64-bit Unsigned Column --E<gt> Cast to C<uint64_t>

=back

=item * B<SPVM C<long> (signed 64-bit)>

=over 4

=item * To 8-bit Signed Column --E<gt> Cast to C<int8_t>

=item * To 8-bit Unsigned Column --E<gt> Cast to C<uint8_t>

=item * To 16-bit Signed Column --E<gt> Cast to C<int16_t>

=item * To 16-bit Unsigned Column --E<gt> Cast to C<uint16_t>

=item * To 32-bit Signed Column --E<gt> Cast to C<int32_t>

=item * To 32-bit Unsigned Column --E<gt> Cast to C<uint32_t>

=item * To 64-bit Signed Column --E<gt> Cast to C<int64_t>

=item * To 64-bit Unsigned Column --E<gt> Cast to C<uint64_t>

=back

=item * B<SPVM C<float> / C<double>>

=over 4

=item * To Floating Point Column --E<gt> Cast to C<float> or C<double>

=item * To Integer Column --E<gt> Standard C casting to the target integer type

=back

=item * B<Other SPVM Types>

For these types, if the target database column type is different from the expected type, the conversion behavior (automatic casting or raising an error) depends on the database implementation.

=over 4

=item * C<string> --E<gt> UTF-8 Character string

=item * L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BLOB>) --E<gt> Binary data

=item * L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BIG_INT>) --E<gt> Arbitrary precision integer string

=item * L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BIG_FLOAT>) --E<gt> Arbitrary precision decimal string

=item * C<undef> --E<gt> Database C<NULL>

=back

=back

---

=head3 Fetching Rows (SQL to SPVM)

The driver must convert database values into the following SPVM objects.

=over 2

=item * B<Database 8/16/32-bit Integer (Signed/Unsigned)>

=over 4

=item * --E<gt> L<Int|SPVM::Int> object (via C<int32_t> cast)

=back

=item * B<Database 64-bit Integer (Signed/Unsigned)>

=over 4

=item * --E<gt> L<Long|SPVM::Long> object (via C<int64_t> cast)

=back

=item * B<Database Floating Point>

=over 4

=item * Single-precision --E<gt> L<Float|SPVM::Float> object

=item * Double-precision --E<gt> L<Double|SPVM::Double> object

=back

=item * B<Database High-Precision Numbers (NUMERIC, DECIMAL, etc.)>

=over 4

=item * Exact Integers --E<gt> L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BIG_INT>) as string

=item * Exact Decimals --E<gt> L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BIG_FLOAT>) as string

=back

=item * B<Database String / Binary / NULL>

=over 4

=item * Character string --E<gt> C<string> object

=item * Binary data --E<gt> L<DBI::Data|SPVM::DBI::Data> (C<TYPE_ID_BLOB>)

=item * C<NULL> --E<gt> C<undef>

=back

=back

=head3 Technical Note on 64-bit Casts

When casting between C<uint64_t> (database) and C<int64_t> (SPVM C<long>):

=over 2

=item * B<Range <= 2^63 - 1>: 

The value is preserved perfectly during casting. This covers the vast majority of use cases, such as auto-increment IDs that haven't reached the halfway point of the 64-bit range.

=item * B<Range > 2^63 - 1>: 

The bit pattern is preserved, but the value will be interpreted as a negative number in SPVM. Since no bits are lost, the original unsigned value can be recovered or compared using bitwise operations if necessary.

=back

=head1 See Also

L<DBI|SPVM::DBI>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
