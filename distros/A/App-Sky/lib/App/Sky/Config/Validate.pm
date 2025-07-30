package App::Sky::Config::Validate;
$App::Sky::Config::Validate::VERSION = '0.8.0';
use strict;
use warnings;


use Carp ();

use Moo;
use MooX 'late';

use Scalar::Util    qw(reftype);
use List::MoreUtils qw(notall);

has 'config' => ( isa => 'HashRef', is => 'ro', required => 1, );


sub _sorted_keys
{
    my $hash_ref = shift;

    my @ret = sort { $a cmp $b } keys(%$hash_ref);

    return @ret;
}

sub _validate_section
{
    my ( $self, $site_name, $sect_name, $sect_conf ) = @_;

    foreach my $string_key (qw( basename_re target_dir))
    {
        my $v = $sect_conf->{$string_key};

        if (
            not(   defined($v)
                && ref($v) eq ''
                && $v =~ /\S/ )
            )
        {
            die
"Section '$sect_name' at site '$site_name' must contain a non-empty $string_key";
        }
    }

OVER:
    foreach my $string_key (qw( overrides ))
    {
        my $v = $sect_conf->{$string_key};
        next OVER if !defined($v);
        foreach my $kk (qw(dest_upload_prefix dest_upload_url_prefix))
        {
            my $s = $v->{$kk};
            if (
                not(
                    defined($s) ? ( ( ref($s) eq '' ) && ( $s =~ m/\S/ ) ) : 1 )
                )
            {
                die "$kk for section '$sect_name' is not a string.";
            }
        }
    }
    return;
}

sub _validate_site
{
    my ( $self, $site_name, $site_conf ) = @_;

    my $base_upload_cmd = $site_conf->{base_upload_cmd};
    if ( ref($base_upload_cmd) ne 'ARRAY' )
    {
        die "base_upload_cmd for site '$site_name' is not an array.";
    }

    if ( notall { defined($_) && ref($_) eq '' } @$base_upload_cmd )
    {
        die "base_upload_cmd for site '$site_name' must contain only strings.";
    }

    foreach my $kk (qw(dest_upload_prefix dest_upload_url_prefix))
    {
        my $s = $site_conf->{$kk};
        if ( not( defined($s) && ( ref($s) eq '' ) && ( $s =~ m/\S/ ) ) )
        {
            die "$kk for site '$site_name' is not a string.";
        }
    }

    my $sections = $site_conf->{sections};
    if ( ref($sections) ne 'HASH' )
    {
        die "Sections for site '$site_name' is not a hash.";
    }

    foreach my $sect_name ( _sorted_keys($sections) )
    {
        $self->_validate_section( $site_name, $sect_name,
            $sections->{$sect_name} );
    }

    return;
}

sub is_valid
{
    my ($self) = @_;

    my $config = $self->config();

    # Validate the configuration
    {
        if ( !exists( $config->{default_site} ) )
        {
            die "A 'default_site' key must be present in the configuration.";
        }

        my $sites = $config->{sites};
        if ( ref($sites) ne 'HASH' )
        {
            die "sites key must be a hash.";
        }

        foreach my $name ( _sorted_keys($sites) )
        {
            $self->_validate_site( $name, $sites->{$name} );
        }
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Sky::Config::Validate - validate the configuration.

=head1 VERSION

version 0.8.0

=head1 METHODS

=head2 $self->config()

The configuration to validate.

=head2 $self->is_valid()

Determines if the configuration is valid. Throws an exception if not valid,
and returns FALSE (in both list context and scalar context if it is valid.).

=for :stopwords cpan testmatrix url bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Websites

The following websites have more information about this module, and may be of help to you. As always,
in addition to those websites please use your favorite search engine to discover more resources.

=over 4

=item *

MetaCPAN

A modern, open-source CPAN search engine, useful to view POD in HTML format.

L<https://metacpan.org/release/App-Sky>

=item *

RT: CPAN's Bug Tracker

The RT ( Request Tracker ) website is the default bug/issue tracking system for CPAN.

L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-Sky>

=item *

CPANTS

The CPANTS is a website that analyzes the Kwalitee ( code metrics ) of a distribution.

L<http://cpants.cpanauthors.org/dist/App-Sky>

=item *

CPAN Testers

The CPAN Testers is a network of smoke testers who run automated tests on uploaded CPAN distributions.

L<http://www.cpantesters.org/distro/A/App-Sky>

=item *

CPAN Testers Matrix

The CPAN Testers Matrix is a website that provides a visual overview of the test results for a distribution on various Perls/platforms.

L<http://matrix.cpantesters.org/?dist=App-Sky>

=item *

CPAN Testers Dependencies

The CPAN Testers Dependencies is a website that shows a chart of the test results of all dependencies for a distribution.

L<http://deps.cpantesters.org/?module=App::Sky>

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests by email to C<bug-app-sky at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/Public/Bug/Report.html?Queue=App-Sky>. You will be automatically notified of any
progress on the request by the system.

=head2 Source Code

The code is open to the world, and available for you to hack on. Please feel free to browse it and play
with it, or whatever. If you want to contribute patches, please send me a diff or prod me to pull
from your repository :)

L<https://github.com/shlomif/Sky-uploader>

  git clone git://github.com/shlomif/Sky-uploader.git

=head1 AUTHOR

Shlomi Fish <shlomif@cpan.org>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/shlomif/Sky-uploader/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2013 by Shlomi Fish.

This is free software, licensed under:

  The MIT (X11) License

=cut
