package Finance::AMEX::Transaction::GRRCN::Base 0.005;

use strict;
use warnings;

use Text::CSV;
use Carp 'croak';

# ABSTRACT: Parse AMEX Global Reconciliation (GRRCN) Base methods

sub new {
  my ($class, %props) = @_;
  my $self = bless {
    _line         => $props{line},
    _file_format  => $props{file_format},
    _fields       => undef,
    _file_version => $props{file_version} || 1.01,
  }, $class;

  my $map = $self->field_map;

  my $column_number = 0;
  my $numbered      = {};

  foreach my $column (@{$map}) {
    my ($field) = keys %{$column};
    $numbered->{$field} = $column_number++;
  }

  $self->{_fields} = $numbered;

  return $self;
}

sub line {
  my ($self) = @_;
  return $self->{_line};
}

sub file_format {
  my ($self) = @_;
  return $self->{_file_format};
}

sub fields {
  my ($self) = @_;
  return $self->{_fields};
}

sub file_version {
  my ($self) = @_;
  return $self->{_file_version};
}

sub _get_column {
  my ($self, $field) = @_;

  # this will happen if we're trying to get a field that does not
  # exist in the version of the file we are parsing
  return if not exists $self->fields->{$field};

  if ($self->file_format eq 'CSV' or $self->file_format eq 'TSV') {

    # Text::CSV does not like blank space at the end of the line
    $self->{_line} =~ s{\s+\z}{}xsm;
    my $index = $self->fields->{$field};

    my $csv = Text::CSV->new({
      binary      => 1,
      quote_char  => '"',
      escape_char => "\\",
    })
      or croak 'Cannot use CSV: ' . Text::CSV->error_diag();

    if ($self->file_format eq 'TSV') {
      $csv->sep_char("\t");
    }

    if (my $status = $csv->parse($self->{_line})) {
      return ($csv->fields)[$index];
    }

  } elsif ($self->file_format eq 'FIXED') {

    my $column_number = $self->fields->{$field};

    my $map = $self->field_map->{$column_number}->{$field};

    # if the line is not long enough to handle the start of the field,
    # it is an optional field that we don't have
    if (length($self->{_line}) < $map->[0]) {
      return '';
    }

    my $ret = substr($self->{_line}, $map->[0] - 1, $map->[1]);
    $ret =~ s{\s+\z}{}xsm;
    return $ret;
  }
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Finance::AMEX::Transaction::GRRCN::Base - Parse AMEX Global Reconciliation (GRRCN) Base methods

=head1 VERSION

version 0.005

=head1 DESCRIPTION

Don't use this module directly, it is the base module for L<Finance::AMEX::Transaction::GRRCN::Header>, L<Finance::AMEX::Transaction::GRRCN::Summary>, L<Finance::AMEX::Transaction::GRRCN::TaxRecord>, L<Finance::AMEX::Transaction::GRRCN::Submission>, L<Finance::AMEX::Transaction::GRRCN::Transaction>, L<Finance::AMEX::Transaction::GRRCN::TxnPricing>, L<Finance::AMEX::Transaction::GRRCN::Chargeback>, L<Finance::AMEX::Transaction::GRRCN::Adjustment>, L<Finance::AMEX::Transaction::GRRCN::FeeRevenue>, L<Finance::AMEX::Transaction::GRRCN::Trailer>, and L<Finance::AMEX::Transaction::GRRCN::Unknown> objects.

=head1 METHODS

=head2 new

The shared new method.

=head2 line

The shared line method.

=head2 fields

Returns the parsed fields from the child module.

=head2 file_format

Returns the file_format.  Normally this will be auto-detected.

=head2 file_version

Returns the file_version.  Normally this will be auto-detected.

=head1 NAME

Finance::AMEX::Transaction::GRRCN::Base - Shared methods for AMEX reconciliation file records.

=head1 AUTHOR

Tom Heady <cpan@punch.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by ZipRecruiter/Tom Heady.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
