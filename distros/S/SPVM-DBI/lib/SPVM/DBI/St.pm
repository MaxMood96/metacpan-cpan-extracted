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

C<method NUM_OF_FIELDS : int ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns the number of fields (columns) in the result set.

=head2 NAME

C<method NAME : string[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns an array of column names.

=head2 NULLABLE

C<method NULLABLE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns an array indicating if each column is nullable.

=head2 TYPE

C<method TYPE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns an array of column types.

=head2 PRECISION

C<method PRECISION : int[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns an array of column precision values.

=head2 SCALE

C<method SCALE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns an array of column scale values.

=head2 execute

C<method execute : long ($ctx : L<Go::Context|SPVM::Go::Context>, $bind_values : object[] = undef);>

Executes the prepared statement and return the number of affected rows, or -1 if unknown.

=head2 fetch

C<method fetch : object[] ($ctx : L<Go::Context|SPVM::Go::Context>);>

Fetches the next row of data from the result set as an array of objects.

This is the simplest way to fetch data. It always allocates a new array and new column objects (e.g., C<Int>, C<string>) for each row.

Arguments:

=over 4

=item * C<$ctx> : L<Go::Context|SPVM::Go::Context>

The context for execution control and cancellation.

=back

Return Value:

Returns the fetched row as an array of objects (C<object[]>). Returns C<undef> if there are no more rows.

=head2 fetch_with_bind_columns

C<method fetch_with_bind_columns : object[] ($ctx : Go::Context, $bind_columns : object[] = undef, $ret_row : object[] = undef, $create_count_ref : int* = undef, $extended_count_ref : int* = undef);>

Fetches the next row efficiently by using bound columns as reusable buffers.

Arguments:

=over 4

=item * C<$ctx> : L<Go::Context|SPVM::Go::Context>

The context for execution control and cancellation.

=item * C<$bind_columns> : object[] (Optional)

An array of objects provided as reusable containers for column values. This array is read-only; the driver does not modify its elements.

=over 8

=item * If a slot contains an object of the matching type, the driver reuses that container by updating its value, avoiding new memory allocations.

=item * If a slot is C<undef>, or if the existing object's type does not match the type fetched from the database, the driver creates a new column object.

=back

=item * C<$ret_row> : object[] (Optional)

An array to store the result of the current row.

=over 8

=item * The driver fills this array with the objects: either the reused ones from C<$bind_columns> or the newly created ones.

=item * If C<undef>, the driver creates and returns a new array for the row result.

=item * If an array is provided, the driver fills and returns it. If the provided array does not have enough capacity to store all columns, it is automatically extended.

=back

=item * C<$create_count_ref> : int* (Optional)

A reference to an integer that is incremented whenever a new column object is created. This can be used to detect unintended object creations caused by type mismatches between C<$bind_columns> and the actual database columns.

=item * C<$extended_count_ref> : int* (Optional)

A reference to an integer that is incremented whenever the C<$ret_row> array is extended. This is useful for detecting unintended memory allocations caused by the insufficient size of the provided C<$ret_row> array.

=back

Return Value:

Returns the fetched row as an array of objects.

=over 8

=item * If C<$ret_row> was provided, that same array is returned (potentially extended).

=item * If C<$ret_row> was C<undef>, a newly allocated array is returned.

=item * The returned array contains objects from C<$bind_columns> where the types matched; otherwise, it contains newly created objects.

=item * Returns C<undef> when there are no more rows.

=back

=head2 rows

C<method rows : long ($ctx : L<Go::Context|SPVM::Go::Context>);>

Returns the number of rows affected by the last execute.

=head2 finish

C<method finish : void ();>

Indicates that no more data will be fetched from this statement handle before it is prepared again or destroyed. 

=head2 DESTROY

C<method DESTROY : void ();>

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

C<protected method option_names : string[] ();>

Returns the valid option names for this statement handle. Override this method if your statement handle supports specific options. These names are used to validate the options passed to L<DBI#prepare_common|SPVM::DBI/"prepare_common"> method.

=head2 Type Mapping Rules

The mapping depends on the SPVM type and the target database column type. Driver authors must follow these rules to ensure data integrity and consistent behavior.

=head3 Bind Values (SPVM to SQL)

The driver must interpret the SPVM objects and convert them to the appropriate C type for the target database column.

=over 2

=item * L<Byte|SPVM::Byte> (C<unsigned> field is a false value)

The value is treated as a signed 8-bit integer (C<int8_t>).

=item * L<Byte|SPVM::Byte> (C<unsigned> field is a true value)

The value is treated as an unsigned 8-bit integer (C<uint8_t>).

=item * L<Short|SPVM::Short> (C<unsigned> field is a false value)

The value is treated as a signed 16-bit integer (C<int16_t>).

=item * L<Short|SPVM::Short> (C<unsigned> field is a true value)

The value is treated as an unsigned 16-bit integer (C<uint16_t>).

=item * L<Int|SPVM::Int> (C<unsigned> field is a false value)

The value is treated as a signed 32-bit integer (C<int32_t>).

=item * L<Int|SPVM::Int> (C<unsigned> field is a true value)

The value is treated as an unsigned 32-bit integer (C<uint32_t>).

=item * L<Long|SPVM::Long> (C<unsigned> field is a false value)

The value is treated as a signed 64-bit integer (C<int64_t>).

=item * L<Long|SPVM::Long> (C<unsigned> field is a true value)

The value is treated as an unsigned 64-bit integer (C<uint64_t>).

=item * L<Float|SPVM::Float>

The value is treated as a single-precision floating-point (C<float>).

=item * L<Double|SPVM::Double>

The value is treated as a double-precision floating-point (C<double>).

=item * C<string>

The value is treated as a string.

Conventionally, strings are expected to be UTF-8 encoded. However, since the C<string> type represents a raw sequence of bytes, it can also hold strings in any other character encoding (e.g., EUC-JP, Shift_JIS) or any arbitrary byte data.

=item * L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob>

The value is treated as binary data (BLOB).

=item * C<undef>

The value is treated as a database C<NULL>.

=back

=head3 Fetching Rows (SQL to SPVM)

The driver must convert database values into the following SPVM objects.

=over 2

=item * Database 8-bit Signed Integer

Converts to a L<Byte|SPVM::Byte> object (C<unsigned> field is a false value).

=item * Database 8-bit Unsigned Integer

Converts to a L<Byte|SPVM::Byte> object (C<unsigned> field is a true value).

=item * Database 16-bit Signed Integer

Converts to a L<Short|SPVM::Short> object (C<unsigned> field is a false value).

=item * Database 16-bit Unsigned Integer

Converts to a L<Short|SPVM::Short> object (C<unsigned> field is a true value).

=item * Database 32-bit Signed Integer

Converts to an L<Int|SPVM::Int> object (C<unsigned> field is a false value).

=item * Database 32-bit Unsigned Integer

Converts to an L<Int|SPVM::Int> object (C<unsigned> field is a true value).

=item * Database 64-bit Signed Integer (e.g., C<BIGINT>)

Converts to a L<Long|SPVM::Long> object (C<unsigned> field is a false value).

=item * Database 64-bit Unsigned Integer (e.g., C<BIGINT UNSIGNED>)

Converts to a L<Long|SPVM::Long> object (C<unsigned> field is a true value).

=item * Database Single-precision Floating Point

Converts to a L<Float|SPVM::Float> object.

=item * Database Double-precision Floating Point

Converts to a L<Double|SPVM::Double> object.

=item * Database Character String (e.g., C<CHAR>, C<VARCHAR>)

Converts to a C<string> object.

=item * Database Binary Data (BLOB)

Converts to a C<string> object.

=item * Date and Time Types (e.g., C<DATE>, C<TIME>, C<DATETIME>, C<TIMESTAMP>)

Converts to a C<string> object in RFC 3339 format. The specific format depends on the database type:

=over 2

=item * C<Date>: C<YYYY-MM-DD>

=item * C<Time>: C<HH:MM:SS.fffffffff>

=item * C<Date and Time>: C<YYYY-MM-DD HH:MM:SS.fffffffff[Z|[+|-]HH:MM]>

=back

The following rules apply to these formats:

=over 2

=item * Separator

A space is used between the date and time instead of "T" for better readability and compatibility with standard SQL output.

=item * Fractional Seconds

The fractional seconds part (C<fffffffff>) can have up to 9 digits (nanosecond precision). The number of digits depends on the database precision (e.g., 6 digits for microseconds).

=item * Time Zone

If the database provides time zone information, it must be included as C<Z> (for UTC) or a numerical offset (e.g., C<+09:00>). If the database does not provide time zone information, the offset part is omitted to indicate a local or unknown time zone.

=back

=item * Database Decimals (e.g., C<DECIMAL>, C<NUMERIC>, and integers exceeding 64-bit)

Converts to a C<string> object. These values are converted into their exact textual representation (e.g., C<"12345678901234567890.12345">) to preserve full precision that exceeds the capacity of 64-bit integers or floating-point numbers.

=item * Database Character Large Object (C<CLOB>)

Converts to a C<string> object.

=item * Database C<NULL>

Converts to C<undef>.

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
