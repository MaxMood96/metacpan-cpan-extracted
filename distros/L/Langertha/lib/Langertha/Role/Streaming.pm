package Langertha::Role::Streaming;
# ABSTRACT: Role for streaming support
our $VERSION = '0.100';
use Moose::Role;

requires qw(
  json
  parse_stream_chunk
  stream_format
);

use Langertha::Stream;
use Langertha::Stream::Chunk;

sub parse_sse_line {
  my ($self, $line) = @_;

  return undef if !defined $line || $line eq '';
  return undef if $line =~ /^:\s*/; # SSE comment

  if ($line =~ /^data:\s*(.*)$/) {
    my $data = $1;
    return { type => 'done' } if $data eq '[DONE]';
    return undef if $data eq '';
    return { type => 'data', data => $self->json->decode($data) };
  }

  if ($line =~ /^event:\s*(.*)$/) {
    return { type => 'event', event => $1 };
  }

  return undef;
}

sub parse_ndjson_line {
  my ($self, $line) = @_;

  return undef if !defined $line || $line eq '';

  my $data = $self->json->decode($line);
  return { type => 'data', data => $data };
}

sub process_stream_data {
  my ($self, $data, $chunk_callback) = @_;

  my @chunks;
  my $format = $self->stream_format;
  my $buffer = '';
  my $current_event = undef;

  my @lines = split /\r?\n/, $data;

  for my $line (@lines) {
    if ($format eq 'sse') {
      if ($line eq '') {
        # Empty line marks end of SSE event
        next;
      }

      my $parsed = $self->parse_sse_line($line);
      next unless $parsed;

      if ($parsed->{type} eq 'event') {
        $current_event = $parsed->{event};
      } elsif ($parsed->{type} eq 'done') {
        # Stream complete
        last;
      } elsif ($parsed->{type} eq 'data') {
        my $chunk = $self->parse_stream_chunk($parsed->{data}, $current_event);
        if ($chunk) {
          push @chunks, $chunk;
          $chunk_callback->($chunk) if $chunk_callback;
        }
        $current_event = undef;
      }
    } elsif ($format eq 'ndjson') {
      next if $line eq '';

      my $parsed = $self->parse_ndjson_line($line);
      next unless $parsed && $parsed->{type} eq 'data';

      my $chunk = $self->parse_stream_chunk($parsed->{data});
      if ($chunk) {
        push @chunks, $chunk;
        $chunk_callback->($chunk) if $chunk_callback;
      }
    }
  }

  return \@chunks;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Role::Streaming - Role for streaming support

=head1 VERSION

version 0.100

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/langertha/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de> L<https://raudss.us/>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
