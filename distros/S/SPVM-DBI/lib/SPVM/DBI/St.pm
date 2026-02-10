package SPVM::DBI::St;

1;

=encoding utf8

=head1 Name

SPVM::DBI::St - Statement Handle

=head1 Description

L<DBI::St|SPVM::DBI::St> class in L<SPVM> represents a statement handle. This class is a base class for statement handles, and each method is expected to be overridden in child classes like L<DBI::St::SQLite|SPVM::DBI::St::SQLite>.

=head1 Usage

  class DBD::MyDiriver::St extends DBI::St {
    
    # Overriding a method
    method execute : long ($ctx : Go::Context, $bind_values : object[] = undef) {
      
      # Implement a logic
    }
    
  }

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

Returns the valid option names for this statement handle. This method is intended to be overridden in child classes.

=head2 NUM_OF_FIELDS

C<method NUM_OF_FIELDS : int ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return the number of fields (columns) in the result set.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 NAME

C<method NAME : string[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return an array of column names.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 NULLABLE

C<method NULLABLE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return an array indicating if each column is nullable.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 TYPE

C<method TYPE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return an array of column types.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 PRECISION

C<method PRECISION : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return an array of column precision values.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 SCALE

C<method SCALE : int[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return an array of column scale values.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 execute

C<method execute : long ($ctx : L<Go::Context|SPVM::Go::Context>, $bind_values : object[] = undef)>

In a child class, this method must execute the prepared statement and return the number of affected rows, or -1 if unknown.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 fetchrow_array

C<method fetchrow_array : object[] ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must fetch the next row of data and return an array of objects or C<undef> if there are no more rows.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 rows

C<method rows : long ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must return the number of rows affected by the last execute.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 finish

C<method finish : void ()>

In a child class, this method is expected to indicate that no more data will be fetched from this statement handle.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 DESTROY

C<method DESTROY : void ()>

The destructor. Calls L</"finish">.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::Db|SPVM::DBI::Db>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
