package Net::Async::Github::Repository;

use strict;
use warnings;

our $VERSION = '0.013'; # VERSION

use parent qw(Net::Async::Github::Common);

=head1 NAME

Net::Async::Github::Repository

=head1 DESCRIPTION

Autogenerated module.

=cut

use Net::Async::Github::User ();
use URI::Template ();
use Time::Moment ();

=head1 METHODS

=cut

=head2 id

Provides an accessor for C<id>.

=cut

sub id {
    shift->{id}
}

=head2 owner

Provides an accessor for C<owner>.

=cut

sub owner {
    $_[0]->{owner} =
     Net::Async::Github::User->new($_[0]->{owner})
        unless ref $_[0]->{owner};
    shift->{owner}
}

=head2 name

Provides an accessor for C<name>.

=cut

sub name {
    shift->{name}
}

=head2 full_name

Provides an accessor for C<full_name>.

=cut

sub full_name {
    shift->{full_name}
}

=head2 description

Provides an accessor for C<description>.

=cut

sub description {
    shift->{description}
}

=head2 private

Provides an accessor for C<private>.

=cut

sub private {
    shift->{private}
}

=head2 fork

Provides an accessor for C<fork>.

=cut

sub fork {
    shift->{fork}
}

=head2 url

Provides an accessor for C<url>.

=cut

sub url {
    $_[0]->{url} =
     URI::Template->new($_[0]->{url})
        unless ref $_[0]->{url};
    shift->{url}
}

=head2 html_url

Provides an accessor for C<html_url>.

=cut

sub html_url {
    $_[0]->{html_url} =
     URI::Template->new($_[0]->{html_url})
        unless ref $_[0]->{html_url};
    shift->{html_url}
}

=head2 archive_url

Provides an accessor for C<archive_url>.

=cut

sub archive_url {
    $_[0]->{archive_url} =
     URI::Template->new($_[0]->{archive_url})
        unless ref $_[0]->{archive_url};
    shift->{archive_url}
}

=head2 assignees_url

Provides an accessor for C<assignees_url>.

=cut

sub assignees_url {
    $_[0]->{assignees_url} =
     URI::Template->new($_[0]->{assignees_url})
        unless ref $_[0]->{assignees_url};
    shift->{assignees_url}
}

=head2 blobs_url

Provides an accessor for C<blobs_url>.

=cut

sub blobs_url {
    $_[0]->{blobs_url} =
     URI::Template->new($_[0]->{blobs_url})
        unless ref $_[0]->{blobs_url};
    shift->{blobs_url}
}

=head2 branches_url

Provides an accessor for C<branches_url>.

=cut

sub branches_url {
    $_[0]->{branches_url} =
     URI::Template->new($_[0]->{branches_url})
        unless ref $_[0]->{branches_url};
    shift->{branches_url}
}

=head2 clone_url

Provides an accessor for C<clone_url>.

=cut

sub clone_url {
    $_[0]->{clone_url} =
     URI::Template->new($_[0]->{clone_url})
        unless ref $_[0]->{clone_url};
    shift->{clone_url}
}

=head2 collaborators_url

Provides an accessor for C<collaborators_url>.

=cut

sub collaborators_url {
    $_[0]->{collaborators_url} =
     URI::Template->new($_[0]->{collaborators_url})
        unless ref $_[0]->{collaborators_url};
    shift->{collaborators_url}
}

=head2 comments_url

Provides an accessor for C<comments_url>.

=cut

sub comments_url {
    $_[0]->{comments_url} =
     URI::Template->new($_[0]->{comments_url})
        unless ref $_[0]->{comments_url};
    shift->{comments_url}
}

=head2 commits_url

Provides an accessor for C<commits_url>.

=cut

sub commits_url {
    $_[0]->{commits_url} =
     URI::Template->new($_[0]->{commits_url})
        unless ref $_[0]->{commits_url};
    shift->{commits_url}
}

=head2 compare_url

Provides an accessor for C<compare_url>.

