package Filename::Media::Info;

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
use Time::Local qw(timelocal_posix);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-08-23'; # DATE
our $DIST = 'Filename-Media-Info'; # DIST
our $VERSION = '0.002'; # VERSION

our @EXPORT_OK = qw(parse_media_filename);

our %SPEC;

$SPEC{parse_media_filename} = {
    v => 1.1,
    summary => 'Extract various information from media filenames',
    description => <<'MARKDOWN',


MARKDOWN
    args => {
        filename => {
            schema => 'filename*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
    result => {
        schema => ['hash*'],
    },
    examples => [
        {
            args => {filename => 'IMG-20140828-WA0002.jpg'},
            test => 0,
        },
        {
            args => {filename => 'IMG_20141103_122548680_HDR.jpg'},
            test => 0,
        },
    ],
};
sub parse_media_filename {
    my %args = @_;

    my $filename = $args{filename};
    my $res = {filename => $filename};

    if ($filename =~ /^Screenshot/) {
        $res->{type} = 'image';
        $res->{is_screenshot} = 1;
    } elsif ($filename =~ /^(IMG)[_-]/) {
        $res->{type} = 'image';
    } elsif ($filename =~ /^(VID)[_-]/) {
        $res->{type} = 'video';
    }

    if ($filename =~ /^(?:IMG|VID)_(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})(\d{2})(\d{3})?/) {
        $res->{ymd} = "$1$2$3";
        $res->{hms} = "$4$5$6";
        $res->{millisecond} = $7;
        $res->{epoch} = timelocal_posix($6, $5, $4, $3, $2-1, $1-1900);
    } elsif ($filename =~ /^(?:IMG|VID)-(\d{4})(\d{2})(\d{2})-WA/) {
        $res->{ymd} = "$1$2$3";
        $res->{hms} = "000000";
        $res->{epoch} = timelocal_posix(0, 0, 0, $3, $2-1, $1-1900);
        $res->{is_whatsapp} = 1;
    }

    $res;
}

1;
# ABSTRACT: Extract various information from media filenames

__END__

=pod

=encoding UTF-8

=head1 NAME

Filename::Media::Info - Extract various information from media filenames

=head1 VERSION

This document describes version 0.002 of Filename::Media::Info (from Perl distribution Filename-Media-Info), released on 2025-08-23.

=head1 SYNOPSIS

 use Filename::Media::Info qw(parse_media_filename);
 my $res = parse_media_filename(filename => "IMG_20141103_122548680_HDR.jpg");

=head1 DESCRIPTION

=head1 FUNCTIONS


=head2 parse_media_filename

Usage:

 parse_media_filename(%args) -> hash

Extract various information from media filenames.

Examples:

=over

=item * Example #1:

 parse_media_filename(filename => "IMG-20140828-WA0002.jpg");

Result:

 {
   epoch => 1409158800,
   filename => "IMG-20140828-WA0002.jpg",
   hms => "000000",
   is_whatsapp => 1,
   type => "image",
   ymd => 20140828,
 }

=item * Example #2:

 parse_media_filename(filename => "IMG_20141103_122548680_HDR.jpg");

Result:

 {
   epoch => 1414992348,
   filename => "IMG_20141103_122548680_HDR.jpg",
   hms => 122548,
   millisecond => 680,
   type => "image",
   ymd => 20141103,
 }

=back

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<filename>* => I<filename>

(No description)


=back

Return value:  (hash)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Filename-Media-Info>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Filename-Media-Info>.

=head1 SEE ALSO

C<Filename::Type::*>.

L<Media::Info>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Filename-Media-Info>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
