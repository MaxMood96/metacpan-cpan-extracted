package JIRA::API::FieldConfigurationSchemeProjects 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::FieldConfigurationSchemeProjects -

=head1 SYNOPSIS

  my $obj = JIRA::API::FieldConfigurationSchemeProjects->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< fieldConfigurationScheme >>

Details of a field configuration scheme.

=cut

has 'fieldConfigurationScheme' => (
    is       => 'ro',
    isa      => Object,
);

=head2 C<< projectIds >>

The IDs of projects using the field configuration scheme.

=cut

has 'projectIds' => (
    is       => 'ro',
    isa      => ArrayRef[Str],
    required => 1,
);


1;
