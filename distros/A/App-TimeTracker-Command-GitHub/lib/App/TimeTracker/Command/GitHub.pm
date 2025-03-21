package App::TimeTracker::Command::GitHub;
use strict;
use warnings;
use 5.024;

# ABSTRACT: App::TimeTracker GitHub plugin
use App::TimeTracker::Utils qw(error_message warning_message);

our $VERSION = "1.002";

use Moose::Role;
use Pithub;

has 'issue' => (
    is            => 'rw',
    isa           => 'Str',
    documentation => 'github issue',
    predicate     => 'has_issue'
);

has 'github_client' => (
    is         => 'rw',
    isa        => 'Maybe[Pithub]',
    lazy_build => 1,
    traits     => ['NoGetopt'],
);

sub _build_github_client {
    my $self   = shift;
    my $config = $self->config->{github};

    my %args;

    # required
    for my $fld (qw(user repo token)) {
        error_message( "Please configure github." . $fld . ". in your TimeTracker config" )
            unless $config->{$fld};
        $args{$fld} = $config->{$fld};
    }

    # optional
    $args{api_uri} = $config->{api_uri} if $config->{api_uri};

    if ( $config->{upstream} ) {
        for my $fld (qw(user repo)) {
            error_message( "You set upstream, but did not set '" . $fld . "'!" )
                unless $config->{upstream}->{$fld};
            $args{$fld} = $config->{upstream}->{$fld};
        }
    }

    return Pithub->new(%args);
}

before [ 'cmd_start', 'cmd_continue', 'cmd_append' ] => sub {
    my $self = shift;
    return unless $self->has_issue;

    my $issuename = 'issue#' . $self->issue;
    $self->insert_tag($issuename);

    my $cfg = $self->config->{github};
    my $response =
        $self->github_client->issues->get( repo => $cfg->{repo}, issue_id => $self->issue );
    unless ( $response->success ) {
        error_message( "Cannot find issue %s in %s/%s", $self->issue, $cfg->@{ 'user', 'repo' } );
        return;
    }
    my $issue = $response->content;
    my $name  = $issue->{title};

    if ( defined $self->description ) {
        $self->description( $self->description . ' ' . $name );
    }
    else {
        $self->description($name);
    }

    if ( $self->meta->does_role('App::TimeTracker::Command::Git') ) {
        my $branch = $self->issue;
        if ($name) {
            $branch = $self->safe_branch_name( $self->issue . ' ' . $name );
        }
        $branch =~ s/_/-/g;
        $self->branch( lc($branch) ) unless $self->branch;
    }
};

sub App::TimeTracker::Data::Task::github_issue {
    my $self = shift;
    foreach my $tag ( @{ $self->tags } ) {
        next unless $tag =~ /^issue#(\d+)/;
        return $1;
    }
}

no Moose::Role;

q{ listening to: Train noises on my way from Wien to Graz }

__END__

=pod

=encoding UTF-8

=head1 NAME

App::TimeTracker::Command::GitHub - App::TimeTracker GitHub plugin

=head1 VERSION

version 1.002

=head1 DESCRIPTION

Connect tracker with L<GitHub|https://github.com/>.

Using the GitHub plugin, tracker can fetch the name of an issue and use
it as the task's description; generate a nicely named C<git> branch
(if you're also using the C<Git> plugin).

=head1 CONFIGURATION

=head2 plugins

Add C<GitHub> to the list of plugins.

=head2 github

add a hash named C<github>, containing the following keys:

=head3 user [REQUIRED]

Your github user name. Best stored in your global TimeTracker config file.

=head3 token [REQUIRED]

Your personal access token. Get it from your github settings
(Developer Settings, Personal access token): https://github.com/settings/tokens

Best stored in your global TimeTracker config file.

=head3 repo [REQUIRED]

The name of the repository you are working on. Currently a required
entry to the config file, but we might upgrade it to a command line
param and/or try to guess it from the current working dir or your git
config.

=head3 api_uri

Optional.

Set this to the URL of your local GitHub Enterprise installation.

=head3 upstream

Optional.

If the project you are working on has an upstream project where issues are
handled, then you can set upstream to a hash of user and repo (like on a normal
project) to fetch issues from there.

=head1 NEW COMMANDS

No new commands

=head1 CHANGES TO OTHER COMMANDS

=head2 start, continue

=head3 --issue

    ~/perl/Your-Project$ tracker start --issue 42

If C<--issue> is set and we can find an issue with this id in your current repo

=over

=item * set or append the issue name in the task description ("Rev up FluxCompensator!!")

=item * add the issue id to the tasks tags ("issue#42")

=item * if C<Git> is also used, determine a save branch name from the issue name, and change into this branch ("42-rev-up-fluxcompensator")

=item * TODO: assign to your user, if C<set_assignee> is set and issue is not assigned

=item * TODO: reopen a closed issue if C<reopen> is set

=item * TODO: modifiy the labels by adding all labels listed in C<labels_on_start.add> and removing all lables listed in C<labels_on_start.add>

=back

=head1 Contributors

=over

=item * L<Thomas MANTL|https://github.com/TM2500>

=back

=head1 AUTHOR

Thomas Klausner <domm@plix.at>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by Thomas Klausner.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
