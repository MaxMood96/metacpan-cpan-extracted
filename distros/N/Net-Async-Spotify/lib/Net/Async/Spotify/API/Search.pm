package Net::Async::Spotify::API::Search;

use strict;
use warnings;

our $VERSION = '0.002'; # VERSION
our $AUTHORITY = 'cpan:VNEALV'; # AUTHORITY

use mro;
use parent qw(Net::Async::Spotify::API::Generated::Search);

use Log::Any qw($log);
use Syntax::Keyword::Try;
use JSON::MaybeUTF8 qw(:v1);
use Net::Async::Spotify::Object;

=encoding utf8

=head1 NAME

Net::Async::Spotify::API::Search - Package representing Main Spotify Search API

=head1 DESCRIPTION

Main module for an Autogenerated one L<Net::Async::Spotify::API::Generated::Search>.
Will hold all extra functionality for Spotify Search API

=head1 METHODS

=cut

sub parser {
    my ( $self, $decoded_res, $expected ) = @_;

    my $mapped_res;
    $mapped_res = $decoded_res ? Net::Async::Spotify::Object->new($decoded_res, $expected) : $decoded_res;

   return $mapped_res;
}

sub parse_response {
    my ( $self, $decoded_res, $expected ) = @_;

    try {
        return $decoded_res ? Net::Async::Spotify::Object->new($decoded_res, $expected) : $decoded_res;
    } catch ($e) {
        $log->warnf('Could not Map Spotify API Response to its Object %s | Error: %s | data: %s', $expected, $e, $decoded_res);
        return $decoded_res;
    }
}
1;
