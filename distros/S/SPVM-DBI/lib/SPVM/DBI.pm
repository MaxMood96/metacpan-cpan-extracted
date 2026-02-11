package SPVM::DBI;

our $VERSION = "0.003";

1;

=encoding utf8

=head1 Name

SPVM::DBI - Database Independent Interface

=head1 Description

L<DBI|SPVM::DBI> class in L<SPVM> provides a database-independent interface for database connections. It acts as a factory to create a database handle (L<DBI::Db|SPVM::DBI::Db>) by loading the appropriate driver (L<DBI::Dr|SPVM::DBI::Dr>).

=head1 Caution

B<SPVM::DBI is under early development. This is an alpha release.>

This module is not yet tested and is in a highly experimental stage. The interface and implementation are subject to change without notice. Use this module at your own risk. It is not recommended for production use.

=head1 Usage

  use DBI;
  use DBD::SQLite;
  use Go::Context;
  
  my $ctx = Go::Context->new;
  my $dsn = "dbi:SQLite:dbname=:memory:";
  
  # 1. Connect to a database
  my $dbh = DBI->connect($ctx, $dsn, "user", "password");
  
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

  # 5. Fast fetch with buffer reuse (Zero-allocation)
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

=head1 Modules

=over 2

=item * L<DBI::Dr|SPVM::DBI::Dr> - Driver Handle

=item * L<DBI::Db|SPVM::DBI::Db> - Database Handle

=item * L<DBI::St|SPVM::DBI::St> - Statement Handle

=item * L<DBI::Constant|SPVM::DBI::Constant> - Information and Capability Constants

=item * L<DBI::Error::SQLState|SPVM::DBI::Error::SQLState> - SQLSTATE Exceptions

=back

=head1 Class Variables

=head2 $DRIVERS_H

C<our $DRIVERS_H : cache L<Hash|SPVM::Hash> of L<DBI::Dr|SPVM::DBI::Dr>;>

A cache for driver handles.

=head1 Class Methods

=head2 connect

C<static method connect : L<DBI::Db|SPVM::DBI::Db> ($ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

Establishes a connection to the database specified by the C<$dsn>.

For more information about the available options that can be passed in C<$options> (such as timeouts and TCP settings), please see the L<DBI::Dr#connect|SPVM::DBI::Dr/"connect"> method.

This method performs the following steps:

=over 2

=item 1. DSN Parsing

Validates the C<$dsn> and parses it to extract the driver name (e.g., extracting "SQLite" from "dbi:SQLite:dbname=:memory:").

=item 2. Driver Resolution

Checks the internal cache L</"$DRIVERS_H">. If the driver (e.g., C<DBD::SQLite>) is already loaded, it reuses the existing driver instance.

=item 3. Dynamic Driver Creation

If the driver is not in the cache, creates a new instance of the driver class calling C<new> method. The new instance is then stored in the cache.

=item 4. Handover to Driver

Calls the L<connect|SPVM::DBI::Dr/"connect"> method of the resolved driver handle (L<DBI::Dr|SPVM::DBI::Dr>) to obtain a database handle (L<DBI::Db|SPVM::DBI::Db>).

=back

=head1 See Also

L<DBI::Db|SPVM::DBI::Db>, L<DBI::Dr|SPVM::DBI::Dr>, L<Go::Context|SPVM::Go::Context>

=head1 Repository

L<https://github.com/yuki-kimoto/SPVM-DBI>

=head1 Author

Yuki Kimoto C<kimoto.yuki@gmail.com>

=head1 Copyright & License

Copyright (c) 2026 Yuki Kimoto

MIT License
