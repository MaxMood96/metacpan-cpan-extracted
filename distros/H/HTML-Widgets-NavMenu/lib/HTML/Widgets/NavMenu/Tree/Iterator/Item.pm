package HTML::Widgets::NavMenu::Tree::Iterator::Item;
$HTML::Widgets::NavMenu::Tree::Iterator::Item::VERSION = '1.1000';
use strict;
use warnings;

use parent qw(HTML::Widgets::NavMenu::Object);

__PACKAGE__->mk_acc_ref(
    [
        qw(
            _node
            _subs
            _sub_idx
            _visited
            _accum_state
        )
    ]
);


sub _init
{
    my ( $self, $args ) = @_;

    $self->_node( $args->{'node'} )
        or die "node not specified!";

    $self->_subs( $args->{'subs'} )
        or die "subs not specified!";

    $self->_sub_idx(-1);
    $self->_visited(0);

    $self->_accum_state( $args->{'accum_state'} )
        or die "accum_state not specified!";

    return 0;
}

sub _is_visited
{
    my $self = shift;
    return $self->_visited();
}

sub _visit
{
    my $self = shift;

    $self->_visited(1);

    if ( $self->_num_subs_to_go() )
    {
        return $self->_subs()->[ $self->_sub_idx( $self->_sub_idx() + 1 ) ];
    }
    else
    {
        return;
    }
}

sub _visited_index
{
    my $self = shift;

    return $self->_sub_idx();
}

sub _num_subs_to_go
{
    my $self = shift;
    return $self->_num_subs() - $self->_sub_idx() - 1;
}

sub _num_subs
{
    my $self = shift;
    return scalar( @{ $self->_subs() } );
}

sub _get_sub
{
    my $self    = shift;
    my $sub_num = shift;

    return $self->_subs()->[$sub_num];
}

sub _li_id
{
    return shift->_node->li_id();
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

HTML::Widgets::NavMenu::Tree::Iterator::Item - an item for the tree iterator.

=head1 VERSION

version 1.1000

=head1 SYNOPSIS

For internal use only.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Shlomi Fish, all rights reserved.

This program is released under the following license: MIT X11.

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/HTML-Widgets-NavMenu>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=HTML-Widgets-NavMenu>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/HTML-Widgets-NavMenu>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/H/HTML-Widgets-NavMenu>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=HTML-Widgets-NavMenu>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=HTML::Widgets::NavMenu>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-html-widgets-navmenu at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=HTML-Widgets-NavMenu>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/perl-HTML-Widgets-NavMenu>

  git clone git://github.com/shlomif/perl-HTML-Widgets-NavMenu.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/perl-HTML-Widgets-NavMenu/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
