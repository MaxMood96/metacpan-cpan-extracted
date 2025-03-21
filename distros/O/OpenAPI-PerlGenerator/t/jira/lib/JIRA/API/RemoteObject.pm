package JIRA::API::RemoteObject 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::RemoteObject -

=head1 SYNOPSIS

  my $obj = JIRA::API::RemoteObject->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< icon >>

Details of the icon for the item. If no icon is defined, the default link icon is used in Jira.

=cut

has 'icon' => (
    is       => 'ro',
);

=head2 C<< status >>

The status of the item.

=cut

has 'status' => (
    is       => 'ro',
);

=head2 C<< summary >>

The summary details of the item.

=cut

has 'summary' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< title >>

The title of the item.

=cut

has 'title' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head2 C<< url >>

The URL of the item.

=cut

has 'url' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);


1;
