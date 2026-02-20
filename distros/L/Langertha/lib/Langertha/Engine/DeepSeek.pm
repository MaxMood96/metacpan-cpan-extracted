package Langertha::Engine::DeepSeek;
# ABSTRACT: DeepSeek API
our $VERSION = '0.100';
use Moose;
extends 'Langertha::Engine::OpenAI';
use Carp qw( croak );

sub _build_supported_operations {[qw(
  createChatCompletion
)]}

sub all_models {qw(
  deepseek-chat
  deepseek-reasoner
  deepseek-v3.2
)}

has '+url' => (
  lazy => 1,
  default => sub { 'https://api.deepseek.com' },
);
around has_url => sub { 1 };

sub _build_api_key {
  my ( $self ) = @_;
  return $ENV{LANGERTHA_DEEPSEEK_API_KEY}
    || croak "".(ref $self)." requires LANGERTHA_DEEPSEEK_API_KEY or api_key set";
}

sub default_model { 'deepseek-chat' }

sub embedding_request {
  croak "".(ref $_[0])." doesn't support embedding";
}

sub transcription_request {
  croak "".(ref $_[0])." doesn't support transcription";
}

__PACKAGE__->meta->make_immutable;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Engine::DeepSeek - DeepSeek API

=head1 VERSION

version 0.100

=head1 SYNOPSIS

  use Langertha::Engine::DeepSeek;

  my $deepseek = Langertha::Engine::DeepSeek->new(
    api_key => $ENV{DEEPSEEK_API_KEY},
    model => 'deepseek-chat',
    system_prompt => 'You are a helpful assistant',
    temperature => 0.5,
  );

  print($deepseek->simple_chat('Say something nice'));

=head1 DESCRIPTION

This module provides access to DeepSeek's models via their API.

B<Available Models (February 2026):>

=over 4

=item * B<deepseek-chat> - Fast, general-purpose chat model (default). Excellent for most tasks with strong multilingual support.

=item * B<deepseek-reasoner> - Advanced reasoning model with chain-of-thought capabilities. Best for complex problem-solving and logic tasks.

=item * B<deepseek-v3.2> - Latest version with integrated thinking directly into tool-use. Supports tool-use in both thinking and non-thinking modes. Features updated chat template and "thinking with tools" capability.

=back

B<Note:> DeepSeek V4 is expected to launch mid-February 2026 with context windows exceeding 1 million tokens and enhanced codebase processing capabilities.

B<Dynamic Model Listing:> DeepSeek inherits from L<Langertha::Engine::OpenAI>,
so it supports C<list_models()> for dynamic model discovery. See
L<Langertha::Engine::OpenAI> for documentation on model listing and caching.

B<THIS API IS WORK IN PROGRESS>

=head1 HOW TO GET DEEPSEEK API KEY

L<https://platform.deepseek.com/>

=head1 SEE ALSO

=over 4

=item * L<https://api-docs.deepseek.com/> - Official DeepSeek API documentation

=item * L<Langertha::Engine::OpenAI> - Parent class

=item * L<Langertha> - Main Langertha documentation

=back

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
