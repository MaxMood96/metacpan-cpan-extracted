use strict;
use warnings;

use Test::Fatal qw{exception};
use FindBin::libs;
use URI::Shortener;
use Capture::Tiny qw{capture_merged};
use DBD::SQLite;

use Test::More tests => 5;

subtest 'happy path' => sub {
    my $s = URI::Shortener->new(
        domain => 'ACGT',
        prefix => 'https://go.mydomain.test/short',
        dbname => ':memory:',
        seed   => 1337,
        length => 10,
    );
    my $uri   = 'https://mydomain.test/somePath';
    my $short = $s->shorten($uri);
    is( $short,               'https://go.mydomain.test/short/CTTACCGGTC', "I do this...for da shorteez.  Especially URIs" );
    $short = $s->shorten($uri);
    is( $short,               'https://go.mydomain.test/short/CTTACCGGTC', "caching works" );
    is( $s->lengthen($short), $uri,                                "Lengthens, Hardens, Girthens & Fully Pleasures your URI" );
    $s->prune_before( time() + 10 );
    is( $s->lengthen($short), undef, "Pruning works" );

};

subtest 'Sovereign is he who tests his exceptions' => sub {
    my %bad;

    like( exception { URI::Shortener->new(%bad) }, qr/prefix/i, "You've just been pre-fixated" );
    $bad{prefix} = 'jumbo://hugs';
    like( exception { URI::Shortener->new(%bad) }, qr/dbname/i, "Get in the DB shinji" );
    $bad{dbname} = ':memory:';
    like( exception { URI::Shortener->new(%bad) }, qr/seed/i, "My seed hath slain the chess dragon" );
};

# pathological case
subtest 'going to the circle 8 track' => sub {
    my $s = URI::Shortener->new(
        domain => 'A',
        prefix => 'bar',
        dbname => ':memory:',
        seed   => 1337,
        length => 1,
    );
    is( $s->shorten('foo'), 'bar/A', "Works fine, right?");
    like( exception { capture_merged { $s->shorten('hug') } }, qr/too many failures/i, "Stack smashing guard encountered");
};

# Alternative names
subtest 'alternative names' => sub {
    my $s = URI::Shortener->new(
        domain => 'ACGT',
        prefix => 'https://go.mydomain.test/short',
        dbname => ':memory:',
        seed   => 1337,
        length => 10,
        uri_tablename    => 'shortener_uris',
        prefix_tablename => 'shortener_prefix',
        uri_idxname      => 'shortener_uri_idx',
        prefix_idxname   => 'shortener_prefix_idx',
        cipher_idxname   => 'shortener_cipher_idx',
        created_idxname  => 'shortener_created_idx',
    );
    my $uri   = 'https://mydomain.test/somePath';
    my $short = $s->shorten($uri);
    is( $short,               'https://go.mydomain.test/short/CTTACCGGTC', "I do this...for da shorteez.  Especially URIs" );
    $short = $s->shorten($uri);
    is( $short,               'https://go.mydomain.test/short/CTTACCGGTC', "caching works" );
    is( $s->lengthen($short), $uri,                                "Lengthens, Hardens, Girthens & Fully Pleasures your URI" );
    $s->prune_before( time() + 10 );
    is( $s->lengthen($short), undef, "Pruning works" );
};

# Migration
subtest 'migration' => sub {
    my $s = URI::Shortener->new(
        prefix => 'https://go.mydomain.test/short',
        dbname => ':memory:',
        seed   => 1337,
        length => 10,
    );
    my $uri   = 'https://mydomain.test/somePath';
    my $short = $s->shorten($uri);
    is( $short,               'https://go.mydomain.test/short/dZennAUZHG', "Can build basic shortener DB" );

    # Slam in uris to force batching
    my $uri2;
    foreach my $idx (0..10_000) {
        $uri2 = "https://mydomain$idx/somePath";
        eval { $s->shorten($uri2) };
    }

    my $s2 =URI::Shortener->new(
        prefix => 'https://go.mydomain.test/short',
        dbname => ':memory:',
        seed   => 1337,
        length => 10,
    );

    $s->migrate($s2);
    my $long = $s2->lengthen($s->shorten($uri));
    is( $long, $uri, "First record migrated");
    $long = $s2->lengthen($s->shorten($uri2));
    is( $long, $uri2, "10kth record migrated");
};

