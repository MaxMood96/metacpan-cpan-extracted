package JIRA::API::CustomFieldContextDefaultValueForgeMultiStringField 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::CustomFieldContextDefaultValueForgeMultiStringField -

=head1 SYNOPSIS

  my $obj = JIRA::API::CustomFieldContextDefaultValueForgeMultiStringField->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< type >>

=cut

has 'type' => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head2 C<< values >>

List of string values. The maximum length for a value is 254 characters.

=cut

has 'values' => (
    is       => 'ro',
    isa      => ArrayRef[Str],
);


1;
