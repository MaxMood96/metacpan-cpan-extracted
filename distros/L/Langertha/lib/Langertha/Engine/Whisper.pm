package Langertha::Engine::Whisper;
# ABSTRACT: Whisper compatible transcription server
our $VERSION = '0.100';
use Moose;
use Carp qw( croak );

extends 'Langertha::Engine::OpenAI';

sub default_transcription_model { '' }

has '+url' => (
  required => 1,
);

sub _build_api_key { 'whisper' }

sub _build_supported_operations {[qw(
  createTranscription
  createTranslation
)]}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Engine::Whisper - Whisper compatible transcription server

=head1 VERSION

version 0.100

=head1 SYNOPSIS

  use Langertha::Engine::Whisper;

  my $whisper = Langertha::Engine::Whisper->new(
    url => $ENV{WHISPER_URL},
  );

  print($whisper->simple_transcription('recording.ogg'));

=head1 DESCRIPTION

B<THIS API IS WORK IN PROGRESS>

=head1 HOW TO INSTALL FASTER WHISPER

L<https://github.com/fedirz/faster-whisper-server>

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
