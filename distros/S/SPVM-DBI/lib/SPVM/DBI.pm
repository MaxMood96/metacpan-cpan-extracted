package SPVM::DBI;

our $VERSION = "0.008";

1;

=encoding utf8

=head1 Name

SPVM::DBI - Base Class for Database Drivers Providing Common Utilities

=head1 Description

L<DBI|SPVM::DBI> class in L<SPVM> provides a database-independent interface for database connections.

This class serves two main purposes:

=over 2

=item *

B<Base Class for Drivers>: It acts as a base class for database driver handles. Each driver, such as L<DBD::SQLite|SPVM::DBD::SQLite>, extends this class and implements its own C<connect> and other database-specific methods.

=item *

B<Common Functionality>: It provides common fields and protected methods (like L</"connect_common">) that handle shared logic for all drivers, such as option validation and DSN parsing.

=back

Note that while this class contains the logic for driver authors, general users will interact with instances of this class (or its subclasses) to perform database operations.

=head1 Caution

B<SPVM::DBI is under early development. This is an alpha release.>

This module is not yet tested and is in a highly experimental stage. The interface and implementation are subject to change without notice. Use this module at your own risk. It is not recommended for production use.

=head1 Usage

  use DBI;
  use DBD::SQLite;
  use Go::Context;
  
  my $ctx = Go::Context->new;
  
  # 1. Connect to a database
  my $dbh = DBD::SQLite->connect($ctx, "user", "password", {Database => ":memory:"});
  
  # 2. Prepare a statement
  my $sql = "SELECT id, name FROM users WHERE id > ?";
  my $sth = $dbh->prepare($ctx, $sql);
  
  # 3. Execute with bind values
  $sth->execute($ctx, [(object)10]);
  
  # 4. Fetch rows in a while loop (Simple usage)
  while (my $row = $sth->fetch($ctx)) {
    my $id   = $row->[0]->(int);
    my $name = $row->[1]->(string);
    
    # Process the data...
  }

Fast Fetch with Buffer Reuse:

  # Prepare the "vessels" (objects) in advance to avoid allocations inside the loop.
  # Use new_string_len to allocate a string buffer without redundant initialization.
  my $columns = [(object)Int->new(0), new_string_len 100]; 
  my $ret_row = new object[2];
  
  while (my $row = $sth->fetch($ctx, $columns, $ret_row)) {
    # The driver updates the existing objects in $columns.
    # $row is the same as $ret_row.
    my $id   = $row->[0]->(int);
    my $name = $row->[1]->(string);
    
  }

Transaction:

  # Transaction management
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

=head1 Modules

=over 2

=item * L<DBI::St|SPVM::DBI::St> - Statement Handle

=item * L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> - Statement Handle

=item * L<DBI::Constant|SPVM::DBI::Constant> - Information and Capability Constants

=item * L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> - SQLSTATE Exceptions

=back

=head1 Fields

=head2 Username

The username for the database connection. This field stores the username extracted from the DSN.

=head2 Database

C<has Database : ro string;>

The database name.

=head2 Host

C<has Host : ro string;>

The host name of the database server.

=head2 Port

C<has Port : ro int;>

The port number of the database server.

C<has Username : ro string;>

=head2 AutoCommit

C<has AutoCommit : ro byte;>

The AutoCommit status.

=head2 InactiveDestroy

C<has InactiveDestroy : rw byte;>

The InactiveDestroy status.

=head2 IdleTimeout

C<has IdleTimeout : rw double;>

The maximum time in seconds that a connection can remain idle before being closed.

=head2 ConnectTimeout

C<has ConnectTimeout : rw double;>

The timeout value for establishing a new database connection, in seconds.

=head2 ReadTimeout

C<has ReadTimeout : rw double;>

The timeout value for read operations, in seconds.

=head2 WriteTimeout

C<has WriteTimeout : rw double;>

The timeout value for write operations, in seconds.

=head2 SocketKeepAlive

C<has SocketKeepAlive : rw byte;>

A boolean value that indicates whether the TCP keep-alive is enabled. 
If set to 1, C<SO_KEEPALIVE> is enabled on the socket.