=cut

sub compare_url {
    $_[0]->{compare_url} =
     URI::Template->new($_[0]->{compare_url})
        unless ref $_[0]->{compare_url};
    shift->{compare_url}
}

=head2 contents_url

Provides an accessor for C<contents_url>.

=cut

sub contents_url {
    $_[0]->{contents_url} =
     URI::Template->new($_[0]->{contents_url})
        unless ref $_[0]->{contents_url};
    shift->{contents_url}
}

=head2 contributors_url

Provides an accessor for C<contributors_url>.

=cut

sub contributors_url {
    $_[0]->{contributors_url} =
     URI::Template->new($_[0]->{contributors_url})
        unless ref $_[0]->{contributors_url};
    shift->{contributors_url}
}

=head2 deployments_url

Provides an accessor for C<deployments_url>.

=cut

sub deployments_url {
    $_[0]->{deployments_url} =
     URI::Template->new($_[0]->{deployments_url})
        unless ref $_[0]->{deployments_url};
    shift->{deployments_url}
}

=head2 downloads_url

Provides an accessor for C<downloads_url>.

=cut

sub downloads_url {
    $_[0]->{downloads_url} =
     URI::Template->new($_[0]->{downloads_url})
        unless ref $_[0]->{downloads_url};
    shift->{downloads_url}
}

=head2 events_url

Provides an accessor for C<events_url>.

=cut

sub events_url {
    $_[0]->{events_url} =
     URI::Template->new($_[0]->{events_url})
        unless ref $_[0]->{events_url};
    shift->{events_url}
}

=head2 forks_url

Provides an accessor for C<forks_url>.

=cut

sub forks_url {
    $_[0]->{forks_url} =
     URI::Template->new($_[0]->{forks_url})
        unless ref $_[0]->{forks_url};
    shift->{forks_url}
}

=head2 git_commits_url

Provides an accessor for C<git_commits_url>.

=cut

sub git_commits_url {
    $_[0]->{git_commits_url} =
     URI::Template->new($_[0]->{git_commits_url})
        unless ref $_[0]->{git_commits_url};
    shift->{git_commits_url}
}

=head2 git_refs_url

Provides an accessor for C<git_refs_url>.

=cut

sub git_refs_url {
    $_[0]->{git_refs_url} =
     URI::Template->new($_[0]->{git_refs_url})
        unless ref $_[0]->{git_refs_url};
    shift->{git_refs_url}
}

=head2 git_tags_url

Provides an accessor for C<git_tags_url>.

=cut

sub git_tags_url {
    $_[0]->{git_tags_url} =
     URI::Template->new($_[0]->{git_tags_url})
        unless ref $_[0]->{git_tags_url};
    shift->{git_tags_url}
}

=head2 git_url

Provides an accessor for C<git_url>.

=cut

sub git_url {
    $_[0]->{git_url} =
     URI::Template->new($_[0]->{git_url})
        unless ref $_[0]->{git_url};
    shift->{git_url}
}

=head2 hooks_url

Provides an accessor for C<hooks_url>.

=cut

sub hooks_url {
    $_[0]->{hooks_url} =
     URI::Template->new($_[0]->{hooks_url})
        unless ref $_[0]->{hooks_url};
    shift->{hooks_url}
}

=head2 issue_comment_url

Provides an accessor for C<issue_comment_url>.

=cut

sub issue_comment_url {
    $_[0]->{issue_comment_url} =
     URI::Template->new($_[0]->{issue_comment_url})
        unless ref $_[0]->{issue_comment_url};
    shift->{issue_comment_url}
}

=head2 issue_events_url

Provides an accessor for C<issue_events_url>.

=cut

sub issue_events_url {
    $_[0]->{issue_events_url} =
     URI::Template->new($_[0]->{issue_events_url})
        unless ref $_[0]->{issue_events_url};
    shift->{issue_events_url}
}

=head2 issues_url

Provides an accessor for C<issues_url>.

=cut

