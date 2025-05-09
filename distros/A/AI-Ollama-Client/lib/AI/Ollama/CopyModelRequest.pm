package AI::Ollama::CopyModelRequest 0.05;
# DO NOT EDIT! This is an autogenerated file.

use 5.020;
use Moo 2;
use experimental 'signatures';
use stable 'postderef';
use Types::Standard qw(Enum Str Bool Num Int HashRef ArrayRef);
use MooX::TypeTiny;

use namespace::clean;

=encoding utf8

=head1 NAME

AI::Ollama::CopyModelRequest -

=head1 SYNOPSIS

  my $obj = AI::Ollama::CopyModelRequest->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< destination >>

Name of the new model.

=cut

has 'destination' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head2 C<< source >>

Name of the model to copy.

=cut

has 'source' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);


1;
