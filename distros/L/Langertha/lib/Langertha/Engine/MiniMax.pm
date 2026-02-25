package Langertha::Engine::MiniMax;
# ABSTRACT: MiniMax API
our $VERSION = '0.202';
use Moose;
use Carp qw( croak );

extends 'Langertha::Engine::OpenAIBase';

with 'Langertha::Role::Tools';


sub _build_supported_operations {[qw(
  createChatCompletion
)]}

has '+url' => (
  lazy => 1,
  default => sub { 'https://api.minimax.io/v1' },
);

sub _build_api_key {
  my ( $self ) = @_;
  return $ENV{LANGERTHA_MINIMAX_API_KEY}
    || croak "".(ref $self)." requires LANGERTHA_MINIMAX_API_KEY or api_key set";
}

sub default_model { 'MiniMax-M2.5' }

__PACKAGE__->meta->make_immutable;


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Langertha::Engine::MiniMax - MiniMax API

=head1 VERSION

version 0.202

=head1 SYNOPSIS

    use Langertha::Engine::MiniMax;

    my $minimax = Langertha::Engine::MiniMax->new(
        api_key => $ENV{MINIMAX_API_KEY},
        model   => 'MiniMax-M2.5',
    );

    print $minimax->simple_chat('Hello from Perl!');

    # Streaming
    $minimax->simple_chat_stream(sub {
        print shift->content;
    }, 'Write a poem');

    # Tool calling works out of the box
    my $response = await $minimax->chat_with_tools_f('Search for Perl modules');

=head1 DESCRIPTION

Provides access to L<MiniMax|https://www.minimax.io/> models via their
OpenAI-compatible API. Composes L<Langertha::Role::OpenAICompatible> with
MiniMax's endpoint (C<https://api.minimax.io/v1>) and API key handling.

MiniMax is a Chinese AI company based in Shanghai, offering large language
models with strong coding, reasoning, and agentic capabilities.

B<Available text models:>

=over 4

=item * C<MiniMax-M2.5> — Latest flagship. 1M context window, $0.30/1M input,
$1.20/1M output. SOTA coding (80.2% SWE-Bench Verified), agentic tool use,
and search.

=item * C<MiniMax-M2.5-highspeed> — Same M2.5 performance with lower latency.
205K context window.

=item * C<MiniMax-M2.1> — 230B total parameters, 10B activated per inference.
Strong multilingual coding and reasoning.

=item * C<MiniMax-M2.1-highspeed> — Same M2.1 performance with lower latency.

=item * C<MiniMax-M2> — 200K context, 128K max output. Function calling and
agentic capabilities.

=back

See L<https://platform.minimax.io/docs/guides/models-intro> for the full
model catalog including audio, video, and music models.

Supports chat, streaming, and tool calling. Embeddings, transcription, and
dynamic model listing (C</v1/models>) are not supported.

B<Coding Plan:> MiniMax offers a Coding Plan subscription with web search
and image understanding APIs for coding workflows. See
L<https://platform.minimax.io/docs/coding-plan/intro>.

Get your API key at L<https://platform.minimax.io/> and set
C<LANGERTHA_MINIMAX_API_KEY> in your environment.

B<THIS API IS WORK IN PROGRESS>

=head1 SEE ALSO

=over

=item * L<https://platform.minimax.io/docs/> - Official MiniMax API documentation

=item * L<Langertha::Role::OpenAICompatible> - OpenAI API format role

=item * L<Langertha::Engine::DeepSeek> - Another OpenAI-compatible engine

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
