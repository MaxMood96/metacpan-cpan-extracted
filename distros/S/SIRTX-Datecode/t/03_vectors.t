#!/usr/bin/perl -w

use v5.10;
use lib 'lib', '../lib'; # able to run prove in project dir and .t locally

use constant {
    vectors_iso8601 => [map {$_, $_.'Z'} qw(
        1582 1678 1904
        1905 1905-01 1905-12 1960 1960-01 1960-02 1979 1979-01 1979-12
        1980 1980-01 1980-01-01 1980-12-31 2024 2024-01 2024-03-12 2058 2058-01 2058-01-01 2058-12 2058-12-31
        2059 2059-01 2059-12 2080 2080-05 2114 2114-01 2114-12
        2114 2222 2333 2440
        )],
    vectors_datecode => [0, 2..5, 1000..1005, 32768, 65535, 4294967295],
};

use Test::More tests => (1 + 4*scalar(@{vectors_iso8601()}) + 2*scalar(@{vectors_datecode()}));

use_ok('SIRTX::Datecode');

foreach my $iso8601 (@{vectors_iso8601()}) {
    my $dc = SIRTX::Datecode->new(iso8601 => $iso8601);
    note('Testing for: ', $iso8601);
    isa_ok($dc, 'SIRTX::Datecode');
    cmp_ok($dc->datecode, '<', 65536);
    cmp_ok($dc->datecode, '>', 0);
    is($dc->iso8601, $iso8601);
}

foreach my $datecode (@{vectors_datecode()}) {
    my $dc = SIRTX::Datecode->new(datecode => $datecode);
    note('Testing for: ', $datecode);
    isa_ok($dc, 'SIRTX::Datecode');
    is($dc->datecode, $datecode);
}

exit 0;
