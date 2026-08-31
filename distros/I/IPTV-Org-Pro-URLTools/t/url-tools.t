use strict;
use warnings;
use Test::More;
use lib 'lib';
use IPTV::Org::Pro::URLTools qw(metadata search_url channel_url);

is metadata()->{homepage}, 'https://iptv-org.pro', 'metadata homepage';
is search_url('News & weather'), 'https://iptv-org.pro/search/?q=News%20%26%20weather', 'search URL';
is channel_url('us', 'public/news'), 'https://iptv-org.pro/channels/us/public%2Fnews/', 'channel URL';
done_testing;
