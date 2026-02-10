package SPVM::DBI::Dr;

1;

=encoding utf8

=head1 Name

SPVM::DBI::Dr - Driver Handle

=head1 Description

L<DBI::Dr|SPVM::DBI::Dr> class in L<SPVM> represents a driver handle. This class is a base class for driver handles, and each method is expected to be overridden in child classes like L<DBD::SQLite::Dr|SPVM::DBD::SQLite::Dr>.

=head1 Usage

  class DBD::MyDriver::Dr extends DBI::Dr {
    
    # Overriding the connect method
    method connect : DBI::Db ($ctx : Go::Context, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef) {
      
      my $dbh = DBD::MyDriver::Db->new;
      
      # Call the common connection logic provided by the base class
      $self->connect_common($dbh, $ctx, $dsn, $user, $password, $options);
      
      # Implement the driver-specific logic to connect to a database
      # ...
      
      return $dbh;
    }
    
  }

=head1 Instance Methods

=head2 connect

C<method connect : L<DBI::Db|SPVM::DBI::Db> ($ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

In a child class, this method must establish a database connection and return a database handle (L<DBI::Db|SPVM::DBI::Db>).

Exceptions:

Always throws a L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> exception whose message begins with a 5-character SQLSTATE "IM001" because this method is not implemented.

=head2 connect_common

C<protected method connect_common : void ($dbh : L<DBI::Db|SPVM::DBI::Db>, $ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

This method provides common initialization logic for a database handle. It is intended to be called by driver authors within their C<connect> implementation.

This method performs the following tasks:

=over 2

=item 1.

Validates the option names in C<$options> using L<option_names|SPVM::DBI::Db/"option_names">.

=item 2.

Parses the DSN to extract the database name and username.

=item 3.

Sets the L<AutoCommit|SPVM::DBI::Db/"AutoCommit"> field of C<$dbh> to 1.

=item 4.

If an option exists in C<$options>, its value is mapped to the corresponding field in C<$dbh>. The mapped fields include:

=over 2

=item * L<InactiveDestroy|SPVM::DBI::Db/"InactiveDestroy">

=item * L<IdleTimeoutDurationNsec|SPVM::DBI::Db/"IdleTimeoutDurationNsec">

=item * L<ConnectTimeoutDurationNsec|SPVM::DBI::Db/"ConnectTimeoutDurationNsec">

=item * L<ReadTimeoutDurationNsec|SPVM::DBI::Db/"ReadTimeoutDurationNsec">

=item * L<WriteTimeoutDurationNsec|SPVM::DBI::Db/"WriteTimeoutDurationNsec">

=item * L<SocketKeepAliveDurationNsec|SPVM::DBI::Db/"SocketKeepAliveDurationNsec">

=item * L<TCPNoDelay|SPVM::DBI::Db/"TCPNoDelay">

=back

By using C<exists> check internally, this method allows driver authors to distinguish whether a field was explicitly set by the user or should be initialized with a modern default.

=back

=head2 option_names

C<protected method option_names : string[] ()>

Returns an array of supported option names for the database handle.

In the base class L<DBI::Db|SPVM::DBI::Db>, this method returns the following default options:

=over 2

=item * C<InactiveDestroy>

=item * C<IdleTimeoutDurationNsec>

=item * C<ConnectTimeoutDurationNsec>

=item * C<ReadTimeoutDurationNsec>

=item * C<WriteTimeoutDurationNsec>

=item * C<SocketKeepAliveDurationNsec>

=item * C<TCPNoDelay>

=back

Driver authors can override this method to add driver-specific options. These names are used by L<connect_common|SPVM::DBI::Dr/"connect_common"> or L<prepare_common|SPVM::DBI::Db/"prepare_common"> to validate the options provided by the user via L<Fn#check_option_names|SPVM::Fn/"check_option_names">.

=head1 See Also

L<DBI|SPVM::DBI>, L<DBI::Db|SPVM::DBI::Db>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
