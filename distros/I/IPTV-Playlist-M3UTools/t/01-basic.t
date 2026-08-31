use strict;
use warnings;
use Test::More tests => 3;
use lib 'lib';
use IPTV::Playlist::M3UTools qw(metadata playlist_url tool_url);

is playlist_url('United Kingdom'), 'https://iptvplaylist.app/playlists/united-kingdom';
is tool_url('checker'), 'https://iptvplaylist.app/iptv-checker';
is metadata->{homepage}, 'https://iptvplaylist.app/';
