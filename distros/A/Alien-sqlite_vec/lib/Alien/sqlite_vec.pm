package Alien::sqlite_vec;
# ABSTRACT: sqlite-vec SQLite extension for vector search
our $VERSION = '0.001';

use parent 'Alien::Base';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Alien::sqlite_vec - sqlite-vec SQLite extension for vector search

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use Alien::sqlite_vec;
  use DBI;

  my $dbh = DBI->connect("dbi:SQLite:dbname=:memory:");
  $dbh->sqlite_enable_load_extension(1);

  my ($vec_path) = Alien::sqlite_vec->dynamic_libs;
  $dbh->do("SELECT load_extension(?)", {}, $vec_path);

=head1 DESCRIPTION

Provides the L<sqlite-vec|https://github.com/asg017/sqlite-vec> extension
for SQLite. sqlite-vec enables fast vector search (KNN) directly inside
SQLite using virtual tables.

This module downloads and compiles the sqlite-vec v0.1.6 amalgamation from
source, making the compiled extension available via
C<< Alien::sqlite_vec->dynamic_libs >>.

=head1 SEE ALSO

=over

=item * L<SQLite::VecDB> - High-level vector database API using sqlite-vec

=item * L<https://github.com/asg017/sqlite-vec> - sqlite-vec project

=back

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-alien-sqlite-vec/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
