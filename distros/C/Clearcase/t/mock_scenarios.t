#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 7;
use lib 't/lib';
use lib 'lib';
use MockClearcase;

my $cc = MockClearcase->new;
isa_ok ($cc, 'MockClearcase');
isa_ok ($cc, 'Clearcase');

# Test global attributes
is ($cc->region, 'mock_region', 'Got mocked region');
is ($cc->client, 'mock_client', 'Got mocked client');

# Test lsvob simulation
my ($status, @output) = $cc->execute ('lsvob -s');
is ($status,    0,                'Execute status 0');
is ($output[0], '/vobs/mock_vob', 'Got mocked vob');

# Test describe
($status, @output) = $cc->execute ('describe -fmt "%Na" vob:/vobs/mock_vob');
like ($output[0], qr/Name=\/vobs\/mock_vob/, 'Describe output matches');
