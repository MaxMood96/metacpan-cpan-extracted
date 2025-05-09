#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 7;
use Test::Exception;

BEGIN { use_ok('Digest::HighwayHash') };

is highway_hash64([1, 2, 3, 4], 'hello'), '11956820856122239241', 'highway_hash64';
is_deeply highway_hash128([1, 2, 3, 4], 'hello'), ['3048112761216189476', '13900443277579286659'], 'highway_hash128';
is_deeply highway_hash256([1, 2, 3, 4], 'hello'), ['8099666330974151427', '17027479935588128037', '4015249936799013189', '10027181291351549853'], 'highway_hash256';

throws_ok { highway_hash64 1, 'hello' }                qr/not an ARRAY reference/, 'bad key 1';
throws_ok { highway_hash128 [1, 2], 'hello' }          qr/Key for highway_hash must be a 4-element array/, 'bad key 2';
throws_ok { highway_hash256 [1, 2, 3, 4, 5], 'hello' } qr/Key for highway_hash must be a 4-element array/, 'bad key 3';
