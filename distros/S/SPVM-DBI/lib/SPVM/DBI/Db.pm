package SPVM::DBI::Db;

1;

=encoding utf8

=head1 Name

SPVM::DBI::Db - Database Handle

=head1 Description

L<DBI::Db|SPVM::DBI::Db> class in L<SPVM> represents a database handle. This class is a base class for database handles, and each method is expected to be overridden in child classes like L<DBI::Db::SQLite|SPVM::DBI::Db::SQLite>.

=head1 Usage

  class DBD::MyDriver::Db extends DBI::Db {
    
    # Overriding the prepare method
    method prepare : DBI::St ($ctx : Go::Context, $sql : string, $options : object[] = undef) {
      
      my $sth = DBD::MyDriver::St->new;
      
      # Call the common preparation logic provided by the base class
      $self->prepare_common($sth, $ctx, $sql, $options);
      
      # Implement the driver-specific logic to prepare a statement
      # ...
      
      return $sth;
    }
    
  }

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

The default value is set to 1. Driver authors must ensure that the initial database connection state matches this default (i.e., transactions are automatically committed after each statement).

=head2 InactiveDestroy

C<has InactiveDestroy : rw byte;>

The InactiveDestroy status.

=head2 IdleTimeoutDurationNsec

C<has IdleTimeoutDurationNsec : rw long;>

The maximum duration that a connection can remain idle, in nanoseconds. If the idle time exceeds this duration, the connection is expected to be closed, typically by a connection pool.

=head2 ConnectTimeoutDurationNsec

C<has ConnectTimeoutDurationNsec : rw long;>

The timeout value for establishing a new database connection, in nanoseconds.

=head2 ReadTimeoutDurationNsec

C<has ReadTimeoutDurationNsec : rw long;>

The timeout value for read operations, in nanoseconds. If a read operation does not complete within this duration, the operation is canceled.

=head2 WriteTimeoutDurationNsec

C<has WriteTimeoutDurationNsec : rw long;>

The timeout value for write operations, in nanoseconds. If a write operation does not complete within this duration, the operation is canceled.

=head2 SocketKeepAliveDurationNsec

C<has SocketKeepAliveDurationNsec : rw long;>

The duration for TCP keep-alive idle time, in nanoseconds. 

If this field is not explicitly set, it is recommended that the driver calls L<apply_modern_tcp_settings|SPVM::IO::Socket/"apply_modern_tcp_settings"> (or a similar method) to apply the modern default value. Set to 0 to explicitly disable keep-alive.

=head2 TCPNoDelay

C<has TCPNoDelay : rw byte;>

The TCP_NODELAY status. 

A boolean value (1 or 0). If this field is not explicitly set, it is recommended that the driver calls L<apply_modern_tcp_settings|SPVM::IO::Socket/"apply_modern_tcp_settings"> (or a similar method) to apply the modern default (usually 1). If set to 1, Nagle's algorithm is disabled, which ensures that small database query packets are sent immediately without delay.

=head1 Instance Methods

=head2 prepare

C<method prepare : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $sql : string, $options : object[] = undef)>

In a child class, this method must prepare the SQL statement and return a statement handle (L<DBI::St|SPVM::DBI::St>).

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 begin_work

C<method begin_work : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must start a new transaction.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 commit

C<method commit : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must commit the current transaction.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 rollback

C<method rollback : void ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must roll back the current transaction.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 last_insert_id

C<method last_insert_id : object ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string = undef, $schema : string = undef, $table : string = undef, $field : string = undef, $options : object[] = undef)>

In a child class, this method must return the ID of the last inserted row.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 ping

C<method ping : int ($ctx : L<Go::Context|SPVM::Go::Context>)>

In a child class, this method must check if the database connection is still alive.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 get_info

C<method get_info : object ($ctx : L<Go::Context|SPVM::Go::Context>, $info_type : int)>

In a child class, this method must return information about the database.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 table_info

C<method table_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $type : string, $options : object[] = undef)>

In a child class, this method must return a statement handle containing information about tables.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 column_info

C<method column_info : L<DBI::St|SPVM::DBI::St> ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $column : string)>

In a child class, this method must return a statement handle containing information about columns.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 quote

C<method quote : string ($ctx : L<Go::Context|SPVM::Go::Context>, $str : string, $type : int = -1)>

In a child class, this method must quote a string for use in a SQL statement.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 quote_identifier

C<method quote_identifier : string ($ctx : L<Go::Context|SPVM::Go::Context>, $catalog : string, $schema : string, $table : string, $options : object[] = undef)>

In a child class, this method must quote an identifier for use in a SQL statement.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 disconnect

C<method disconnect : void ()>

In a child class, this method is expected to disconnect from the database.

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 DESTROY

C<method DESTROY : void ()>

The destructor. Unless L</"InactiveDestroy"> is true, it calls L</"disconnect">.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::St|SPVM::DBI::St>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
