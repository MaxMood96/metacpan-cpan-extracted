#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use JSON::PP;
use Time::Moment;
use lib 'lib';
use Cron::Toolkit;

my $json  = do { local $/; open my $fh, '<', 't/data/cron_tests.json' or die $!; <$fh> };
my $tests = decode_json($json);

my $valid = grep { !$_->{invalid} } @$tests;

for my $t (@$tests) {
   next if $t->{invalid};

   my $c = eval {
      my $obj = Cron::Toolkit->new( expression => $t->{expr} );
      $obj->time_zone( $t->{tz} )          if $t->{tz};
      $obj->utc_offset( $t->{utc_offset} ) if exists $t->{utc_offset} && defined $t->{utc_offset};
      $obj;
   };

   ok($c, "tree") or diag "Error: $@";
   diag $c->dump_tree;

   SKIP: {
      my $string = $c->as_string;
      my $quartz_string = $c->as_quartz_string;
      my $describe = $c->describe;
      my $base = $t->{base_epoch};
      my $next = $c->next($base);
      my $prev = $c->previous($base);
      my $utc_offset = $c->utc_offset;

      diag "string: $string";
      diag "quartz string: $quartz_string";
      diag "describe: $describe";
      diag "base: $t->{base_epoch}";
      diag "utc_offset: $utc_offset";
      diag "next: $next" if $next;
      diag "prev: $prev" if $prev;

      is( $string, $t->{as_string}, "as_string");
      is( $quartz_string, $t->{as_quartz_string}, "as_quartz_string");
      is( $describe, $t->{desc}, "describe");
      is( $next, $t->{next_epoch}, "next" );
      is( $prev, $t->{prev_epoch}, "previous" );
      diag "\n";
   }
}

# Named last-weekday aliases (MONL → 1L) and regressions
{
   my $monl  = Cron::Toolkit->new( expression => '0 0 12 ? * MONL *' );
   my $one_l = Cron::Toolkit->new( expression => '0 0 12 ? * 1L *' );
   is( $monl->as_string,  '0 0 12 ? * 1L *', 'MONL stores as 1L' );
   is( $monl->as_string,  $one_l->as_string, 'MONL matches numeric 1L' );

   my $sunl    = Cron::Toolkit->new( expression => '0 0 12 ? * SUNL *' );
   my $seven_l = Cron::Toolkit->new( expression => '0 0 12 ? * 7L *' );
   is( $sunl->as_string, '0 0 12 ? * 7L *', 'SUNL stores as 7L' );
   is( $sunl->as_string, $seven_l->as_string, 'SUNL matches numeric 7L' );

   my $thul   = Cron::Toolkit->new( expression => '0 0 12 ? * THUL *' );
   my $four_l = Cron::Toolkit->new( expression => '0 0 12 ? * 4L *' );
   is( $thul->as_string, '0 0 12 ? * 4L *', 'THUL stores as 4L' );
   is( $thul->as_string, $four_l->as_string, 'THUL matches numeric 4L' );

   my $nth = Cron::Toolkit->new( expression => '0 0 12 ? * MON#3 *' );
   is( $nth->as_string, '0 0 12 ? * 1#3 *', 'MON#3 still stores as 1#3' );

   my $range = Cron::Toolkit->new( expression => '0 0 9 ? * MON-FRI *' );
   is( $range->as_string, '0 0 9 ? * 1-5 *', 'MON-FRI still works' );

   my $base = 1761177600;
   ok( $monl->is_match( $one_l->next($base) ),   'MONL is_match agrees with 1L' );
   ok( $sunl->is_match( $seven_l->next($base) ), 'SUNL is_match agrees with 7L' );
   ok( $thul->is_match( $four_l->next($base) ),  'THUL is_match agrees with 4L' );
   ok( $one_l->is_match($base) == $monl->is_match($base), '1L still works' );

   eval { Cron::Toolkit->new( expression => '0 0 12 ? * MONX *' ) };
   ok( $@, 'MONX still dies' );
   like( $@, qr/Invalid characters/, 'MONX dies with Invalid characters' );
}

done_testing;
