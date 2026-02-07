=head1 NAME

StreamFinder::Zeno - Fetch actual raw streamable URLs from radio-stations and podcasts on zeno.fm

=head1 AUTHOR

This module is Copyright (C) 2017-2026 by

Jim Turner, C<< <turnerjw784 at yahoo.com> >>
		
Email: turnerjw784@yahoo.com

All rights reserved.

You may distribute this module under the terms of either the GNU General 
Public License or the Artistic License, as specified in the Perl README 
file.

=head1 SYNOPSIS

	#!/usr/bin/perl

	use strict;

	use StreamFinder::Zeno;

	die "..usage:  $0 ID|URL\n"  unless ($ARGV[0]);

	my $station = new StreamFinder::Zeno($ARGV[0]);

	die "Invalid URL or no streams found!\n"  unless ($station);

	my $firstStream = $station->get();

	print "First Stream URL=$firstStream\n";

	my $url = $station->getURL();

	print "Stream URL=$url\n";

	my $stationTitle = $station->getTitle();
	
	print "Title=$stationTitle\n";
	
	my $stationDescription = $station->getTitle('desc');
	
	print "Title=$stationDescription\n";
	
	my $stationID = $station->getID();

	print "Station ID=$stationID\n";
	
	my $genre = $station->{'genre'};

	print "Genre=$genre\n"  if ($genre);
	
	my $icon_url = $station->getIconURL();

	if ($icon_url) {   #SAVE THE ICON TO A TEMP. FILE:

		my ($image_ext, $icon_image) = $station->getIconData();

		if ($icon_image && open IMGOUT, ">/tmp/${stationID}.$image_ext") {

			binmode IMGOUT;

			print IMGOUT $icon_image;

			close IMGOUT;

		}

	}

	my $stream_count = $station->count();

	print "--Stream count=$stream_count=\n";

	my @streams = $station->get();

	foreach my $s (@streams) {

		print "------ stream URL=$s=\n";

	}

=head1 DESCRIPTION

StreamFinder::Zeno accepts a valid radio station or podcast ID or URL on 
Zeno.fm and returns the actual stream URL(s), title, and cover art icon for 
that station.  The purpose is that one needs one of these URLs in order to 
have the option to stream the station in one's own choice of media player 
software rather than using their web browser and accepting any / all flash, 
ads, javascript, cookies, trackers, web-bugs, and other crapware that can come 
with that method of play.  The author uses his own custom all-purpose media 
player called "fauxdacious" (his custom hacked version of the open-source 
"audacious" audio player).  "fauxdacious" can incorporate this module to 
decode and play Zeno.fm streams.

Generally, only one stream will be returned for each station.  

=head1 SUBROUTINES/METHODS

=over 4

=item B<new>(I<ID>|I<url> [, I<-secure> [ => 0|1 ]] 
[, I<-debug> [ => 0|1|2 ]])

Accepts a Zeno.fm station or podcast ID or URL and creates and returns a new 
station object, or I<undef> if the URL is not a valid Zeno.fm station or no 
streams are found.  The URL can be the full URL, 
ie. I<https://www.zeno.fm/radio/>B<station-id>, or just I<station-id>, 
I<https://www.zeno.fm/podcast/>B<podcast-id>/episodes/B<episode-id> or just 
I<podcast-id>/I<episode-id>, or I<https://www.zeno.fm/podcast/>B<podcast-id> or 
just I<p/podcast-id>.  If a podcast page URL is specified without the 
episode-id part, then the first (latest?) episode will be returned.

The optional I<-secure> argument can be either 0 or 1 (I<false> or I<true>).  
If 1 then only secure ("https://") streams will be returned.  Currently, all 
known Zeno streams seem to be secure ("https://").

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
stream found.  [site]:  The site name (Zeno).  [url]:  The url searched 
for streams.  
[time]: Perl timestamp when the line was logged.  [title], [artist], [album], 
[description], [year], [genre], [total], [albumartist]:  The corresponding 
field data returned (or "I<-na->", if no value).

=item $station->B<get>(I<['playlist']>)

Returns an array of strings representing all stream URLs found.
If I<"playlist"> is specified, and the URL is a podcast page, then an extended 
m3u playlist is returned instead of stream url(s), Otherwise, the array will 
likely contain a stream for each episode found in order of latest to oldest, 
as displayed on the podcast's web-page.
=item $station->B<getURL>([I<options>])

Similar to B<get>() except it only returns a single stream representing 
the first valid stream found.  

