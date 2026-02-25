package SQLite::VecDB::Result;
# ABSTRACT: Search result from SQLite::VecDB
our $VERSION = '0.001';

use Moose;

use overload '""' => sub { $_[0]->id }, fallback => 1;

has id => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);


has distance => (
  is => 'ro',
  isa => 'Num',
);


has metadata => (
  is => 'ro',
  isa => 'HashRef',
  default => sub { {} },
);


has content => (
  is => 'ro',
  isa => 'Str',
  predicate => 'has_content',
);


has vector => (
  is => 'ro',
  isa => 'ArrayRef[Num]',
  predicate => 'has_vector',
);


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SQLite::VecDB::Result - Search result from SQLite::VecDB

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  my @results = $collection->search(vector => [...], limit => 5);

  for my $r (@results) {
    say $r->id;          # 'doc1'
    say $r->distance;    # 0.042
    say $r->metadata;    # { title => 'Hello' }
    say $r->content;     # 'Original text...'
    say "$r";            # 'doc1' (stringifies to id)
  }

=head1 DESCRIPTION

Immutable result object returned by L<SQLite::VecDB::Collection/search>.
Stringifies to C<id>.

=head2 id

The unique identifier of the stored vector.

=head2 distance

The distance from the query vector. Lower means more similar.
The scale depends on the distance metric (cosine: 0..2, l2: 0..inf).

=head2 metadata

The metadata HashRef stored with this vector.

=head2 content

The original text content, if stored.

=head2 vector

The stored vector, if requested.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-sqlite-vecdb/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
