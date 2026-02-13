use strict;
use warnings;
use Test::More;

my @modules = qw(
    WWW::Bund
    WWW::Bund::Registry
    WWW::Bund::Caller
    WWW::Bund::Auth
    WWW::Bund::Cache
    WWW::Bund::RateLimit
    WWW::Bund::HTTPRequest
    WWW::Bund::HTTPResponse
    WWW::Bund::Role::IO
    WWW::Bund::Role::Response
    WWW::Bund::Response::JSON
    WWW::Bund::Response::XML
    WWW::Bund::Response::Raw
    WWW::Bund::LWPIO
    WWW::Bund::API::Autobahn
    WWW::Bund::API::NINA
    WWW::Bund::API::PegelOnline
    WWW::Bund::API::Tagesschau
    WWW::Bund::API::Bundestag
    WWW::Bund::API::DWD
    WWW::Bund::CLI
    WWW::Bund::CLI::Formatter
    WWW::Bund::CLI::Strings
    WWW::Bund::CLI::Role::APICommand
    WWW::Bund::CLI::Cmd::List
    WWW::Bund::CLI::Cmd::Info
    WWW::Bund::CLI::Cmd::Autobahn
    WWW::Bund::CLI::Cmd::Pegel
    WWW::Bund::CLI::Cmd::Tagesschau
    WWW::Bund::CLI::Cmd::Nina
    WWW::Bund::CLI::Cmd::Bundestag
    WWW::Bund::CLI::Cmd::Dwd
    WWW::Bund::CLI::Cmd::Feiertage
    WWW::Bund::CLI::Cmd::Smard
    WWW::Bund::CLI::Cmd::Bundeshaushalt
    WWW::Bund::CLI::Cmd::Bundesrat
    WWW::Bund::CLI::Cmd::BundestagLobbyregister
    WWW::Bund::CLI::Cmd::DashboardDeutschland
    WWW::Bund::CLI::Cmd::Travelwarning
    WWW::Bund::CLI::Cmd::Ladestationen
    WWW::Bund::CLI::Cmd::EcoVisio
    WWW::Bund::CLI::Cmd::Hilfsmittel
);

plan tests => scalar @modules;

for my $mod (@modules) {
    use_ok($mod);
}