Current options are:  I<"random">, I<"nopls">, and I<"noplaylists">.  
By default, the first ("best"?) stream is returned.  If I<"random"> is 
specified, then a random one is selected from the list of streams found.  
If I<"nopls"> is specified, and the stream to be returned is a ".pls" playlist, 
it is first fetched and the first entry (or a random entry if I<"random"> is 
specified) is returned.  This is needed by Fauxdacious Mediaplayer.
If I<"noplaylists"> is specified, and the stream to be returned is a 
"playlist" (either .pls or .m3u? extension), it is first fetched and the first 
entry (or a random entry if I<"random"> is specified) in the playlist 
is returned.

=item $station->B<count>(I<['playlist']>)

Returns the number of streams found for the station or podcasts 
(almost always 1 for Zeno.fm).  If I<"playlist"> is specified, the number of 
episodes returned in the playlist is returned (the playlist can have more than 
one item if a podcast page URL is specified).


=item $station->B<getID>()

Returns the station's or podcast's Zeno.fm ID (alphanumeric).

=item $station->B<getTitle>(['desc'])

Returns the station's or podcast's title, or (long description).  

=item $station->B<getIconURL>()

Returns the URL for the station's or podcast's "cover art" icon image, if any.

=item $station->B<getIconData>()

Returns a two-element array consisting of the extension (ie. "png", 
"gif", "jpeg", etc.) and the actual icon image (binary data), if any.

=item $station->B<getImageURL>()

Returns the URL for the station's "cover art" (usually larger) 
banner image.  Zeno.fm Podcasts do not have a separate banner image.

=item $station->B<getImageData>()

Returns a two-element array consisting of the extension (ie. "png", 
"gif", "jpeg", etc.) and the actual station's banner image (binary data).  
Zeno.fm Podcasts do not have a separate banner image.

=item $station->B<getType>()

Returns the station's / podcast's type ("Zeno").

=back

=head1 CONFIGURATION FILES

The default root location directory for StreamFinder configuration files 
is "~/.config/StreamFinder".  To use an alternate location directory, 
specify it in the "I<STREAMFINDER>" environment variable, ie.:  
B<$ENV{STREAMFINDER} = "/etc/StreamFinder">.

=over 4

=item ~/.config/StreamFinder/Zeno/config

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

Options specified here override any specified in 
I<~/.config/StreamFinder/config>.

Among options valid for Zeno streams is the I<-notrim> described in the 
B<new()> function.  

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

Zeno

=head1 DEPENDENCIES

L<URI::Escape>, L<HTML::Entities>, L<LWP::UserAgent>

=head1 RECCOMENDS

wget

=head1 BUGS

Please report any bugs or feature requests to C<bug-streamFinder-Zeno at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=StreamFinder-Zeno>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc StreamFinder::Zeno

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=StreamFinder-Zeno>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/StreamFinder-Zeno>

=item * Search CPAN

L<http://search.cpan.org/dist/StreamFinder-Zeno/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2017-2026 Jim Turner.

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

package StreamFinder::Zeno;

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

	my $self = $class->SUPER::new('Zeno', @_);
	$DEBUG = $self->{'debug'}  if (defined $self->{'debug'});
	$self->{'notrim'} = 0;
	while (@_) {
		if ($_[0] =~ /^\-?notrim$/o) {
			shift;
			$self->{'notrim'} = (defined $_[0]) ? shift : 1;
		} else {
			shift;
		}
	}

	my $baseURL = 'https://zeno.fm';
	my $isStation;
	my $isPodcastPage;
	my @epiStreams = ();
	my @epiTitles = ();
	my $tryit = 0;

