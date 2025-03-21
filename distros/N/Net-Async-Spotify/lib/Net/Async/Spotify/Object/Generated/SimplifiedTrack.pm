package Net::Async::Spotify::Object::Generated::SimplifiedTrack;

use strict;
use warnings;

our $VERSION = '0.002'; # VERSION
our $AUTHORITY = 'cpan:VNEALV'; # AUTHORITY

use mro;
use parent qw(Net::Async::Spotify::Object::Base);

=encoding utf8

=head1 NAME

Net::Async::Spotify::Object::Generated::SimplifiedTrack - Package representing Spotify SimplifiedTrack Object

=head1 DESCRIPTION

Autogenerated module.
Based on https://developer.spotify.com/documentation/web-api/reference/#objects-index
Check C<crawl-api-doc.pl> for more information.

=head1 PARAMETERS

Those are Spotify SimplifiedTrack Object attributes:

=over 4

=item artists

Type:Array[SimplifiedArtistObject]
Description:The artists who performed the track. Each artist object includes a link in href to more detailed information about the artist.

=item available_markets

Type:Array[String]
Description:A list of the countries in which the track can be played, identified by their ISO 3166-1 alpha-2 code.

=item disc_number

Type:Integer
Description:The disc number (usually 1 unless the album consists of more than one disc).

=item duration_ms

Type:Integer
Description:The track length in milliseconds.

=item explicit

Type:Boolean
Description:Whether or not the track has explicit lyrics ( true = yes it does; false = no it does not OR unknown).

=item external_urls

Type:ExternalUrlObject
Description:External URLs for this track.

=item href

Type:String
Description:A link to the Web API endpoint providing full details of the track.

=item id

Type:String
Description:The Spotify ID for the track.

=item is_local

Type:Boolean
Description:Whether or not the track is from a local file.

=item is_playable

Type:Boolean
Description:Part of the response when Track Relinking is applied. If true , the track is playable in the given market. Otherwise false.

=item linked_from

Type:LinkedTrackObject
Description:Part of the response when Track Relinking is applied and is only part of the response if the track linking, in fact, exists. The requested track has been replaced with a different track. The track in the linked_from object contains information about the originally requested track.

=item name

Type:String
Description:The name of the track.

=item preview_url

Type:String
Description:A URL to a 30 second preview (MP3 format) of the track.

=item restrictions

Type:TrackRestrictionObject
Description:Included in the response when a content restriction is applied.
See Restriction Object for more details.

=item track_number

Type:Integer
Description:The number of the track. If an album has several discs, the track number is the number on the specified disc.

=item type

Type:String
Description:The object type: “track”.

=item uri

Type:String
Description:The Spotify URI for the track.

=back

=cut

sub new {
    my ($class, %args) = @_;

    my $fields = {
        artists => 'Array[SimplifiedArtistObject]',
        available_markets => 'Array[String]',
        disc_number => 'Integer',
        duration_ms => 'Integer',
        explicit => 'Boolean',
        external_urls => 'ExternalUrlObject',
        href => 'String',
        id => 'String',
        is_local => 'Boolean',
        is_playable => 'Boolean',
        linked_from => 'LinkedTrackObject',
        name => 'String',
        preview_url => 'String',
        restrictions => 'TrackRestrictionObject',
        track_number => 'Integer',
        type => 'String',
        uri => 'String',
    };

    my $obj = next::method($class, $fields, %args);

    return $obj;
}

1;
