#
# This file is part of App-nioscli
#
# This software is Copyright (c) 2021 by Christian Segundo.
#
# This is free software, licensed under:
#
#   The Artistic License 2.0 (GPL Compatible)
#
## no critic
package App::nioscli::Commands::list_host_records;
$App::nioscli::Commands::list_host_records::VERSION = '0.001';

# VERSION
# AUTHORITY

## use critic
use strictures 2;
use MooseX::App::Command;

extends qw(App::nioscli);

command_short_description 'List HOST Records';

with 'App::nioscli::Roles::Listable';

has 'default_return_fields' => (
  is      => 'ro',
  isa     => 'Str',
  default => "ipv4addrs,name,extattrs"
);

has 'exe' => (
  is      => 'ro',
  isa     => 'CodeRef',
  traits  => ['Code'],
  lazy    => 1,
  default => sub {
    sub { shift->nios_client->list_host_records(@_); }
  },
  handles => {
    call => 'execute'
  }
);

sub run {
  shift->execute;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::nioscli::Commands::list_host_records

=head1 VERSION

version 0.001

=head1 OVERVIEW

List HOST Records.

B<Examples>

=over

=item * List all

    nioscli list-host-records [long options...]

=item * List filtering by name (exact match)

    nioscli list-host-records --filter "name=foo.bar" [long options...]

=item * List filtering by an exact name (regex)

    nioscli list-host-records --filter "name~=^foo" [long options...]

=item * List filtering by extattr

    nioscli list-host-records --filter "*Tenant ID:=foo" [long options...]

=back

=head1 AUTHOR

Christian Segundo <ssmn@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2021 by Christian Segundo.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