TRYIT:
	(my $url2fetch = $url) =~ s#\/$##;
	print STDERR "-0(Zeno): URL=$url= try=$tryit=\n"  if ($DEBUG);
	if ($url =~ /^https?\:/) {
		if ($url =~ m#\/podcast\/([^\/]+)\/episodes?\/([^\/\?\&]+)#) {
			$self->{'id'} = "$1/$2";
			$url2fetch =~ s#\/episode\/#\/episodes\/#;  #CATCH SOME FAT-FINGERS!
		} elsif ($url =~ m#\/(podcast|radio)\/([^\/\?\&]+)#) {
			$self->{'id'} = $2;
		} else {
			print STDERR "--Invalid Zeno URL (not station, podcast or episode), PUNT!\n";
			return undef;
		}
		$isStation = ($url =~ m#\/radio\/#) ? 1 : 0;
		my $pctype = ($self->{'id'} =~ m#\/# ? 'EPISODE' : 'PODCAST');
		print STDERR "-We're a full " . ($isStation ? 'STATION' : $pctype)
				. " url($url2fetch).\n"  if ($DEBUG);
	} elsif ($url =~ m#\/#) {
		my ($pcid, $epid) = split(m#\/#, $url);
		$self->{'id'} = $url;
		$url2fetch = "${baseURL}/podcast/" . (($self->{'id'} =~ s#^p(?:odcast)?\/##)
				? $epid : "$pcid/episodes/$epid");
		$isStation = 0;
		print STDERR "-We're a podcast or episode-ID(".$self->{'id'}.") (url:=$url2fetch).\n"
				if ($DEBUG);
	} else {
		$self->{'id'} = $url;
		$url2fetch = 'https://www.zeno.fm/radio/' . $url;
		$isStation = 1;
		print STDERR "-We're a radio-station ID(".$self->{'id'}.") (url:=$url2fetch).\n"
				if ($DEBUG);
	}
	$isPodcastPage = ($isStation || $self->{'id'} =~ m#\/#) ? 0 : 1;
	$self->{'cnt'} = 0;
	my $html = '';
	my $ua = LWP::UserAgent->new(@{$self->{'_userAgentOps'}});		
	$ua->timeout($self->{'timeout'});
	$ua->cookie_jar({});
	$ua->env_proxy;
	my $response = $ua->get($url2fetch);
	if ($response->is_success) {
		$html = $response->decoded_content;
	} else {
		print STDERR $response->status_line  if ($DEBUG);
	}
	print STDERR "-1: html=$html=\n"  if ($DEBUG > 1);
	return undef  unless ($html);  #STEP 1 FAILED, INVALID STATION URL, PUNT!

	my $have1stepisode = 0;
	if ($isPodcastPage) {   #WE'RE A PODCAST PAGE (NOT SPECIFIC EPISODE), GATHER PLAYLIST DATA:
		print STDERR "..Podcast PAGE, extract episodes for playlist, then return 1st episode:\n"  if ($DEBUG);
		$html =~ s#^.+?\,\{\"podcastId\"\:\d+\}\,#AGGIES#s;
		while ($html =~ s#(^.+?)\,\{"podcastId\"\:\d+\,\"episodeId\"\:\d+\}\,##so) {
			my $epistuff = $1;
			if ($epistuff =~ m#\d\}\,\"[a-zA-Z0-9\-\_]+\"\,\"([^\"]+)\"\,\"([^\"]+)\"#s) {
				my $epiID = $1;
				my $epititle = $2;
				if ($epistuff =~ s#\,\"(https?\:\/\/anchor\.fm\/[^\"]*)\"##s
						|| $epistuff =~ s#\,\"(https?\:\/\/[^\"]+(?:mp3|ogg|flac|webm|acc|m3u8))\"##s) {
					my $epistream = $1;
					unless ($self->{'secure'} && $epistream !~ /^https/o) {
						push @{$self->{'streams'}}, $epistream;
						$self->{'cnt'}++;
						push @epiStreams, $epistream;
						push @epiTitles, $epititle;
						$have1stepisode ||= $epiID;						
					}
				}
			}
		}
	}
	if ($isStation) {   #WE'RE A RADIO-STATION:  PROGRMMER NOTE: DO *NOT* USE elsif HERE!
		print STDERR "-We're a radio-station page!\n"  if ($DEBUG);
		$self->{'title'} = $1  if ($html =~ m#\,\"$$self{'id'}\"\,\"([^\"]+)#s);
		$self->{'title'} ||= $1  if ($html =~ m#\<meta\s+property="(?:og|twitter)\:title\"\s+content\=\"([^\"]+)\"#s);
		$self->{'title'} ||= $1  if ($html =~ m#\<title\>([^\<]+)\"#si);
		$self->{'description'} = $1  if ($html =~ s#\<div\s+class\=\"description[^\>]+\>(.+?)\<\/div\>##s);
		$self->{'description'} ||= $self->{'title'};
		if ($html =~ s#\<h2\>(.+?\<\/h2\>)##si) {
			my $channeldata = $1;
			$self->{'albumartist'} = $1  if ($channeldata =~ s#\<a(?:.+?)href\=\"([^\"]+)\"[^\>]*\>##s);
			$self->{'albumartist'} = $baseURL . $self->{'albumartist'}  if ($self->{'albumartist'} =~ m#^\/#);
			$self->{'artist'} = $1  if ($channeldata =~ m#\s*([^\<]+)#s);
		} else {
			($self->{'albumartist'} = $url2fetch) =~ s#\/podcast\/.+$#\/#;
		}
		$self->{'created'} = ($html =~ m#\>([^\<]+)\<\/span\>\<\/div\>\<h1#) ? $1 : '';
		$self->{'total'} = $self->{'cnt'};
		$self->{'Url'} = ($self->{'total'} > 0) ? $self->{'streams'}->[0] : '';
		while ($html =~ s#\,\"(https?\:\/\/anchor\.fm\/[^\"]*)\"##s
				|| $html =~ s#\,\"(https?\:\/\/[^\"]+(?:mp3|ogg|flac|webm|acc|m3u8))\"##s) {
			my $stream = $1;
			print STDERR "----RADIO STREAM FOUND1 ($stream)!\n"  if ($DEBUG);
			unless ($self->{'secure'} && $stream !~ /^https/o) {
				push @{$self->{'streams'}}, $stream;
				$self->{'cnt'}++;
			}
		}

		#NOW REMOVE A BUNCH OF HTML TO MAKE REST EASIER:

		$html =~ s#^.+?(\<script\s+type\=\"application\/json\")#$1#s;

		if ($html =~ s#\,\"(https?\:\/\/stream[^\"]+)\"##) {
			my $stream = $1;
			print STDERR "----RADIO STREAM FOUND2 ($stream)!\n"  if ($DEBUG);
			unless ($self->{'secure'} && $stream !~ /^https/o) {
				push @{$self->{'streams'}}, $stream;
				$self->{'cnt'}++;
			}
		}
		$self->{'iconurl'} = $1  if ($html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s);
		$html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s;  #THIS ONE'S NO GOOD (SKIP OVER)!
		$self->{'imageurl'} = ($html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s) ? $1 : $self->{'artimageurl'};

		$self->{'iconurl'} ||= $1  if ($html =~ s#^.+?\,\"(https?\:\/\/image[^\"]+)\"##s);
		$self->{'iconurl'} ||= ($html =~ m#\,\"(https?\:\/\/[^\"]+)#s) ? $1 : $self->{'iconurl'};
		$self->{'imageurl'} ||= $self->{'iconurl'};
	} else {   #WE'RE A PODCAST OR PODCAST EPISODE PAGE:
		print STDERR "---isPodcastPage=$isPodcastPage, have1stEp=$have1stepisode, tryit=$tryit.\n";
		if ($isPodcastPage && $have1stepisode && !$tryit) {
			$url = "$$self{'id'}/$have1stepisode";
			++$tryit;
			if ($DEBUG) {
				foreach my $f (sort keys %{$self}) {
					print STDERR "--PODCAST.KEY=$f= VAL=$$self{$f}=\n";
				}
			}
			print STDERR "------Podcast PAGE: loopback & FETCH 1ST EPISODE ($url)\n\n"
					if ($DEBUG);

			goto TRYIT;  #PODCAST PAGE: LOOP BACK TO FETCH 1ST EPISODE:
		}

		#IF HERE, WE HAVE A SPECIFIC PODCAST EPISODE:
		print STDERR "--We are an EPISODE page!\n"  if ($DEBUG);
		$self->{'genre'} = 'Podcast';
		my $epID = ($self->{'id'} =~ m#\/(.+)$#) ? $1 : '';
		$self->{'title'} = $1  if ($epID && $html =~ m#\,\"$epID\"\,\"([^\"]+)#s);
		$self->{'title'} ||= $1  if ($html =~ m#\<meta\s+property="(?:og|twitter)\:title\"\s+content\=\"([^\"]+)\"#s);
		$self->{'title'} ||= $1  if ($html =~ m#\<title\>([^\<]+)\"#si);
		$self->{'description'} = $1  if ($html =~ s#\<div\s+class\=\"description[^\>]+\>(.+?)\<\/div\>##s);
		$self->{'description'} ||= $self->{'title'};
		if ($html =~ s#\<h2\>(.+?\<\/h2\>)##si) {
			my $channeldata = $1;
			$self->{'albumartist'} = $1  if ($channeldata =~ s#\<a(?:.+?)href\=\"([^\"]+)\"[^\>]*\>##s);
			$self->{'albumartist'} = $baseURL . $self->{'albumartist'}  if ($self->{'albumartist'} =~ m#^\/#);
			$self->{'artist'} = $1  if ($channeldata =~ m#\s*([^\<]+)#s);
		} else {
			($self->{'albumartist'} = $url2fetch) =~ s#\/podcast\/.+$#\/#;
		}
		$self->{'created'} = ($html =~ m#\>([^\<]+)\<\/span\>\<\/div\>\<h1#) ? $1 : '';

		#NOW REMOVE A BUNCH OF HTML TO MAKE REST EASIER:

		$html =~ s#^.+?(\<script\s+type\=\"application\/json\")#$1#s;

		if ($html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s) {
			my $artist_website = $1;
			$self->{'artist'} .= ' - '  if ($self->{'artist'});
			$self->{'artist'} .= $artist_website;
		}
		$self->{'artimageurl'} = $1  if ($html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s);
		$self->{'articonurl'} = ($html =~ s#\,\"(https?\:\/\/[^\"]*)\"##s) ? $1 : $self->{'artimageurl'};

		while ($html =~ s#\,\"(https?\:\/\/anchor\.fm\/[^\"]*)\"##s
				|| $html =~ s#\,\"(https?\:\/\/[^\"]+(?:mp3|ogg|flac|webm|acc|m3u8))\"##s) {
			my $stream = $1;
			unless ($self->{'secure'} && $stream !~ /^https/o) {
				push @{$self->{'streams'}}, $stream;
				$self->{'cnt'}++;
			}
		}
		$self->{'iconurl'} = $1  if ($html =~ s#^.+?\,\"(https?\:\/\/image[^\"]+)\"##s);
		$self->{'imageurl'} = ($html =~ m#\,\"(https?\:\/\/[^\"]+)#s) ? $1 : $self->{'iconurl'};
		$self->{'iconurl'} ||= $self->{'imageurl'};
		$self->{'created'} ||= $1  if ($html =~ m#\}\,\"([^\"]")\,\[#s);
		$self->{'year'} = ($self->{'created'} && $self->{'created'} =~ /(\d\d\d\d)/s) ? $1 : '';
		#IF WAS ORIGINALLY A PODCAST PAGE (NOW 1ST EPISODE), BUILD THE PLAYLIST:
		$self->{'playlist'} = "#EXTM3U\n";
		if ($#epiStreams >= 0) {  #PODCAST PAGE (MULTIPLE EPISODES):
			$self->{'playlist_cnt'} = scalar @epiStreams;
			for (my $i=0;$i<=$#epiStreams;$i++) {
				last  if ($i > $#epiTitles);
				$self->{'playlist'} .= "#EXTINF:-1, " . $epiTitles[$i] . "\n";
				$self->{'playlist'} .= "#EXTART:" . $self->{'artist'} . "\n"
						if ($self->{'artist'});
				$self->{'playlist'} .= "#EXTALB:" . $self->{'album'} . "\n"
						if ($self->{'album'});
				$self->{'playlist'} .= "#EXTGENRE:" . $self->{'genre'} . "\n"
						if ($self->{'genre'});
				$self->{'playlist'} .= $epiStreams[$i] . "\n";
			}
		} else {   #EPISODE PAGE (SINGLE EPISODE):
			$self->{'playlist_cnt'} = 1;
			$self->{'playlist'} .= "#EXTINF:-1, " . $self->{'title'} . "\n";
			$self->{'playlist'} .= "#EXTART:" . $self->{'artist'} . "\n"
					if ($self->{'artist'});
			$self->{'playlist'} .= "#EXTALB:" . $self->{'album'} . "\n"
					if ($self->{'album'});
			$self->{'playlist'} .= "#EXTGENRE:" . $self->{'genre'} . "\n"
					if ($self->{'genre'});
			$self->{'playlist'} .= ${$self->{'streams'}}[0] . "\n";
		}
	}
	#CLEAN UP SOME COMMON FIELDS:
	$self->{'title'} = HTML::Entities::decode_entities($self->{'title'});
	$self->{'title'} = uri_unescape($self->{'title'});
	$self->{'title'} =~ s/(?:\%|\\[ux\%]?00|\bu00)([0-9A-Fa-f]{2})/chr(hex($1))/egs;
	$self->{'title'} =~ s/^\s*Listen to\s+//i;  #TIDY UP TITLE A BIT.
	$self->{'title'} =~ s/\s*\|\s*Zeno.FM//;  #TIDY UP TITLE A BIT.
	$self->{'description'} = HTML::Entities::decode_entities($self->{'description'});
	$self->{'description'} = uri_unescape($self->{'description'});
	$self->{'description'} =~ s/(?:\%|\\[ux\%]?00|\bu00)([0-9A-Fa-f]{2})/chr(hex($1))/egs;  #\u003C

	$self->{'total'} = $self->{'cnt'};
	$self->{'Url'} = ($self->{'total'} > 0) ? $self->{'streams'}->[0] : '';
	if ($DEBUG) {
		foreach my $f (sort keys %{$self}) {
			print STDERR "--KEY=$f= VAL=$$self{$f}=\n";
		}
		print STDERR "-SUCCESS: 1st stream=".$self->{'Url'}."=\n"  if ($self->{'cnt'} > 0);;
	}

	$self->_log($url);

	bless $self, $class;   #BLESS IT!

	return $self;
}

1