If this is not specified, the default value of the underlying L<IO::Socket|SPVM::IO::Socket> is used.

=head2 TCPKeepIdle

C<has TCPKeepIdle : rw int;>

The time in seconds that a connection must be idle before TCP starts sending keep-alive probes.
Note that this setting only takes effect when L</"SocketKeepAlive"> is set to 1.

If this is not specified, the default value of the underlying L<IO::Socket|SPVM::IO::Socket> is used.

=head2 TCPNoDelay

C<has TCPNoDelay : rw byte;>

The TCP_NODELAY status (boolean 1 or 0).

=head1 Class Methods

=head2 blob

C<static method blob : L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> ($value : string);>

Creates a new L<DBI::BindData::Blob|SPVM::DBI::BindData::Blob> object>.

This is a helper method to wrap binary data.

=head1 Instance Methods

=head2 prepare

C<method prepare : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $sql : string, $options : object[] = undef);>

Prepares the SQL statement and returns a statement handle (L<DBI::St|SPVM::DBI::St>).

=head2 begin_work

C<method begin_work : void ($ctx : L<Go::Context|SPVM::Go::Context>);>

Starts a new transaction.

=head2 commit

C<method commit : void ($ctx : L<Go::Context|SPVM::Go::Context>);>

Commits the current transaction.

=head2 rollback

C<method rollback : void ($ctx : L<Go::Context|SPVM::Go::Context>);>

Rolls back the current transaction.

=head2 last_insert_id

C<method last_insert_id : object ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string = undef, $schema : string = undef, $table : string = undef, $field : string = undef, $options : object[] = undef);>

Returns the ID of the last inserted row.

=head2 ping

C<method ping : int ($ctx : L<Go::Context|SPVM::Go::Context>);>

Checks if the database connection is still alive.

=head2 get_info

C<method get_info : object ($ctx : L<Go::Context|SPVM::Go::Context>, $info_type : int);>

Returns information about the database.

=head2 table_info

C<method table_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $type : string, $options : object[] = undef);>

Returns a statement handle containing information about tables.

=head2 column_info

C<method column_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $column : string);>

Returns a statement handle containing information about columns.

=head2 quote

C<method quote : string ($ctx : L<Go::Context|SPVM::Go::Context>, $str : string, $type : int = -1);>

Quotes a string for use in a SQL statement.

=head2 quote_identifier

C<method quote_identifier : string ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $options : object[] = undef);>

Quotes an identifier for use in a SQL statement.

=head2 disconnect

C<method disconnect : void ();>

Disconnects from the database.

=head2 DESTROY

C<method DESTROY : void ();>

The destructor. Unless L</"InactiveDestroy"> is true, it calls L</"disconnect">.

=head1 For Driver Authors

=head2 Extending DBI

The following example shows how to implement a specific database driver (DBD) by extending the L<DBI|SPVM::DBI> class.

  class DBD::MyDriver extends DBI {
    
    # Implement the connect method
    static method connect : DBD::MyDriver ($ctx : Go::Context, $user : string = undef, $password : string = undef, $options : object[] = undef) {
      
      my $self = DBD::MyDriver->new;
      
      # Call the common connection logic provided by the base class.
      # This validates options and stores them into the database handle ($dbh).
      $self->connect_common($dbh, $ctx, $user, $password, $options);
      
      # Implement the driver-specific logic to connect to a database.
      # Apply network-related settings using the values stored in $dbh.
      # ...
      
      return $self;
    }
    
    # Overriding prepare method
    method prepare : DBI::St ($ctx : Go::Context, $sql : string, $options : object[] = undef) {
      
      my $sth = DBD::MyDriver::St->new;
      
      # Call the common preparation logic provided by the base class.
      $self->prepare_common($sth, $ctx, $sql, $options);
      
      # Implement the driver-specific logic to prepare a statement.
      # ...
      
      return $sth;
    }
    
  }

=head2 Implementing connect

When implementing C<connect> method, driver authors are responsible for the following:

C<static method connect : L<DBI|SPVM::DBI> ($ctx : L<Go::Context|SPVM::Go::Context>, $user : string = undef, $password : string = undef, $options : object[] = undef);>

