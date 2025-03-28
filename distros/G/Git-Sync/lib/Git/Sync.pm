package Git::Sync;
$Git::Sync::VERSION = '0.0.1';
use strict;
use warnings;

use Moo;

has 'remote' => ( is => 'ro', required => 1, );
has 'branch' => ( is => 'ro', default  => 'master', );

my %aliases = (
    'o'  => 'origin',
    'u'  => 'upstream',
    'gh' => 'github',
    'b'  => 'bitbucket'
);

sub _remote_aliases
{
    return \%aliases;
}

sub run
{
    my $self = shift;

    my $aliases = $self->_remote_aliases;

    my $remote = $self->remote;
    if ( exists $aliases->{$remote} )
    {
        $remote = $aliases->{$remote};
    }
    my $branch = $self->branch;

    my $ret = system(
qq#git pull --ff-only "$remote" "$branch" && git fetch "$remote" && git fetch "$remote" --tags#
    );

    if ($ret)
    {
        die $!;
    }
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Git::Sync - synchronize a git repository.

=head1 VERSION

version 0.0.1

=head1 METHODS

=head2 my $branch = $self->branch;

Returns the git branch.

=head2 my $remote = $self->remote;

Returns the git remote.

=head2 $self->run;

Runs the git commands.

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/Git-Sync>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Git-Sync>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/Git-Sync>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/G/Git-Sync>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Git-Sync>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Git::Sync>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-git-sync at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Git-Sync>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/perl-Git-Sync>

  git clone https://github.com/shlomif/perl-Git-Sync.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/git-sync/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2020 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
