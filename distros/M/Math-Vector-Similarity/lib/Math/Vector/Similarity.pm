package Math::Vector::Similarity;
# ABSTRACT: Cosine similarity, euclidean distance and other vector comparison functions
our $VERSION = '0.001';

use strict;
use warnings;
use Carp qw( croak );
use Exporter 'import';

our @EXPORT_OK = qw(
  cosine_similarity
  cosine_distance
  euclidean_distance
  dot_product
  normalize
);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub dot_product {
  my ( $a, $b ) = @_;
  croak "vectors must have same dimensions"
    unless @$a == @$b;
  my $sum = 0;
  $sum += $a->[$_] * $b->[$_] for 0..$#$a;
  return $sum;
}


sub normalize {
  my ( $vec ) = @_;
  my $norm = 0;
  $norm += $_ * $_ for @$vec;
  $norm = sqrt($norm);
  return $vec if $norm == 0;
  return [ map { $_ / $norm } @$vec ];
}


sub cosine_similarity {
  my ( $a, $b ) = @_;
  croak "vectors must have same dimensions"
    unless @$a == @$b;
  my ( $dot, $norm_a, $norm_b ) = ( 0, 0, 0 );
  for my $i (0..$#$a) {
    $dot    += $a->[$i] * $b->[$i];
    $norm_a += $a->[$i] * $a->[$i];
    $norm_b += $b->[$i] * $b->[$i];
  }
  my $denom = sqrt($norm_a) * sqrt($norm_b);
  return 0 if $denom == 0;
  return $dot / $denom;
}


sub cosine_distance {
  my ( $a, $b ) = @_;
  return 1 - cosine_similarity($a, $b);
}


sub euclidean_distance {
  my ( $a, $b ) = @_;
  croak "vectors must have same dimensions"
    unless @$a == @$b;
  my $sum = 0;
  for my $i (0..$#$a) {
    my $d = $a->[$i] - $b->[$i];
    $sum += $d * $d;
  }
  return sqrt($sum);
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Math::Vector::Similarity - Cosine similarity, euclidean distance and other vector comparison functions

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use Math::Vector::Similarity qw( cosine_similarity cosine_distance );

  my $vec_a = [0.1, 0.2, 0.3];
  my $vec_b = [0.1, 0.25, 0.28];

  say cosine_similarity($vec_a, $vec_b);  # 0.998...
  say cosine_distance($vec_a, $vec_b);    # 0.001...

  # Compare embeddings from any source
  my $emb1 = $engine->simple_embedding("Perl programming");
  my $emb2 = $engine->simple_embedding("Python programming");
  my $emb3 = $engine->simple_embedding("Italian cooking");

  say cosine_similarity($emb1, $emb2);  # high — both programming
  say cosine_similarity($emb1, $emb3);  # low  — different topics

  # Import everything
  use Math::Vector::Similarity qw( :all );

  my $unit = normalize($vec_a);
  my $dp   = dot_product($vec_a, $vec_b);
  my $ed   = euclidean_distance($vec_a, $vec_b);

=head1 DESCRIPTION

Lightweight pure-Perl functions for comparing numeric vectors. Works on
plain ArrayRefs of any dimensionality, with zero dependencies.

Designed for comparing embedding vectors from LLM APIs (OpenAI, Ollama,
etc.), but works for any numeric vectors.

=head2 dot_product

  my $dp = dot_product($vec_a, $vec_b);

Returns the dot product (inner product) of two vectors.

=head2 normalize

  my $unit = normalize($vec);

Returns a new unit vector (L2-normalized). Returns the original vector
unchanged if its magnitude is zero.

=head2 cosine_similarity

  my $sim = cosine_similarity($vec_a, $vec_b);

Returns the cosine similarity between two vectors. Range: -1 to 1.
A value of 1 means identical direction, 0 means orthogonal, -1 means
opposite direction.

=head2 cosine_distance

  my $dist = cosine_distance($vec_a, $vec_b);

Returns the cosine distance: C<1 - cosine_similarity>. Range: 0 to 2.
This is the metric used by sqlite-vec and many vector databases when
configured with C<distance_metric=cosine>.

=head2 euclidean_distance

  my $dist = euclidean_distance($vec_a, $vec_b);

Returns the Euclidean (L2) distance between two vectors.

=head1 EXPORTED FUNCTIONS

Nothing is exported by default. Use C<:all> to import everything, or
import individual functions by name.

=head1 SEE ALSO

=over

=item * L<PDL> - For heavy-duty numeric computation on large datasets

=item * L<Math::Vector::Real> - OOP vector math with blessed objects

=back

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-math-vector-similarity/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
