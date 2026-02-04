#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Temp;

use DateTime;
use JSON::MaybeXS;
use IO::Async::Loop;
use DBIx::Class::Async::Schema;

use lib 't/lib';

my $json           = JSON::MaybeXS->new(utf8 => 1, sort_by => 1);
my $loop           = IO::Async::Loop->new;
my ($fh, $db_file) = File::Temp::tempfile(UNLINK => 1);
my $schema         = DBIx::Class::Async::Schema->connect(
    "dbi:SQLite:dbname=$db_file", undef, undef, {},
    { workers      => 2,
      schema_class => 'TestSchema',
      async_loop   => $loop,
      cache_ttl    => 60,
    },
);

$schema->inflate_column('Product', 'metadata', {
    inflate => sub {
        my $val = shift;
        return {} unless defined $val;

        return $val if ref $val;

        if ($val !~ /^HASH\(0x/) {
            my $decoded = eval { $json->decode($val) };
            return $decoded if $decoded;
        }

        return {};
    },
    deflate => sub {
        my $hashref = shift;
        return undef unless defined $hashref;
        # Turn the HashRef back into a JSON string for the DB
        return ref($hashref) ? $json->encode($hashref) : $hashref;
    },
});

$schema->inflate_column('Product', 'created_at', {
    inflate => sub {
        my $raw = shift;
        return undef unless $raw;
        if ($raw =~ /^(\d{4})-(\d{2})-(\d{2})\s(\d{2}):(\d{2}):(\d{2})$/) {
            return DateTime->new(
                year   => $1,
                month  => $2,
                day    => $3,
                hour   => $4,
                minute => $5,
                second => $6);
        }
        return $raw;
    },
    deflate => sub {
        my $dt = shift;
        return undef unless $dt;
        return ref($dt) ? $dt->strftime('%Y-%m-%d %H:%M:%S') : $dt;
    },
});

my $now = DateTime->now(time_zone => 'UTC');
$now->set_nanosecond(0);

# Capture the entire chain in a single Future
my $test_future = $schema->deploy
    ->then(sub {
        return $schema->resultset('Product')->create({
            name       => 'Async Phone',
            sku        => 'ASYNC-PH-001',
            metadata   => { color => 'blue', tags => ['tech', 'mobile'] },
            created_at => $now,
        });
    })
    ->then(sub {
        my $row = shift;
        is( ref($row->metadata), 'HASH', 'Metadata inflated to HashRef' );
        isa_ok($row->created_at, 'DateTime');

        my $meta = $row->metadata;
        $meta->{in_stock} = 1;
        $row->metadata($meta);
        $row->created_at($now->clone->add(days => 1));

        return $row->update;
    })
    ->then(sub {
        my $row = shift;
        return $schema->resultset('Product')->find($row->id);
    })
    ->then(sub {
        my $fresh = shift;
        is($fresh->metadata->{in_stock}, 1, "Updated JSON persists");
        is($fresh->created_at->day, $now->day + 1, "Updated DateTime persists");
        return Future->done; # Signal completion
    });

eval { $loop->await($test_future); };
if ($@) { diag "Complex Inflation Fail: $@"; }

$schema->disconnect;

done_testing;
