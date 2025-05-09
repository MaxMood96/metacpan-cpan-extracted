package Mail::LMLM::Types::Base;
$Mail::LMLM::Types::Base::VERSION = '0.6807';
use strict;
use warnings;

use Mail::LMLM::Object;

use vars qw(@ISA);

@ISA = qw(Mail::LMLM::Object);

sub parse_args
{
    my $self = shift;

    my $args = shift;

    my ( @left, $key, $value );

    while ( scalar(@$args) )
    {
        $key   = shift(@$args);
        $value = shift(@$args);
        if ( $key =~ /^-?(id)$/ )
        {
            $self->{'id'} = $value;
        }
        elsif ( $key =~ /^-?(group_base)$/ )
        {
            $self->{'group_base'} = $value;
        }
        elsif ( $key =~ /^-?(desc|description)$/ )
        {
            $self->{'description'} = $value;
        }
        elsif ( $key =~ /^-?(hostname|host)$/ )
        {
            $self->{'hostname'} = $value;
        }
        elsif ( $key =~ /^-?(homepage)$/ )
        {
            $self->{'homepage'} = $value;
        }
        elsif ( $key =~ /^-?(online_archive)$/ )
        {
            $self->{'online_archive'} = $value;
        }
        elsif ( $key =~ /^-?(guidelines)$/ )
        {
            $self->{'guidelines'} = $value;
        }
        elsif ( $key =~ /^-?(notes)$/ )
        {
            $self->{'notes'} = $value;
        }
        else
        {
            push @left, $key, $value;
        }
    }

    return ( \@left );
}

sub initialize
{
    my $self = shift;

    $self->parse_args( [@_] );

    return 0;
}

sub get_id
{
    my $self = shift;

    return $self->{'id'};
}

sub get_description
{
    my $self = shift;

    return $self->{'description'};
}

sub get_homepage
{
    my $self = shift;

    return $self->{'homepage'};
}

sub get_group_base
{
    my $self = shift;

    return $self->{'group_base'};
}

sub get_hostname
{
    my $self = shift;

    return $self->{'hostname'} || $self->get_default_hostname();
}

sub get_online_archive
{
    my $self = shift;

    return $self->{'online_archive'};
}

sub get_guidelines
{
    my $self = shift;

    return $self->{'guidelines'};
}

sub render_subscribe
{
    my $self = shift;

    my $htmler = shift;

    return 0;
}

sub render_unsubscribe
{
    my $self = shift;

    my $htmler = shift;

    return 0;
}

sub render_post
{
    my $self = shift;

    my $htmler = shift;

    return 0;
}

sub render_owner
{
    my $self = shift;

    my $htmler = shift;

    return 0;
}

sub render_none
{
    my $self = shift;

    my $htmler = shift;

    $htmler->para("None.");

    return 0;
}

sub render_homepage
{
    my $self = shift;

    my $htmler = shift;

    my $homepage = $self->get_homepage();

    if ($homepage)
    {
        $htmler->start_para();
        $htmler->url($homepage);
        $htmler->end_para();
    }
    else
    {
        $self->render_none($htmler);
    }

    return 0;
}

sub render_online_archive
{
    my $self = shift;

    my $htmler = shift;

    my $archive = $self->get_online_archive();

    if ( ref($archive) eq "CODE" )
    {
        $archive->( $self, $htmler );
    }
    elsif ( ref($archive) eq "" )
    {
        $htmler->start_para();
        $htmler->url($archive);
        $htmler->end_para();
    }
    else
    {
        $self->render_none($htmler);
    }

    return 0;
}

sub render_field
{
    my $self = shift;

    my $htmler = shift;

    my $desc = shift;

    if ( ref($desc) eq "CODE" )
    {
        $desc->( $self, $htmler );
    }
    elsif ( ref($desc) eq "ARRAY" )
    {
        foreach my $paragraph (@$desc)
        {
            $htmler->para($paragraph);
        }
    }
    elsif ( ref($desc) eq "" )
    {
        $htmler->para($desc);
    }
    return 0;
}

sub render_description
{
    my $self   = shift;
    my $htmler = shift;
    $self->render_field( $htmler, $self->get_description() );
}

sub render_guidelines
{
    my $self   = shift;
    my $htmler = shift;
    $self->render_field( $htmler, $self->get_guidelines() );
}

sub render_something_with_email_addr
{
    my $self = shift;

    my $htmler         = shift;
    my $begin_msg      = shift;
    my $address_method = shift;

    $htmler->para($begin_msg);
    $htmler->indent_inc();
    $htmler->start_para();
    $htmler->email_address( $self->$address_method() );
    $htmler->end_para();
    $htmler->indent_dec();

    return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mail::LMLM::Types::Base - the base class for the mailing list types.

=head1 VERSION

version 0.6807

=head1 SYNOPSIS

Extend the class.

=head1 METHODS

=head2 Mail::LMLM::Types::MyMailingListType->new(%args)

%args keys can be:

=over 4

=item * id

The id of the mailing list - used for URLs, etc.

=item * group_base

The base username of the mailing list.

=item * desc (or description)

The description of the mailing list.

=item * hostname

The hostname where the mailing list is hosted.

=item * homepage

The mailing list's homepage

=item * online_archive

The online archive of the mailing list (can be a coderef).

=item * guidelines

Guidelines for posting on the list.

=item * notes

Notes for the mailing list.

=back

=head2 get_id()

An accessor for the ID.

=head2 get_description()

An accessor for the description.

=head2 get_homepage

An accessor for the homepage. (may be overrided by derived classes).

=head2 get_group_base

An accessor for the group base.

=head2 get_hostname

An accessor for the hostname.

=head2 get_online_archive

An accessor for the online archive.

=head2 get_guidelines

An accessor for the guidelines.

=head2 render_subscribe

Render the subscribe part.

=head2 render_unsubscribe

Render the unsubscribe part.

=head2 render_post

Render the post part.

=head2 render_owner

Render the owner part.

=head2 render_none

Render a paragraph saying "None".

=head2 render_homepage

Render the homepage part.

=head2 render_online_archive

Render the online archive part.

=head2 $self->render_field($htmler, $desc)

Renders the $desc using the rendered.

=head2 render_description

Render the description part.

=head2 render_guidelines

Render the guidelines part.

=head2 $type->render_something_with_email_addr($htmler, $begin_msg, $address_method)

Render something with the email address.

=head1 INTERNAL METHODS

=head2 initialize()

This is a helper for new(). For internal use.

=head2 parse_args()

This is a helper for initialize(). For internal use.

=head1 SEE ALSO

L<Mail::LMLM>

=head1 AUTHOR

Shlomi Fish, L<http://www.shlomifish.org/>

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/Mail-LMLM>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=Mail-LMLM>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/Mail-LMLM>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/M/Mail-LMLM>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=Mail-LMLM>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=Mail::LMLM>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-mail-lmlm at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=Mail-LMLM>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/perl-mail-lmlm>

  git clone git://github.com/shlomif/perl-mail-lmlm.git

=head1 AUTHOR

Shlomi Fish

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/perl-mail-lmlm/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2020 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
