package Media::Info::Ffmpeg;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2020-06-02'; # DATE
our $DIST = 'Media-Info-Ffmpeg'; # DIST
our $VERSION = '0.008'; # VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Capture::Tiny qw(capture);
use IPC::System::Options 'system', -log=>1;
use Perinci::Sub::Util qw(err);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       get_media_info
               );

our %SPEC;

$SPEC{get_media_info} = {
    v => 1.1,
    summary => 'Return information on media file/URL, using ffmpeg',
    args => {
        media => {
            summary => 'Media file',
            schema  => 'str*',
            pos     => 0,
            req     => 1,
        },
    },
    deps => {
        prog => 'ffmpeg',
    },
};
sub get_media_info {
    require File::Which;

    my %args = @_;

    File::Which::which("ffmpeg")
          or return err(412, "Can't find ffmpeg in PATH");
    my $media = $args{media} or return err(400, "Please specify media");

    # make sure user can't sneak in cmdline options to ffmpeg
    $media = "./$media" if $media =~ /\A-/;

    my ($stdout, $stderr, $exit) = capture {
        local $ENV{LANG} = "C";
        system("ffmpeg", "-i", $media); # ffprobe produces the same output
    };

    return err(500, "ffmpeg doesn't show information")
        unless $stderr =~ /^Input \#0/m;

    my $info = {};
    $info->{duration}      = $1*3600+$2*60+$3 if $stderr =~ /^\s*Duration: (\d+):(\d+):(\d+\.\d+)/m;
    $info->{rotate}        = $1 if $stderr =~ /^\s*rotate\s*:\s*(.+)/m;

    # XXX what about multiple video streams info?
    if ($stderr =~ /^\s*Stream.+?: Video: (.+)/m) {
        my $video_info = $1;
        $video_info =~ /^(\w+)/; $info->{video_format} = uc($1);
        $video_info =~ /([1-9]\d*)x(\d+)/ and do {
            $info->{video_width}  = $1;
            $info->{video_height} = $2;
        };
        $video_info =~ /DAR ((\d+):(\d+))/ and do {
            $info->{video_dar} = $1;
            # portrait, adjust width & height to reflect this
            if ($2 < $3) {
                $info->{video_orientation} = 'portrait';
                if ($info->{video_width} > $info->{video_height}) {
                    ($info->{video_width}, $info->{video_height}) =
                        ($info->{video_height}, $info->{video_width});
                }
            } else {
                $info->{video_orientation} = 'landscape';
            }
        };
        $video_info =~ /SAR ((\d+):(\d+))/ and do {
            $info->{video_sar} = $1;
        };

        $video_info =~ /(\d+(?:\.\d+)?) fps/ and $info->{video_fps} = $1;
        $video_info =~ m!(\d+(?:\.\d+)?) kb/s! and $info->{video_bitrate} = $1*1024;
    }

    # XXX what about multiple audio streams info?
    if ($stderr =~ /\s*Stream.+?: Audio: (.+)/m) {
        my $audio_info = $1;
        $audio_info =~ /^(\w+)/; $info->{audio_format} = uc($1);
        $audio_info =~ /(\d+(?:\.\d+)?) Hz/ and $info->{audio_rate} = $1;
        $audio_info =~ m!(\d+(?:\.\d+)?) kb/s! and $info->{audio_bitrate} = $1*1024;
    }

    [200, "OK", $info, {"func.raw_output"=>$stderr}];
}

1;
# ABSTRACT: Return information on media file/URL, using ffmpeg

__END__

=pod

=encoding UTF-8

=head1 NAME

Media::Info::Ffmpeg - Return information on media file/URL, using ffmpeg

=head1 VERSION

This document describes version 0.008 of Media::Info::Ffmpeg (from Perl distribution Media-Info-Ffmpeg), released on 2020-06-02.

=head1 SYNOPSIS

Use directly:

 use Media::Info::Ffmpeg qw(get_media_info);
 my $res = get_media_info(media => '/home/steven/celine.avi');

or use via L<Media::Info>.

Sample result:

 [
   200,
   "OK",
   {
     audio_bitrate => 128000,
     audio_format  => "aac",
     audio_rate    => 44100,
     duration      => 2081.25,
   },
   {
     "func.raw_output" => "ffmpeg version 0.8.17-...",
   },
 ]

=head1 FUNCTIONS


=head2 get_media_info

Usage:

 get_media_info(%args) -> [status, msg, payload, meta]

Return information on media fileE<sol>URL, using ffmpeg.

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<media>* => I<str>

Media file.


=back

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (payload) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Media-Info-Ffmpeg>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Media-Info-Ffmpeg>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Media-Info-Ffmpeg>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Media::Info>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020, 2019, 2017, 2016 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
