package SPVM::DBI::St;

1;

=encoding utf8

=head1 Name

SPVM::DBI::St - Statement Handle

=head1 Description

L<DBI::St|SPVM::DBI::St> class in L<SPVM> represents a statement handle. This class is a base class for statement handles, and each method is expected to be overridden in child classes like L<DBI::St::SQLite|SPVM::DBI::St::SQLite>.

=head1 Usage

A statement handle is typically created by calling the L<prepare|SPVM::DBI::Db/"prepare"> method of a database handle (L<DBI::Db|SPVM::DBI::Db>).

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

=head1 Fields

=head2 Database

C<has Database : ro L<DBI::Db|SPVM::DBI::Db>;>

The database handle that created this statement handle.

=head2 Statement

C<has Statement : ro string;>

The SQL statement string.

=head1 Instance Methods

=head2 option_names

C<protected method option_names : string[] ()>

Returns the valid option names for this statement handle.

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

=head2 Overriding option_names

Returns the valid option names for this statement handle. Override this method if your statement handle supports specific options. These names are used to validate the options passed to L<DBI::Db#prepare_common|SPVM::DBI::Db/"prepare_common"> method.

=head2 Abstract Methods

The following methods are intended to be overridden in child classes. If a method is not overridden, it throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception with SQLSTATE "IM001" (Driver does not support this function) to indicate that the driver implementation is missing:

L</"NUM_OF_FIELDS">, L</"NAME">, L</"NULLABLE">, L</"TYPE">, L</"PRECISION">, L</"SCALE">, L</"execute">, L</"fetch">, L</"rows">, L</"finish">.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::Db|SPVM::DBI::Db>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
