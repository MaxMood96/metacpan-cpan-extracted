#!/usr/bin/env perl
use v5.36; use strict; use warnings;
use AnyEvent; use IO::Handle; use Time::HiRes qw(time); use Getopt::Long qw(GetOptions);
my $events=100_000; my $prefill=4096; GetOptions('events=i'=>\$events,'prefill=i'=>\$prefill) or die "bad options\n";
$prefill=1 if $prefill<1; $prefill=$events if $prefill>$events;
pipe(my $r,my $w) or die $!; $r->blocking(0); $w->blocking(0);
my $seed='x'x$prefill; my $off=0; while ($off<length($seed)) { my $n=syswrite($w,$seed,length($seed)-$off,$off); die $! unless defined $n; $off+=$n; }
my ($read,$written)=(0,$prefill); my $cv=AnyEvent->condvar; my $watch;
$watch=AnyEvent->io(fh=>$r,poll=>'r',cb=>sub{ my $n=sysread($r,my $buf,1); return unless defined $n && $n>0; $read+=$n; if ($read >= $events) { undef $watch; $cv->send; return; } if ($written < $events) { my $m=syswrite($w,'x'); die $! unless defined $m; $written+=$m; }});
my $start=time; $cv->recv; my $elapsed=time-$start; my $rate=$read/$elapsed;
printf qq({"bench":"anyevent_dispatch_read_only","backend":"AnyEvent","events":%d,"elapsed":%.9f,"rate":%.2f,"callback_calls":%d}\n),$read,$elapsed,$rate,$read;
