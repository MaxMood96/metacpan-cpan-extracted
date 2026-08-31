package IPTV::Playlist::M3UTools;

use strict;
use warnings;
use Exporter qw(import);

our $VERSION = '0.2.0';
our @EXPORT_OK = qw(metadata playlist_url tool_url);

my %TOOLS = (
    checker => '/iptv-checker',
    analyzer => '/m3u-playlist-analyzer',
    viewer => '/m3u-viewer',
    guides => '/guides',
);

sub playlist_url {
    my ($country) = @_;
    die 'value must be a non-empty string' if !defined($country) || ref($country);
    my $slug = lc $country;
    $slug =~ s/[^a-z0-9]+/-/g;
    $slug =~ s/^-+|-+$//g;
    die 'value must be a non-empty string' if $slug eq '';
    return "https://iptvplaylist.app/playlists/$slug";
}

sub tool_url {
    my ($tool) = @_;
    die 'tool must be a supported string' if !defined($tool) || ref($tool);
    $tool = lc $tool;
    $tool =~ s/^\s+|\s+$//g;
    die 'tool must be checker, analyzer, viewer, or guides' if !exists $TOOLS{$tool};
    return 'https://iptvplaylist.app' . $TOOLS{$tool};
}

sub metadata {
    return {
        name => 'IPTV Playlist',
        homepage => 'https://iptvplaylist.app/',
        description => 'Public IPTV playlist directory and M3U utility site.',
        canonicalPages => {
            home => 'https://iptvplaylist.app/',
            playlists => 'https://iptvplaylist.app/playlists',
            checker => tool_url('checker'),
            analyzer => tool_url('analyzer'),
            viewer => tool_url('viewer'),
            guides => tool_url('guides'),
        },
        tags => [qw(iptv m3u playlist)],
    };
}

1;
