package JIRA::API::Worklog 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::Worklog -

=head1 SYNOPSIS

  my $obj = JIRA::API::Worklog->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< author >>

Details of the user who created the worklog.

=cut

has 'author' => (
    is       => 'ro',
);

=head2 C<< comment >>

A comment about the worklog in [Atlassian Document Format](https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/). Optional when creating or updating a worklog.

=cut

has 'comment' => (
    is       => 'ro',
);

=head2 C<< created >>

The datetime on which the worklog was created.

=cut

has 'created' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< id >>

The ID of the worklog record.

=cut

has 'id' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< issueId >>

The ID of the issue this worklog is for.

=cut

has 'issueId' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< properties >>

Details of properties for the worklog. Optional when creating or updating a worklog.

=cut

has 'properties' => (
    is       => 'ro',
    isa      => ArrayRef[Object],
);

=head2 C<< self >>

The URL of the worklog item.

=cut

has 'self' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< started >>

The datetime on which the worklog effort was started. Required when creating a worklog. Optional when updating a worklog.

=cut

has 'started' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< timeSpent >>

The time spent working on the issue as days (\#d), hours (\#h), or minutes (\#m or \#). Required when creating a worklog if `timeSpentSeconds` isn't provided. Optional when updating a worklog. Cannot be provided if `timeSpentSecond` is provided.

=cut

has 'timeSpent' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< timeSpentSeconds >>

The time in seconds spent working on the issue. Required when creating a worklog if `timeSpent` isn't provided. Optional when updating a worklog. Cannot be provided if `timeSpent` is provided.

=cut

has 'timeSpentSeconds' => (
    is       => 'ro',
    isa      => Int,
);

=head2 C<< updateAuthor >>

Details of the user who last updated the worklog.

=cut

has 'updateAuthor' => (
    is       => 'ro',
);

=head2 C<< updated >>

The datetime on which the worklog was last updated.

=cut

has 'updated' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< visibility >>

Details about any restrictions in the visibility of the worklog. Optional when creating or updating a worklog.

=cut

has 'visibility' => (
    is       => 'ro',
);


1;
