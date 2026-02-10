package SPVM::DBI;

our $VERSION = "0.002";

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
  
  # 3. Execute with bind values (Box primitives using (object))
  $sth->execute($ctx, [(object)10]);
  
  # 4. Fetch rows in a while loop
  while (my $row = $sth->fetchrow_array($ctx)) {
    my $id = $row->[0]->(int);
    my $name = $row->[1]->(string);
    
    # Process the data...
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

A cache for driver handles. The keys are driver names (e.g., "SQLite"), and the values are their corresponding driver handle objects (L<DBI::Dr|SPVM::DBI::Dr>). This cache is used by L</"connect"> to reuse existing driver instances.

=head1 Class Methods

=head2 connect

C<static method connect : L<DBI::Db|SPVM::DBI::Db> ($ctx : L<Go::Context|SPVM::Go::Context>, $dsn : string, $user : string = undef, $password : string = undef, $options : object[] = undef)>

Establishes a connection to the database specified by the C<$dsn>.

This method performs the following:

=over 2

=item 1.

Parses the C<$dsn> to identify the driver name (e.g., "SQLite" in "dbi:SQLite:...").

=item 2.

Checks the internal driver cache L</"$DRIVERS_H">. If an instance of the driver already exists, it is reused.

=item 3.

If the driver is not cached, it loads the corresponding driver class (e.g., C<DBD::SQLite>), creates a new instance, and stores it in the L</"$DRIVERS_H"> cache for future use.

=item 4.

Calls the L<connect|SPVM::DBI::Dr/"connect"> method of the driver and returns a database handle (L<DBI::Db|SPVM::DBI::Db>).

=back

C<$options> is an array of key-value pairs. Supported options are defined in L<option_names|SPVM::DBI::Db/"option_names">.

Exceptions:

=over 2

=item *

If C<$dsn> is not defined.

=item *

If the DSN format is invalid.

=item *

If the driver class cannot be loaded or an error occurs during connection.

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
