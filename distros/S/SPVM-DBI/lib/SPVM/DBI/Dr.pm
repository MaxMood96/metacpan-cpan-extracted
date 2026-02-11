package SPVM::DBI::Dr;

1;

=encoding utf8

=head1 Name

SPVM::DBI::Dr - Driver Handle

=head1 Description

L<DBI::Dr|SPVM::DBI::Dr> class in L<SPVM> represents a driver handle. 

This class is a base class for database driver handles, and each method is expected to be overridden in child classes like L<DBD::SQLite::Dr|SPVM::DBD::SQLite::Dr>.

Note that this class is intended for driver authors. General users should not use this class directly; instead, use the L<DBI|SPVM::DBI> class to establish a connection.

=head1 Instance Methods

=head2 connect

C<method connect : L<DBI::Db|SPVM::DBI::Db> ($ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

Establishes a connection to the database specified by the C<$dsn> and returns a database handle (L<DBI::Db|SPVM::DBI::Db>).

The following options can be specified in C<$options>.

=over 4

=item * C<ConnectTimeoutDurationNsec>

The maximum time to wait for the database connection to be established, specified in nanoseconds.

=item * C<TCPNoDelay>

A boolean value (0 or 1) to disable Nagle's algorithm. Set to 1 to reduce latency for small packets by sending them immediately.

=item * C<SocketKeepAliveDurationNsec>

The interval for TCP keep-alive probes, specified in nanoseconds. This is useful for maintaining long-lived connections through firewalls or load balancers.

=item * C<IdleTimeoutDurationNsec>

The duration a connection can remain idle before it is considered expired and closed by the driver, specified in nanoseconds.

=item * C<InactiveDestroy>

A boolean value. If set to 1, the C<disconnect> method will not be called automatically when the database handle object is destroyed.

=back

=head2 connect_common

C<protected method connect_common : void ($dbh : L<DBI::Db|SPVM::DBI::Db>, $ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

Provides common initialization logic for a database handle, such as parsing the DSN and mapping options to fields.

=head2 option_names

C<protected method option_names : string[] ()>

Returns an array of supported option names for the database handle.

=head1 For Driver Authors

=head2 Extending DBI::Dr

The following example shows how to implement a specific database driver (DBD) by extending the L<DBI::Dr|SPVM::DBI::Dr> class.

  class DBD::MyDriver::Dr extends DBI::Dr {
    
    # Overriding the connect method
    method connect : DBI::Db ($ctx : Go::Context, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef) {
      
      my $dbh = DBD::MyDriver::Db->new;
      
      # Call the common connection logic provided by the base class.
      # This validates options and stores them into the database handle ($dbh).
      $self->connect_common($dbh, $ctx, $dsn, $user, $password, $options);
      
      # Implement the driver-specific logic to connect to a database.
      # Apply network-related settings using the values stored in $dbh.
      # ...
      
      return $dbh;
    }
    
  }

=head2 Abstract Methods

The following method is intended to be overridden in child classes. If it is not overridden, it throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception with SQLSTATE "IM001" (Driver does not support this function):

L</"connect">.

=head2 Implementing connect

When implementing L</"connect">, driver authors are responsible for the following:

=over 2

=item * B<Option Validation>: Call L</"connect_common"> to validate and store options in the L<DBI::Db|SPVM::DBI::Db> instance.

=item * B<Network Settings>: Apply C<TCPNoDelay> (TCP_NODELAY), C<ConnectTimeoutDurationNsec> (dialer deadline), and C<SocketKeepAliveDurationNsec> (TCP keep-alive) to the actual socket.

=item * B<Modern Defaults>: If network options are not provided in C<$options>, call C<apply_modern_tcp_settings> from L<IO::Socket|SPVM::IO::Socket> to ensure optimized default behavior.

=item * B<Idle Management>: Use C<IdleTimeoutDurationNsec> to set the timeout of the L<IO::Socket|SPVM::IO::Socket> to prevent resource leaks.

=item * B<Handle Cleanup>: Ensure the C<InactiveDestroy> value is correctly set in the database handle so that C<DESTROY> behaves as expected.

=back

=head2 How to use connect_common

This method provides common initialization logic for a database handle. It is intended to be called by driver authors within their C<connect> implementation.

It performs the following tasks:

=over 2

=item 1.

Validates the option names in C<$options> using L<option_names|SPVM::DBI::Db/"option_names">.

=item 2.

Parses the DSN to extract the database name and username.

=item 3.

Sets the L<AutoCommit|SPVM::DBI::Db/"AutoCommit"> field of C<$dbh> to 1.

=item 4.

Maps values from C<$options> to the corresponding fields in C<$dbh> (e.g., C<InactiveDestroy>, C<TCPNoDelay>, and various timeout durations).

=back

=head2 Overriding option_names

Returns an array of supported option names for the database handle. In the base class, this returns default options like C<InactiveDestroy>, C<TCPNoDelay>, and several C<*DurationNsec> options.

Driver authors can override this method to add driver-specific options. These names are used by L</"connect_common"> or L<prepare_common|SPVM::DBI::Db/"prepare_common"> via L<Fn#check_option_names|SPVM::Fn/"check_option_names">.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::Db|SPVM::DBI::Db>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
