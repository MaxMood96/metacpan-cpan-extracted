package Uniform::Utils;

use strict;
use warnings;
use Exporter 'import';
use Carp qw(croak);
use Uniform::Exceptions; # PULL IN THE EXCEPTION ENGINE

our $VERSION = '1.02';
our @EXPORT_OK = qw(normalize_http_headers parse_size_limit);

# Shared production-grade normalization engine utilized by all Uniform distributions
sub normalize_http_headers {
    my ($hash) = @_;

    unless (ref($hash) eq 'HASH') {
        Uniform::Exceptions->throw(
            type      => 'TypeError',
            message   => 'Normalization input context must be a strict HASH reference',
            attribute => 'hash_input',
        );
    }

    my (%normalized, %priority);

    for my $key (keys %$hash) {
        next unless defined $key;
        my $val = $hash->{$key};

        my $norm = lc "$key";
        $norm =~ s/^\s+|\s+$//g;

        my $is_http_env = $norm =~ s/^http[-_]//;
        my $rank = ($is_http_env ? 0 : 2) + ($norm =~ /-/ ? 1 : 0);

        $norm =~ tr/_/-/;
        $norm =~ s/-+/-/g;

        # Guard clause: Ignore unrelated, malformed, or hostile names.
        # This prevents a bogus key from colliding with valid metadata after normalization.
        next unless $norm =~ /\Ahx-[a-z0-9]+(?:-[a-z0-9]+)*\z/;

        # Some adapters preserve duplicate headers as an array reference.
        # HTTP specs define these fields as single values, so the last defined value wins.
        if (ref($val) eq 'ARRAY') {
            ($val) = reverse grep { defined && !ref } @$val;
        }
        next if ref $val;

        # Prioritize real HTTP header spellings over CGI/PSGI environment spellings
        # if an adapter accidentally supplies both down the pipeline.
        next if exists($priority{$norm}) && $priority{$norm} > $rank;

        $normalized{$norm} = $val;
        $priority{$norm} = $rank;
    }

    return \%normalized;
}

# Shared human-readable size string parser utilized by any Uniform distribution
# that needs to compare a byte count against a configured limit (upload size
# caps, request body size caps, etc).
sub parse_size_limit {
    my ($limit) = @_;

    unless (defined $limit && length $limit) {
        Uniform::Exceptions->throw(
            type      => 'ValidationError',
            message   => 'parse_size_limit requires a defined, non-empty size string (e.g. "2M") or a plain byte count',
            attribute => 'limit',
        );
    }

    my %multiplier = ( K => 1024, M => 1024**2, G => 1024**3 );
    my ($num, $unit) = $limit =~ /^([\d.]+)\s*([KMG]?)$/i;

    unless (defined $num) {
        Uniform::Exceptions->throw(
            type      => 'ValidationError',
            message   => "parse_size_limit received an unparsable size string: '$limit'",
            attribute => 'limit',
        );
    }

    return $unit ? $num * $multiplier{uc $unit} : $num;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform::Utils - Shared production-grade utility functions for Uniform ecosystem authors

=head1 FUNCTIONS

=head2 normalize_http_headers( \%raw_hash )

Accepts a raw hash reference of incoming network parameters and transforms them into a
clean, normalized data model based on strict ecosystem validation criteria:

=over 4

=item * B<Case Insensitivity>: All incoming keys are lowercased and bounding whitespace is stripped.

=item * B<Environment Pruning>: CGI/PSGI C<HTTP_> and C<HTTP-> environment prefixes are safely removed.

=item * B<Priority Ranking>: Real HTTP header definitions cleanly take precedence over environment-variable duplicates.

=item * B<Array Reduction>: Duplicate incoming headers packed into array references are automatically reduced down to the last scalar definition.

=item * B<Security Sandboxing>: Keys failing structural validation checks are rejected entirely, filtering out malicious header manipulation or collision vectors.

=back

=head2 parse_size_limit( $limit )

Converts a human-readable size string into a plain byte count. C<$limit> may be a
number of bytes on its own, or a number followed by a C<K>, C<M>, or C<G> suffix
(case-insensitive, 1024-based: kilobytes, megabytes, gigabytes) -- e.g. C<'500K'>,
C<'2M'>, C<'1G'>, or a bare C<'2048'>.

Throws a C<ValidationError> via L<Uniform::Exceptions> if C<$limit> is undefined,
an empty string, or does not match a parsable size expression. Returns the
equivalent byte count as a plain number on success.

    use Uniform::Utils qw(parse_size_limit);

    my $bytes = parse_size_limit('2M'); # 2097152

=cut