Establishes a connection to the database and returns a database handle (L<DBI|SPVM::DBI>).

The following options can be specified in C<$options>.

=over 4

=item * C<ConnectTimeout>

The maximum time to wait for the database connection to be established, specified in nanoseconds.

=item * C<TCPNoDelay>

A boolean value (0 or 1) to disable Nagle's algorithm. Set to 1 to reduce latency for small packets by sending them immediately.

=item * C<SocketKeepAlive>

The interval for TCP keep-alive probes, specified in nanoseconds. This is useful for maintaining long-lived connections through firewalls or load balancers.

=item * C<IdleTimeout>

The time in seconds a connection can remain idle before it is considered expired and closed by the driver.

=item * C<InactiveDestroy>

A boolean value. If set to 1, the C<disconnect> method will not be called automatically when the database handle object is destroyed.

=back

=head2 Abstract Methods

The following methods are intended to be overridden in child classes. If a method is not overridden, it throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception with SQLSTATE "IM001" (Driver does not support this function):

L</"prepare">, L</"begin_work">, L</"commit">, L</"rollback">, L</"last_insert_id">, L</"ping">, L</"get_info">, L</"table_info">, L</"column_info">, L</"quote">, L</"quote_identifier">, L</"disconnect">.

=head2 Available Instance Methods

=head3 connect_common

C<protected method connect_common : void ($ctx : L<Go::Context|SPVM::Go::Context>, $user : string = undef, $password : string = undef, $options : object[] = undef);>

Provides common initialization logic for a database handle. This method is intended to be called by driver authors within their own C<connect> implementation.

It performs the following tasks:

=over 2

=item *

Validates the option names in C<$options> by calling L<Fn#check_option_names|SPVM::Fn/"check_option_names"> with the names returned by L<option_names|SPVM::DBI/"option_names">.

=item *

Initializes the following fields using the provided arguments and options:

=over 4

=item * C<Username>

Set to the value of C<$user>.

=item * C<Host>, C<Port>, C<Database>

Set to the values of C<Host>, C<Port>, and C<Database> from C<$options> if they exist.

=item * C<AutoCommit>

Always set to 1.

=item * C<InactiveDestroy>, C<TCPNoDelay>

Set to the values of C<InactiveDestroy> and C<TCPNoDelay> from C<$options> if they exist.

=item * C<IdleTimeout>, C<ConnectTimeout>, C<ReadTimeout>, C<WriteTimeout>, C<SocketKeepAlive>

Set to the seconds (as C<double>) from C<$options> if they exist.

=back

=back

=head3 prepare_common

C<protected method prepare_common : void ($sth : L<DBI::St|SPVM::DBI::St>, $ctx : L<Go::Context|SPVM::Go::Context>, $sql : string, $options : object[] = undef);>

Provides common initialization logic for a statement handle. This method is intended to be called by driver authors within their own C<prepare> implementation.

It performs the following tasks:

=over 2

=item *

Validates the option names in C<$options> by calling L<Fn#check_option_names|SPVM::Fn/"check_option_names"> with the names returned by the statement handle's C<option_names> method.

=item *

Initializes the following fields of the statement handle C<$sth>:

=over 4

=item * Database

Set the L<DBI::St#Database|SPVM::DBI::St/"Database"> field to the current database handle (the instance of L<DBI|SPVM::DBI> that called the C<prepare> method).

=item * Statement

Set the L<DBI::St#Statement|SPVM::DBI::St/"Statement"> field to the SQL string provided as C<$sql>.

=back

=back

=head2 Overridable Instance Methods

=head3 option_names

C<protected method option_names : string[] ();>

Returns an array of supported option names for the database handle. In the base class, this returns default options like C<InactiveDestroy>, C<TCPNoDelay> options.

Driver authors can override this method to add driver-specific options. These names are used by L</"connect_common"> or L<prepare_common|SPVM::DBI/"prepare_common"> via L<Fn#check_option_names|SPVM::Fn/"check_option_names">.

Override this method if your database handle supports specific options. These names are used by L</"prepare_common"> to validate the options passed by the user.

=head1 See Also

L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License