sub issues_url {
    $_[0]->{issues_url} =
     URI::Template->new($_[0]->{issues_url})
        unless ref $_[0]->{issues_url};
    shift->{issues_url}
}

=head2 keys_url

Provides an accessor for C<keys_url>.

=cut

sub keys_url {
    $_[0]->{keys_url} =
     URI::Template->new($_[0]->{keys_url})
        unless ref $_[0]->{keys_url};
    shift->{keys_url}
}

=head2 labels_url

Provides an accessor for C<labels_url>.

=cut

sub labels_url {
    $_[0]->{labels_url} =
     URI::Template->new($_[0]->{labels_url})
        unless ref $_[0]->{labels_url};
    shift->{labels_url}
}

=head2 languages_url

Provides an accessor for C<languages_url>.

=cut

sub languages_url {
    $_[0]->{languages_url} =
     URI::Template->new($_[0]->{languages_url})
        unless ref $_[0]->{languages_url};
    shift->{languages_url}
}

=head2 merges_url

Provides an accessor for C<merges_url>.

=cut

sub merges_url {
    $_[0]->{merges_url} =
     URI::Template->new($_[0]->{merges_url})
        unless ref $_[0]->{merges_url};
    shift->{merges_url}
}

=head2 milestones_url

Provides an accessor for C<milestones_url>.

=cut

sub milestones_url {
    $_[0]->{milestones_url} =
     URI::Template->new($_[0]->{milestones_url})
        unless ref $_[0]->{milestones_url};
    shift->{milestones_url}
}

=head2 mirror_url

Provides an accessor for C<mirror_url>.

=cut

sub mirror_url {
    $_[0]->{mirror_url} =
     URI::Template->new($_[0]->{mirror_url})
        unless ref $_[0]->{mirror_url};
    shift->{mirror_url}
}

=head2 notifications_url

Provides an accessor for C<notifications_url>.

=cut

sub notifications_url {
    $_[0]->{notifications_url} =
     URI::Template->new($_[0]->{notifications_url})
        unless ref $_[0]->{notifications_url};
    shift->{notifications_url}
}

=head2 pulls_url

Provides an accessor for C<pulls_url>.

=cut

sub pulls_url {
    $_[0]->{pulls_url} =
     URI::Template->new($_[0]->{pulls_url})
        unless ref $_[0]->{pulls_url};
    shift->{pulls_url}
}

=head2 releases_url

Provides an accessor for C<releases_url>.

=cut

sub releases_url {
    $_[0]->{releases_url} =
     URI::Template->new($_[0]->{releases_url})
        unless ref $_[0]->{releases_url};
    shift->{releases_url}
}

=head2 ssh_url

Provides an accessor for C<ssh_url>.

=cut

sub ssh_url {
    $_[0]->{ssh_url} =
     URI::Template->new($_[0]->{ssh_url})
        unless ref $_[0]->{ssh_url};
    shift->{ssh_url}
}

=head2 stargazers_url

Provides an accessor for C<stargazers_url>.

=cut

sub stargazers_url {
    $_[0]->{stargazers_url} =
     URI::Template->new($_[0]->{stargazers_url})
        unless ref $_[0]->{stargazers_url};
    shift->{stargazers_url}
}

=head2 statuses_url

Provides an accessor for C<statuses_url>.

=cut

sub statuses_url {
    $_[0]->{statuses_url} =
     URI::Template->new($_[0]->{statuses_url})
        unless ref $_[0]->{statuses_url};
    shift->{statuses_url}
}

=head2 subscribers_url

Provides an accessor for C<subscribers_url>.

=cut

sub subscribers_url {
    $_[0]->{subscribers_url} =
     URI::Template->new($_[0]->{subscribers_url})
        unless ref $_[0]->{subscribers_url};
    shift->{subscribers_url}
}

=head2 subscription_url

Provides an accessor for C<subscription_url>.

=cut

