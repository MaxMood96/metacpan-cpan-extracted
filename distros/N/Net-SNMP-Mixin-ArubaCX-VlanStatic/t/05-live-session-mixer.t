#!perl

use strict;
use warnings;
use Test::More;
use Module::Build;

eval "use Net::SNMP";
plan skip_all => "Net::SNMP required for testing Net::SNMP::Mixin module"
  if $@;

eval "use Net::SNMP::Mixin";
plan skip_all =>
  "Net::SNMP::Mixin required for testing Net::SNMP::Mixin module"
  if $@;

plan tests => 39;
#plan 'no_plan';

my $builder        = Module::Build->current;
my $snmp_agent     = $builder->notes('snmp_agent');
my $snmp_community = $builder->notes('snmp_community');
my $snmp_version   = $builder->notes('snmp_version');

SKIP: {
  skip '-> no live tests', 39, unless $snmp_agent;

  my ( $session, $error ) = Net::SNMP->session(
    hostname  => $snmp_agent,
    community => $snmp_community || 'public',
    version   => $snmp_version || '2c',
  );

  ok( !$error, 'got snmp session for live tests' );
  isa_ok( $session, 'Net::SNMP' );

  isa_ok( $session->mixer('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'Net::SNMP' );
  ok(
    $session->can('map_vlan_id2name'),
    'can $session->map_vlan_id2name'
  );
  ok(
    $session->can('map_vlan_id2if_idx'),
    'can $session->map_vlan_id2if_idx'
  );
  ok( $session->can('map_if_idx2vlan_id'),
    'can $session->map_if_idx2vlan_id' );


  eval { $session->init_mixins };
  ok( !$@, 'init_mixins without error' );
  ok( $session->init_ok('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'initialization successful completetd' );

  eval { $session->init_mixins(1) };
  ok( !$@, 'already initialized but reload forced' );
  ok( $session->init_ok('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'initialization successful completetd' );

  eval { $session->init_mixins };
  like(
    $@,
    qr/already initialized and reload not forced/i,
    'already initialized and reload not forced'
  );

  eval { Net::SNMP->init_mixins };
  like(
    $@,
    qr/pure instance method called as class method/i,
    'pure instance method called as class method'
  );

  my ($ids2names, $ids2ports, $ports2ids);

  eval { $ids2names = $session->map_vlan_id2name };
  ok( !$@, 'map_vlan_id2name' );

  eval { $ids2ports = $session->map_vlan_id2if_idx };
  ok( !$@, 'map_vlan_id2if_idx' );

  eval { $ports2ids = $session->map_if_idx2vlan_id };
  ok( !$@, 'map_if_idx2vlan_id' );

  undef $session;

  # nonblocking tests
  ( $session, $error ) = Net::SNMP->session(
    hostname    => $snmp_agent,
    community   => $snmp_community || 'public',
    version   => $snmp_version || '2c',
    nonblocking => 1,
  );

  ok( !$error, 'got snmp session for live tests' );
  isa_ok( $session, 'Net::SNMP' );

  isa_ok( $session->mixer('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'Net::SNMP' );

  eval { $session->init_mixins };
  ok( !$@, 'init_mixins without error' );
  snmp_dispatcher();
  ok( $session->init_ok('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'initialization successful completetd' );

  eval { $session->init_mixins(1) };
  ok( !$@, 'already initialized but reload forced' );
  snmp_dispatcher();
  ok( $session->init_ok('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'initialization successful completetd' );

  eval { $ids2names = $session->map_vlan_id2name };
  ok( !$@, 'map_vlan_id2name' );

  eval { $ids2ports = $session->map_vlan_id2if_idx };
  ok( !$@, 'map_vlan_id2if_idx' );

  eval { $ports2ids = $session->map_if_idx2vlan_id };
  ok( !$@, 'map_if_idx2vlan_id' );

  undef $session;

  # tests with wrong community
  ( $session, $error ) = Net::SNMP->session(
    hostname  => $snmp_agent,
    community => '_foo_bar_bazz_yazz_%_',
    version   => $snmp_version || '2c',
    timeout   => 1,
    retries   => 0,
  );

  ok( !$error, 'got snmp session for live tests' );
  isa_ok( $session, 'Net::SNMP' );

  isa_ok( $session->mixer('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'Net::SNMP' );

  eval { $session->init_mixins };
  like(
    $session->errors,
    qr/No response from remote host/i,
    'No response from remote host'
  );

  eval { $ids2names = $session->map_vlan_id2name };
  like( $@, qr/not initialized/, 'not initialized' );

  eval { $ids2ports = $session->map_vlan_id2if_idx };
  like( $@, qr/not initialized/, 'not initialized' );

  eval { $ports2ids = $session->map_if_idx2vlan_id };
  like( $@, qr/not initialized/, 'not initialized' );

  undef $session;

  # nonblocking tests with wrong community
  ( $session, $error ) = Net::SNMP->session(
    hostname    => $snmp_agent,
    community   => '_foo_bar_bazz_yazz_%_',
    version   => $snmp_version || '2c',
    timeout     => 1,
    retries     => 0,
    nonblocking => 1,
  );

  ok( !$error, 'got snmp session for live tests' );
  isa_ok( $session, 'Net::SNMP' );

  isa_ok( $session->mixer('Net::SNMP::Mixin::ArubaCX::VlanStatic'), 'Net::SNMP' );

  eval { $session->init_mixins };
  snmp_dispatcher();
  like(
    $session->errors,
    qr/No response from remote host/i,
    'No response from remote host'
  );

  eval { $ids2names = $session->map_vlan_id2name };
  like( $@, qr/not initialized/, 'not initialized' );

  eval { $ids2ports = $session->map_vlan_id2if_idx };
  like( $@, qr/not initialized/, 'not initialized' );

  eval { $ports2ids = $session->map_if_idx2vlan_id };
  like( $@, qr/not initialized/, 'not initialized' );

}

# vim: ft=perl sw=2
