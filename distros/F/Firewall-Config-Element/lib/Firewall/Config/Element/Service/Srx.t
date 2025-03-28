#!/usr/bin/env perl
use strict;
use warnings;

use Test::Simple tests => 5;
use Mojo::Util qw(dumper);

use Firewall::Config::Element::Service::Srx;
use Firewall::Config::Element::ServiceMeta::Srx;

=lala
#设备Id
has fwId => (
    is => 'ro',
    isa => 'Int',
    required => 1,
);

#在同一个设备中描述一个对象的唯一性特征
has sign => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_buildSign',
);


has srvName => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


has metas => (
    is => 'ro',
    does => 'HashRef[Firewall::Config::Element::ServiceMeta::Role]',
    default => sub { {} },
);

has dstPortRangeMap => (
    is => 'ro',
    isa => 'HashRef[Firewall::Utils::Set]',
    default => sub { {} },
);
=cut

my $service;

ok(
  do {
    eval {
      $service = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1525-1559',
        term     => 'z'
      );
    };
    warn $@ if $@;
    $service->isa('Firewall::Config::Element::Service::Srx');
  },
  ' 生成 Firewall::Config::Element::Service::Srx 对象'
);

ok(
  do {
    eval {
      $service = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1525-1559',
        term     => 'z'
      );
    };
    warn $@ if $@;
    $service->sign eq 'a';
  },
  ' lazy生成 sign'
);

ok(
  do {
    eval {
      $service = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1525-1559',
        term     => 'z'
      );
    };
    warn $@ if $@;
    $service->addMeta(
      fwId     => 1,
      srvName  => 'a',
      protocol => 'd',
      srcPort  => 'c',
      dstPort  => '1520-1523',
      term     => 'y'
    );
    $service->metas->{'a<|>z'}->sign eq 'a<|>z'
      and $service->dstPortRangeMap->{'d'}->min == 1520
      and $service->dstPortRangeMap->{'d'}->max == 1523;
  },
  " addMeta( fwId => 1, srvName => 'a', protocol => 'd', srcPort => 'c', dstPort => '1520-1523', term => 'y' )"
);

ok(
  do {
    eval {
      $service = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1525-1559',
        term     => 'z'
      );
    };
    warn $@ if $@;
    $service->addMeta(
      Firewall::Config::Element::ServiceMeta::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'd',
        srcPort  => 'c',
        dstPort  => '1520-1523',
        term     => 'y'
      )
    );
    $service->metas->{'a<|>z'}->sign eq 'a<|>z'
      and $service->dstPortRangeMap->{'d'}->min == 1520
      and $service->dstPortRangeMap->{'d'}->max == 1523;
  },
  " addMeta( Firewall::Config::Element::ServiceMeta::Srx )"
);

ok(
  do {
    eval {
      $service = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1525-1559',
        term     => 'z'
      );
      $service->addMeta(
        Firewall::Config::Element::ServiceMeta::Srx->new(
          fwId     => 1,
          srvName  => 'a',
          protocol => 'd',
          srcPort  => 'c',
          dstPort  => '1525-1559',
          term     => 'y'
        )
      );
      my $anotherService = Firewall::Config::Element::Service::Srx->new(
        fwId     => 1,
        srvName  => 'a',
        protocol => 'b',
        srcPort  => 'c',
        dstPort  => '1520-1523',
        term     => 'x'
      );
      $anotherService->addMeta(
        Firewall::Config::Element::ServiceMeta::Srx->new(
          fwId     => 1,
          srvName  => 'a',
          protocol => 'f',
          srcPort  => 'c',
          dstPort  => '1525-1559',
          term     => 'w'
        )
      );
      $service->addMeta($anotherService);
    };
          $service->metas->{'a<|>z'}->sign eq 'a<|>z'
      and $service->dstPortRangeMap->{'b'}->mins->[0] == 1520
      and $service->dstPortRangeMap->{'b'}->maxs->[0] == 1523
      and $service->dstPortRangeMap->{'b'}->mins->[1] == 1525
      and $service->dstPortRangeMap->{'b'}->maxs->[1] == 1559;
  },
  " addMeta( Firewall::Config::Element::Service::Srx )"
);