sub subscription_url {
    $_[0]->{subscription_url} =
     URI::Template->new($_[0]->{subscription_url})
        unless ref $_[0]->{subscription_url};
    shift->{subscription_url}
}

=head2 svn_url

Provides an accessor for C<svn_url>.

=cut

sub svn_url {
    $_[0]->{svn_url} =
     URI::Template->new($_[0]->{svn_url})
        unless ref $_[0]->{svn_url};
    shift->{svn_url}
}

=head2 tags_url

Provides an accessor for C<tags_url>.

=cut

sub tags_url {
    $_[0]->{tags_url} =
     URI::Template->new($_[0]->{tags_url})
        unless ref $_[0]->{tags_url};
    shift->{tags_url}
}

=head2 teams_url

Provides an accessor for C<teams_url>.

=cut

sub teams_url {
    $_[0]->{teams_url} =
     URI::Template->new($_[0]->{teams_url})
        unless ref $_[0]->{teams_url};
    shift->{teams_url}
}

=head2 trees_url

Provides an accessor for C<trees_url>.

=cut

sub trees_url {
    $_[0]->{trees_url} =
     URI::Template->new($_[0]->{trees_url})
        unless ref $_[0]->{trees_url};
    shift->{trees_url}
}

=head2 homepage

Provides an accessor for C<homepage>.

=cut

sub homepage {
    shift->{homepage}
}

=head2 language

Provides an accessor for C<language>.

=cut

sub language {
    shift->{language}
}

=head2 forks_count

Provides an accessor for C<forks_count>.

=cut

sub forks_count {
    shift->{forks_count}
}

=head2 stargazers_count

Provides an accessor for C<stargazers_count>.

=cut

sub stargazers_count {
    shift->{stargazers_count}
}

=head2 watchers_count

Provides an accessor for C<watchers_count>.

=cut

sub watchers_count {
    shift->{watchers_count}
}

=head2 size

Provides an accessor for C<size>.

=cut

sub size {
    shift->{size}
}

=head2 default_branch

Provides an accessor for C<default_branch>.

=cut

sub default_branch {
    shift->{default_branch}
}

=head2 open_issues_count

Provides an accessor for C<open_issues_count>.

=cut

sub open_issues_count {
    shift->{open_issues_count}
}

=head2 has_issues

Provides an accessor for C<has_issues>.

=cut

sub has_issues {
    shift->{has_issues}
}

=head2 has_wiki

Provides an accessor for C<has_wiki>.

=cut

sub has_wiki {
    shift->{has_wiki}
}

=head2 has_pages

Provides an accessor for C<has_pages>.

=cut

sub has_pages {
    shift->{has_pages}
}

=head2 has_downloads

Provides an accessor for C<has_downloads>.

=cut

sub has_downloads {
    shift->{has_downloads}
}

=head2 pushed_at

Provides an accessor for C<pushed_at>.

=cut

sub pushed_at {
    $_[0]->{pushed_at} =
    (defined($_[0]->{pushed_at}) && length($_[0]->{pushed_at}) ? Time::Moment->from_string($_[0]->{pushed_at}) : undef)
        unless ref $_[0]->{pushed_at};
    shift->{pushed_at}
}

=head2 created_at

Provides an accessor for C<created_at>.

=cut

sub created_at {
    $_[0]->{created_at} =
    (defined($_[0]->{created_at}) && length($_[0]->{created_at}) ? Time::Moment->from_string($_[0]->{created_at}) : undef)
        unless ref $_[0]->{created_at};
    shift->{created_at}
}

=head2 updated_at

Provides an accessor for C<updated_at>.

=cut

sub updated_at {
    $_[0]->{updated_at} =
    (defined($_[0]->{updated_at}) && length($_[0]->{updated_at}) ? Time::Moment->from_string($_[0]->{updated_at}) : undef)
        unless ref $_[0]->{updated_at};
    shift->{updated_at}
}

=head2 permissions

Provides an accessor for C<permissions>.

=cut

sub permissions {
    shift->{permissions}
}

1;

