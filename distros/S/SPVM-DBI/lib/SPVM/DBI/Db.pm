package SPVM::DBI::Db;

1;

=encoding utf8

=head1 Name

SPVM::DBI::Db - Database Handle

=head1 Description

L<DBI::Db|SPVM::DBI::Db> class in L<SPVM> represents a database handle. 

This class is a base class for database handles, and each method is expected to be overridden in child classes like L<DBI::Db::SQLite|SPVM::DBI::Db::SQLite>.

Note that this class is intended for driver authors. General users should not use this class directly; instead, use the L<DBI|SPVM::DBI> class to establish a connection.

=head1 Usage

The following example shows how to prepare a statement and manage transactions using a database handle (L<DBI::Db|SPVM::DBI::Db>).

  use DBI::Db;
  use DBI::St;
  use Go::Context;
  
  my $ctx = Go::Context->new;
  
  # Assuming $dbh is already obtained via DBI->connect
  
  # 1. Prepare a statement
  my $sth = $dbh->prepare($ctx, "SELECT * FROM users WHERE id = ?");
  
  # 2. Transaction management
  eval {
    $dbh->begin_work($ctx);
    
    # ... execute statements ...
    
    $dbh->commit($ctx);
  };
  if ($@) {
    $dbh->rollback($ctx);
  }
  
  # 3. Disconnect explicitly
  $dbh->disconnect;

=head1 Fields

=head2 Name

C<has Name : ro string;>

The data source name (DSN). This field stores the part of the DSN after the second colon (e.g., "dbname=:memory:" if the DSN is "dbi:SQLite:dbname=:memory:").

=head2 Username

C<has Username : ro string;>

The username for the database connection. This field stores the username extracted from the DSN.

=head2 AutoCommit

C<has AutoCommit : ro byte;>

The AutoCommit status.

=head2 InactiveDestroy

C<has InactiveDestroy : rw byte;>

The InactiveDestroy status.

=head2 IdleTimeoutDurationNsec

C<has IdleTimeoutDurationNsec : rw long;>

The maximum duration that a connection can remain idle, in nanoseconds.

=head2 ConnectTimeoutDurationNsec

C<has ConnectTimeoutDurationNsec : rw long;>

The timeout value for establishing a new database connection, in nanoseconds.

=head2 ReadTimeoutDurationNsec

C<has ReadTimeoutDurationNsec : rw long;>

The timeout value for read operations, in nanoseconds.

=head2 WriteTimeoutDurationNsec

C<has WriteTimeoutDurationNsec : rw long;>

The timeout value for write operations, in nanoseconds.

=head2 SocketKeepAliveDurationNsec

C<has SocketKeepAliveDurationNsec : rw long;>

The duration for TCP keep-alive idle time, in nanoseconds.

=head2 TCPNoDelay

C<has TCPNoDelay : rw byte;>

The TCP_NODELAY status (boolean 1 or 0).

=head1 Instance Methods

=head2 prepare

C<method prepare : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $sql : string, $options : object[] = undef)>

Prepares the SQL statement and returns a statement handle (L<DBI::St|SPVM::DBI::St>).

=head2 begin_work

C<method begin_work : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

Starts a new transaction.

=head2 commit

C<method commit : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

Commits the current transaction.

=head2 rollback

C<method rollback : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

Rolls back the current transaction.

=head2 last_insert_id

C<method last_insert_id : object ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string = undef, $schema : string = undef, $table : string = undef, $field : string = undef, $options : object[] = undef)>

Returns the ID of the last inserted row.

=head2 ping

C<method ping : int ($ctx : L<Go::Context|SPVM::Go::Context>)>

Checks if the database connection is still alive.

=head2 get_info

C<method get_info : object ($ctx : L<Go::Context|SPVM::Go::Context>, $info_type : int)>

Returns information about the database.

=head2 table_info

C<method table_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $type : string, $options : object[] = undef)>

Returns a statement handle containing information about tables.

=head2 column_info

C<method column_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $column : string)>

Returns a statement handle containing information about columns.

=head2 quote

C<method quote : string ($ctx : L<Go::Context|SPVM::Go::Context>, $str : string, $type : int = -1)>

Quotes a string for use in a SQL statement.

=head2 quote_identifier

C<method quote_identifier : string ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $options : object[] = undef)>

Quotes an identifier for use in a SQL statement.

=head2 disconnect

C<method disconnect : void ()>

Disconnects from the database.

=head2 prepare_common

C<protected method prepare_common : void ($sth : L<DBI::St|SPVM::DBI::St>, $ctx : L<Go::Context|SPVM::Go::Context>, $sql : string, $options : object[] = undef)>

Provides common initialization logic for a statement handle.

=head2 option_names

C<protected method option_names : string[] ()>

Returns the valid option names for this database handle.

=head2 DESTROY

C<method DESTROY : void ()>

The destructor. Unless L</"InactiveDestroy"> is true, it calls L</"disconnect">.

=head1 For Driver Authors

=head2 Extending DBI::Db

The following example shows how to implement a specific database handle (DBD) by extending the L<DBI::Db|SPVM::DBI::Db> class.

  class DBD::MyDriver::Db extends DBI::Db {
    
    # Overriding the prepare method
    method prepare : DBI::St ($ctx : Go::Context, $sql : string, $options : object[] = undef) {
      
      my $sth = DBD::MyDriver::St->new;
      
      # Call the common preparation logic provided by the base class.
      $self->prepare_common($sth, $ctx, $sql, $options);
      
      # Implement the driver-specific logic to prepare a statement.
      # ...
      
      return $sth;
    }
  }

=head2 Abstract Methods

The following methods are intended to be overridden in child classes. If a method is not overridden, it throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception with SQLSTATE "IM001" (Driver does not support this function):

L</"prepare">, L</"begin_work">, L</"commit">, L</"rollback">, L</"last_insert_id">, L</"ping">, L</"get_info">, L</"table_info">, L</"column_info">, L</"quote">, L</"quote_identifier">, L</"disconnect">.

=head2 Implementing prepare

When implementing L</"prepare">, driver authors should:

=over 2

=item * B<Call prepare_common>: Use L</"prepare_common"> to validate options and perform common initialization tasks.

=item * B<Handle Driver Defaults>: Ensure that initial states (like C<AutoCommit> defaulting to 1) are respected in the underlying database connection.

=back

=head2 How to use prepare_common

This method provides common initialization logic for a statement handle. It validates the option names in C<$options> using L</"option_names"> and performs other shared setup tasks. Driver authors are expected to call this method within their C<prepare> implementation.

=head2 Overriding option_names

Override this method if your database handle supports specific options. These names are used by L</"prepare_common"> to validate the options passed by the user.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::St|SPVM::DBI::St>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
