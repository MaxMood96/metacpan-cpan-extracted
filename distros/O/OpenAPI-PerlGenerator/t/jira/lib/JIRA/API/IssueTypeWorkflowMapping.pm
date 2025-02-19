package JIRA::API::IssueTypeWorkflowMapping 0.01;
# DO NOT EDIT! This is an autogenerated file.
use 5.020;
use Moo 2;
use experimental 'signatures';
use Types::Standard qw(Str Bool Num Int Object ArrayRef);
use MooX::TypeTiny;

=head1 NAME

JIRA::API::IssueTypeWorkflowMapping -

=head1 SYNOPSIS

  my $obj = JIRA::API::IssueTypeWorkflowMapping->new();
  ...

=cut

sub as_hash( $self ) {
    return { $self->%* }
}

=head1 PROPERTIES

=head2 C<< issueType >>

The ID of the issue type. Not required if updating the issue type-workflow mapping.

=cut

has 'issueType' => (
    is       => 'ro',
    isa      => Str,
);

=head2 C<< updateDraftIfNeeded >>

Set to true to create or update the draft of a workflow scheme and update the mapping in the draft, when the workflow scheme cannot be edited. Defaults to `false`. Only applicable when updating the workflow-issue types mapping.

=cut

has 'updateDraftIfNeeded' => (
    is       => 'ro',
);

=head2 C<< workflow >>

The name of the workflow.

=cut

has 'workflow' => (
    is       => 'ro',
    isa      => Str,
);


1;
