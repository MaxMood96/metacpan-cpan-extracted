=head1 NAME

StreamFinder::PragerU - Fetch actual raw streamable video URLs on www.prageru.com

=head1 AUTHOR

This module is Copyright (C) 2026 by

Jim Turner, C<< <turnerjw784 at yahoo.com> >>
		
Email: turnerjw784@yahoo.com

All rights reserved.

You may distribute this module under the terms of either the GNU General 
Public License or the Artistic License, as specified in the Perl README 
file.

=head1 SYNOPSIS

	#!/usr/bin/perl

	use strict;

	use StreamFinder::PragerU;

	die "..usage:  $0 ID|URL\n"  unless ($ARGV[0]);

	my $video = new StreamFinder::PragerU($ARGV[0]);

	die "Invalid URL or no streams found!\n"  unless ($video);

	my $firstStream = $video->get();

	print "First Stream URL=$firstStream\n";

	my $url = $video->getURL();

	print "Stream URL=$url\n";

	my $videoTitle = $video->getTitle();
	
	print "Title=$videoTitle\n";
	
	my $videoDescription = $video->getTitle('desc');
	
	print "Description=$videoDescription\n";
	
	my $videoID = $video->getID();

	print "Video ID=$videoID\n";
	
	my $artist = $video->{'artist'};

	print "Artist=$artist\n"  if ($artist);
	
	my $genre = $video->{'genre'};

	print "Genre=$genre\n"  if ($genre);
	
	my $icon_url = $video->getIconURL();

	if ($icon_url) {   #SAVE THE ICON TO A TEMP. FILE:

		print "Icon URL=$icon_url=\n";

		my ($image_ext, $icon_image) = $video->getIconData();

		if ($icon_image && open IMGOUT, ">/tmp/${videoID}.$image_ext") {

			binmode IMGOUT;

			print IMGOUT $icon_image;

			close IMGOUT;

			print "...Icon image downloaded to (/tmp/${videoID}.$image_ext)\n";

		}

	}

	my $stream_count = $video->count();

	print "--Stream count=$stream_count=\n";

	my @streams = $video->get();

	foreach my $s (@streams) {

		print "------ stream URL=$s=\n";

	}

=head1 DESCRIPTION

StreamFinder::PragerU accepts a valid video ID or URL on 
www.prageru.com and returns the actual stream URL(s), title, and cover 
art icon.  The purpose is that one needs one of these URLs in order to have 
the option to stream the video in one's own choice of media player software 
rather than using their web browser and accepting any / all flash, ads, 
javascript, cookies, trackers, web-bugs, and other crapware that can come with 
that method of play.  The author uses his own custom all-purpose media player 
called "fauxdacious" (his custom hacked version of the open-source "audacious" 
audio player).  "fauxdacious" can incorporate this module to decode and play 
www.prageru.com streams.

One stream URL can be returned for each video.

=head1 SUBROUTINES/METHODS

=over 4

=item B<new>(I<ID>|I<url> [, I<-secure> [ => 0|1 ]] [, I<-debug> [ => 0|1|2 ]])

Accepts a www.prageru.com video ID or URL and creates and 
returns a a new video object, or I<undef> if the URL is not a valid video, or 
no streams are found.  The URL can be the full URL, ie. 
https://www.prageru.com/videos/video-id>, or just 
B<video-id>.

The optional I<-keep> argument can be either a comma-separated string or an 
array reference ([...]) of stream types (extensions) to keep (include) and 
returned in order specified (type1, type2...).  Each "type" (extension) can be 
one of:  "mp3", "m4a", "mp4", "pls" (playlist), etc.  NOTE:  Since these are 
actual extensions used to identify streams, there is NO 
"any/all/stream/playlist" catch-all options as used by some of the other 
(more specific) StreamFinder-supported sites!  Streams will be returned sorted 
by extension in the order specified in this list.

DEFAULT I<-keep> list is:  "m3u8,mp4,m4a,mpd,mp3,ogg,flac,aac", meaning 
that all m3u8 (hls) streams found (if any), followed by all "ogg" streams, etc.

NOTE:  Most PragerU videos are now in .m3u8 (hls) format!

The optional I<-secure> argument can be either 0 or 1 (I<false> or I<true>).  
If 1 then only secure ("https://") streams will be returned.  Currently, 
all PragerU streaming URLs are believed to be secure (https).

