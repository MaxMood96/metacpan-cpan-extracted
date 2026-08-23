#!/usr/bin/env perl
use v5.36; use strict; use warnings;
use AnyEvent; use IO::Handle; use Time::HiRes qw(time); use Getopt::Long qw(GetOptions);
my $events=100_000; GetOptions('events=i'=>\$events) or die "bad options\n";
pipe(my $r,my $w) or die $!; $r->blocking(0); $w->blocking(0);
my $cv=AnyEvent->condvar; my $count=0; my $watch;
my $arm; $arm=sub { $watch=AnyEvent->io(fh=>$r,poll=>'r',cb=>sub{ undef $watch; my $n=sysread($r,my $buf,1); return unless defined $n && $n>0; $count += $n; if ($count >= $events) { $cv->send; return; } syswrite($w,'x') // die $!; $arm->(); }); };
$arm->(); syswrite($w,'x') // die $!; my $start=time; $cv->recv; my $elapsed=time-$start; my $rate=$count/$elapsed;
printf qq({"bench":"anyevent_dispatch_oneshot_rearm","backend":"AnyEvent","events":%d,"elapsed":%.9f,"rate":%.2f,"callback_calls":%d}\n),$count,$elapsed,$rate,$count;
