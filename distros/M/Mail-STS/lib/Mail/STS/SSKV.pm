package Mail::STS::SSKV;

use Moose::Role;

our $VERSION = '0.05'; # VERSION
# ABSTRACT: role for semicolon-separated key/value pairs

requires 'fields';

sub new_from_string {
  my ($class, $string) = @_;
  my @assignments = split(/\s*;\s*/, $string);
  my %kv;
  foreach my $assignment (@assignments) {
    if ($assignment !~ /=/) {
      next;
    }
    my ($key, $value) = split(/=/, $assignment, 2);
    $kv{$key} = $value;
  }
  if (! keys(%kv)) {
    return;
  }
  return $class->new(%kv);
}

sub as_string {
  my $self = shift;
  return join(' ',
    map { $_."=".$self->$_.";" } grep { defined $self->$_ } @{$self->fields}
  );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mail::STS::SSKV - role for semicolon-separated key/value pairs

=head1 VERSION

version 0.05

=head1 AUTHOR

Markus Benning <ich@markusbenning.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Markus Benning <ich@markusbenning.de>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