DEFAULT I<-secure> is 0 (false) - return all streams (http and https).

Additional options:

I<-log> => "I<logfile>"

Specify path to a log file.  If a valid and writable file is specified, A line 
will be appended to this file every time one or more streams is successfully 
fetched for a url.

DEFAULT I<-none-> (no logging).

I<-logfmt> specifies a format string for lines written to the log file.

DEFAULT "I<[time] [url] - [site]: [title] ([total])>".  

The valid field I<[variables]> are:  [stream]: The url of the first/best 
stream found.  
[site]:  The site name (PragerU).  [url]:  The url searched for streams.  
[time]: Perl timestamp when the line was logged.  [title], [artist], [album], 
[description], [year], [genre], [total], [albumartist]:  The corresponding 
field data returned (or "I<-na->", if no value).

=item $video->B<get>(['playlist'])

Playlists are not currently supported.

=item $video->B<getURL>([I<options>])

Similar to B<get>() except it only returns a single stream representing 
the first valid stream found.  There currently are no valid I<options>.

=item $video->B<count>()

Returns the number of streams found for the video (will nearly always be 1).

=item $video->B<getID>()

Returns the video's PragerU ID (default).  PragerU video IDs 
consist of combinations of lower-case letters, numbers and hyphens.

=item $video->B<getTitle>(['desc'])

Returns the video's title, or (long description).  Videos 
on PragerU can have separate descriptions, but for videos, 
it is always the video's title.

Note:  PragerU video descriptions are usually incomplete, ending with a "..", 
since on the page itself there's a "Read More" button to view the rest, and 
"the rest" can only be obtained with Javascript.

=item $video->B<getIconURL>(['artist'])

Returns the URL for the video's "cover art" icon image, if any.
If B<'artist'> is specified, the channel artist's icon url is returned, 
if any.

=item $video->B<getIconData>(['artist'])

Returns a two-element array consisting of the extension (ie. "png", 
"gif", "jpeg", etc.) and the actual icon image (binary data), if any.
If B<'artist'> is specified, the channel artist's icon data is returned, 
if any.

=item $video->B<getImageURL>(['artist'])

