#!/usr/bin/env perl
use v5.36; use strict; use warnings;
use EV; use IO::Handle; use Time::HiRes qw(time); use Getopt::Long qw(GetOptions);
my $events=100_000; GetOptions('events=i'=>\$events) or die "bad options\n";
pipe(my $r,my $w) or die $!; $r->blocking(0); $w->blocking(0);
my $count=0; my $watch; my $arm;
$arm=sub { $watch=EV::io($r,EV::READ,sub{ undef $watch; my $n=sysread($r,my $buf,1); return unless defined $n && $n>0; $count += $n; if ($count >= $events) { EV::break(EV::BREAK_ALL); return; } syswrite($w,'x') // die $!; $arm->(); }); };
$arm->(); syswrite($w,'x') // die $!; my $start=time; EV::run; my $elapsed=time-$start; my $rate=$count/$elapsed;
printf qq({"bench":"ev_dispatch_oneshot_rearm","backend":"EV","events":%d,"elapsed":%.9f,"rate":%.2f,"callback_calls":%d}\n),$count,$elapsed,$rate,$count;
