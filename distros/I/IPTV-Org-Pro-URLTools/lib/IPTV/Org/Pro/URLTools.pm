package IPTV::Org::Pro::URLTools;

use strict;
use warnings;
use Exporter qw(import);
use URI::Escape qw(uri_escape_utf8);

our $VERSION = '0.2.0';
our @EXPORT_OK = qw(metadata search_url country_url category_url channel_url);
my $BASE = 'https://iptv-org.pro';

sub metadata { return {name => 'iptv-org pro', homepage => $BASE, description => 'Independent public television channel directory URL helpers.'}; }
sub search_url { return "$BASE/search/?q=" . uri_escape_utf8($_[0]); }
sub country_url { return "$BASE/countries/" . uri_escape_utf8($_[0]) . '/'; }
sub category_url { return "$BASE/categories/" . uri_escape_utf8($_[0]) . '/'; }
sub channel_url { return "$BASE/channels/" . uri_escape_utf8($_[0]) . '/' . uri_escape_utf8($_[1]) . '/'; }
1;