Returns the URL for the video's "cover art" (usually larger) 
banner image.  If B<'artist'> is specified, the channel artist's image URL 
is returned, if any.  PragerU does not use separate banner images, so the 
icon (or artist's icon) url is returned.

=item $video->B<getImageData>(['artist'])

Returns a two-element array consisting of the extension (ie. "png", 
"gif", "jpeg", etc.) and the actual video's banner image (binary data).
If B<'artist'> is specified, the channel artist's image data is returned, 
if any..  PragerU does not use separate banner images, so the 
icon (or artist's icon) data is returned.

=item $video->B<getType>()

Returns the video's type ("PragerU").

=back

=head1 CONFIGURATION FILES

The default root location directory for StreamFinder configuration files 
is "~/.config/StreamFinder".  To use an alternate location directory, 
specify it in the "I<STREAMFINDER>" environment variable, ie.:  
B<$ENV{STREAMFINDER} = "/etc/StreamFinder">.

=over 4

=item ~/.config/StreamFinder/PragerU/config

Optional text file for specifying various configuration options 
for a specific site (submodule).  Each option is specified on a 
separate line in the format below:
NOTE:  Do not follow the lines with a semicolon, comma, or any other 
separator.  Non-numeric I<values> should be surrounded with quotes, either 
single or double.  Blank lines and lines beginning with a "#" sign as 
their first non-blank character are ignored as comments.

'option' => 'value' [,]

and the options are loaded into a hash used only by the specific 
(submodule) specified.  Valid options include 
I<-debug> => [0|1|2] and most of the L<LWP::UserAgent> options.  

Options specified here override any specified in I<~/.config/StreamFinder/config>.

=item ~/.config/StreamFinder/config

Optional text file for specifying various configuration options.  
Each option is specified on a separate line in the format below:

'option' => 'value' [,]

and the options are loaded into a hash used by all sites 
(submodules) that support them.  Valid options include 
I<-debug> => [0|1|2] and most of the L<LWP::UserAgent> options.

=back

NOTE:  Options specified in the options parameter list of the I<new()> 
function will override those corresponding options specified in these files.

=head1 KEYWORDS

prageru

=head1 DEPENDENCIES

L<URI::Escape>, L<HTML::Entities>, L<LWP::UserAgent>

=head1 RECCOMENDS

wget

=head1 BUGS

Please report any bugs or feature requests to C<bug-streamFinder-iheartradio at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=StreamFinder-PragerU>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc StreamFinder::PragerU

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=StreamFinder-PragerU>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/StreamFinder-PragerU>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/StreamFinder-PragerU>

=item * Search CPAN

L<http://search.cpan.org/dist/StreamFinder-PragerU/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2022 Jim Turner.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

package StreamFinder::PragerU;

use strict;
use warnings;
use URI::Escape;
use HTML::Entities ();
use LWP::UserAgent ();
use parent 'StreamFinder::_Class';

my $DEBUG = 0;

sub new
{
	my $class = shift;
	my $url = shift;

	return undef  unless ($url);

	my $self = $class->SUPER::new('PragerU', @_);
	$DEBUG = $self->{'debug'}  if (defined $self->{'debug'});

	my $baseURL = 'https://www.prageru.com';
	my @okStreams;
	$self->{'id'} = '';
	while (@_) {
		if ($_[0] =~ /^\-?keep$/o) {
			shift;
			if (defined $_[0]) {
				my $keeporder = shift;
				@okStreams = (ref($keeporder) =~ /ARRAY/) ? @{$keeporder} : split(/\,\s*/, $keeporder);
			}
		} else {
			shift;
		}
	}	
	if (!defined($okStreams[0]) && defined($self->{'keep'})) {
		@okStreams = (ref($self->{'keep'}) =~ /ARRAY/) ? @{$self->{'keep'}} : split(/\,\s*/, $self->{'keep'});
	}
	@okStreams = (qw(m3u8 mp4 m4a mpd mp3 ogg flac aac))  unless (defined $okStreams[0]);
	my $streamRegex = join('|',@okStreams);

	(my $url2fetch = $url) =~ s/\?.*$//;  #WE DO NOT CURRENTLY SUPPORT PLAYLISTS, ETC.
	my $ua = LWP::UserAgent->new(@{$self->{'_userAgentOps'}});		
	$ua->timeout($self->{'timeout'});
	$ua->cookie_jar({});
	$ua->env_proxy;
	my $html = '';
	my $response;

	$html = '';
	if ($url2fetch =~ m#^(https?\:\/\/[^\/]+)#) {
		$baseURL = $1;
		$self->{'id'} = $1  if ($url =~ m#\/([a-z\-\d]+)\/?$#);
	} else {
		$self->{'id'} = $url;
		$url2fetch = $baseURL . '/videos/' . $url;
	}

	print STDERR "-0(PragerU): FETCHING URL=$url2fetch= ID=".$self->{'id'}."=\n"  if ($DEBUG);
	$response = $ua->get($url2fetch);
	if ($response->is_success) {
		$html = $response->decoded_content;
	} else {
		print STDERR $response->status_line  if ($DEBUG);
	}
	print STDERR "-1: html=$html=\n"  if ($DEBUG > 1);

	return undef  unless ($html);  #STEP 1 FAILED, INVALID PragerU URL, PUNT!

	my $protocol = $self->{'secure'} ? '' : '?';
	$html =~ s/\\\\//gs;
	$html =~ s/\\\"/\"/gs;
	$self->{'_playbackID'} = ($html =~ m#\"playbackId\":\"([^\"]+)#s) ? $1 : '';
	$self->{'title'} = $1  if ($html =~ /\<h1[^\>]*\>([^\<]+)/is);
	$self->{'title'} ||= $1  if ($html =~ /\<title\>([^\<]+)/is);
	$self->{'title'} =~ s/\s+\|\s+PragerU\s*$//;
	$self->{'description'} = $1  if ($html =~ /\<p\s+class\=\"richText\"\>([^\<]+)/is);
	$self->{'description'} ||= $1  if ($html =~ m#\<meta\s+name\=\"description\"\s+content\=\"(.+?)\"\/\>#is);
	$self->{'iconurl'} = $1  if ($html =~ s#\"thumbnailUrl\"\:\[\"([^\"]+)\"\]\,?##is);
	$self->{'iconurl'} =~ s/\?.*$//;
	$self->{'imageurl'} = $self->{'iconurl'};
	if ($html =~ s#\"uploadDate\"\:\"([^\"]+)\"\,?##is) {
		$self->{'created'} = $1;
		$self->{'year'} = $1  if ($self->{'created'} =~ /(\d\d\d\d)/);
	}
	unless ($self->{'year'}) {
		if ($html =~ m#\,\"publishedAt\"\:\"([^\"]+)\"\,\"transcript\"#s) {
			$self->{'created'} = $1;
			$self->{'year'} = $1  if ($self->{'created'} =~ /(\d\d\d\d)/);
		}
	}
	$self->{'artist'} = $1  if ($html =~ s#\"author\"\:\"([^\"]+)\"\,?##is);
	if ($html =~ m# href\=\"(\/\@[^\"]+)\"[^\>]*\>\<img\s+.+?srcSet\=\"([^\s]+)[\s]+1x#s) {
		$self->{'albumartist'} = $baseURL . $1;
		$self->{'articonurl'} = $2;
		$self->{'articonurl'} = $1  if ($self->{'articonurl'} =~ m#\;image\=(.+)$#);
		$self->{'articonurl'} = uri_unescape($self->{'articonurl'});
		$self->{'artimageurl'} = $self->{'articonurl'};
	}
	if ($html =~ m#\"topics\"\:\[?\{([^\}]+)#is) {
		my $one = $1;
		$self->{'genre'} = $1  if ($one =~ m#\"name\"\:\"([^\"]+)#);
	}
	$self->{'genre'} ||= 'Video';
	if ($self->{'description'} =~ /\w/) {
		$self->{'description'} =~ s/\s+$//;
	} else {
		$self->{'description'} = $self->{'title'};
	}
	foreach my $i (qw(title artist description)) {
		$self->{$i} = HTML::Entities::decode_entities($self->{$i});
		$self->{$i} = uri_unescape($self->{$i});
		$self->{$i} =~ s/(?:\%|\\?u?00)([0-9A-Fa-f]{2})/chr(hex($1))/egso;
	}

	#NOW FIND THE STREAM(S):
	my %streams;
	while ($html =~ s#\"url\"\:\"(https$protocol\:\/\/[^\"]+)\"\,?##o) {
		(my $url = $1) =~ s/\?.*$//o;
		print STDERR "---FOUND STREAM URL=$url=\n"  if ($DEBUG && $url =~ m#\.(?:$streamRegex)$#);
		push (@{$streams{$1}}, $url)  if ($url =~ m#\.($streamRegex)$#);
	}
	#PACK STREAMS IN "-keep" ORDER:
	foreach my $ext (@okStreams) {
		if (defined $streams{$ext}) {
			foreach my $s (@{$streams{$ext}}) {
				push (@{$self->{'streams'}}, $s);
				++$self->{'cnt'};
			}
		}
	}
	if ($self->{'cnt'} == 0 && $self->{'_playbackID'} && $streamRegex =~ /\bm3u8\b/) {
		#NO STREAMS FOUND, TRY FALLBACK STREAM:
		push (@{$self->{'streams'}}, ('https://stream.media.prageru.com/'
				. $self->{'_playbackID'} . '.m3u8'));
		++$self->{'cnt'};
	}

	$self->{'total'} = $self->{'cnt'};
	$self->{'imageurl'} = $self->{'iconurl'};
	$self->{'Url'} = ($self->{'cnt'} > 0) ? $self->{'streams'}->[0] : '';
	print STDERR "-count=".$self->{'cnt'}."= iconurl=".$self->{'iconurl'}."=\n"  if ($DEBUG);
	print STDERR "--SUCCESS: 1st stream=".$self->{'Url'}."= total=".$self->{'total'}."=\n"
			if ($DEBUG && $self->{'cnt'} > 0);
	if ($DEBUG) {
		foreach my $i (sort keys %{$self}) {
			print STDERR "--KEY=$i= VAL=".$self->{$i}."=\n";
		}
	}

	return undef  unless ($self->{'cnt'} > 0);

	$self->_log($url);     #LOG IT.

	bless $self, $class;   #BLESS IT!

	return $self;
}

1
