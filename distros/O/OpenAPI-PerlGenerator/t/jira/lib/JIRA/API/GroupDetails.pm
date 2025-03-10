package JIRA::API::GroupDetails 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::GroupDetails -

=head1 SYNOPSIS

  my $obj = JIRA::API::GroupDetails->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< groupId >>

The ID of the group, which uniquely identifies the group across all Atlassian products. For example, *952d12c3-5b5b-4d04-bb32-44d383afc4b2*.

=cut

has 'groupId' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< name >>

The name of the group.

=cut

has 'name' => (
    is       => 'ro',
    isa      => Str,
);


1;
