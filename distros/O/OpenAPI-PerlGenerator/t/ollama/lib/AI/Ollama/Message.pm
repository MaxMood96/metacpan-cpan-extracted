package AI::Ollama::Message 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

AI::Ollama::Message -

=head1 SYNOPSIS

  my $obj = AI::Ollama::Message->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< content >>

The content of the message

=cut

has 'content' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head2 C<< images >>

(optional) a list of Base64-encoded images to include in the message (for multimodal models such as llava)

=cut

has 'images' => (
    is       => 'ro',
    isa      => ArrayRef[Str],
);

=head2 C<< role >>

The role of the message

=cut

has 'role' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);


1;
