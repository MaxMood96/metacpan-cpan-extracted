package Archive::BagIt::Role::Plugin;
use strict;
use warnings;
use Moo::Role;
use namespace::autoclean;
# ABSTRACT: A role that handles plugin loading
our $VERSION = '0.101'; # VERSION

has plugin_name => (
  is  => 'ro',
  #isa => 'Str',
  default => __PACKAGE__,
);


has bagit => (
  is  => 'ro',
  #isa => 'Archive::BagIt',
  required => 1,
  weak_ref => 1,
);

sub BUILD {
    my ($self) = @_;
    my $plugin_name = $self->plugin_name;
    $self->bagit->plugins( { $plugin_name => $self });
    return 1;
}
no Moo;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Archive::BagIt::Role::Plugin - A role that handles plugin loading

=head1 VERSION

version 0.101

=head2 bagit()

holds the current bag object as weak reference

=head1 AVAILABILITY

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/Archive::BagIt/>.

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<http://rt.cpan.org>.

=head1 AUTHOR

Andreas Romeyke <cpan@andreas.romeyke.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by Rob Schmidt <rjeschmi@gmail.com>, William Wueppelmann and Andreas Romeyke.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
