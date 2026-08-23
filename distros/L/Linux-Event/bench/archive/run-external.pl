#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use FindBin qw($Bin);
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json);

my $backend = 'anyevent';
my $outdir;
my $clients = '1,10,50,100';
my $messages = 1000;
my $bytes = 64;
my $events = 100_000;
GetOptions(
    'backend=s'  => \$backend,
    'out=s'      => \$outdir,
    'clients=s'  => \$clients,
    'messages=i' => \$messages,
    'bytes=i'    => \$bytes,
    'events=i'   => \$events,
) or die "bad options\n";
$outdir //= "$Bin/results/$backend";
make_path($outdir);

sub run_json ($name, @cmd) {
    say "== $name ==";
    my $txt = qx{@cmd};
    my $status = $? >> 8;
    print $txt;
    die "$name failed with exit $status\n" if $status != 0;
    my $data = decode_json($txt);
    open my $fh, '>', "$outdir/$name.json" or die $!;
    print {$fh} JSON::PP->new->canonical->pretty->encode($data);
}

for my $c (split /,/, $clients) {
    run_json("${backend}_echo_${c}", $^X, "$Bin/${backend}_echo_tcp.pl", '--clients', $c, '--messages', $messages, '--bytes', $bytes);
}
run_json("${backend}_dispatch_read_only", $^X, "$Bin/${backend}_dispatch_read_only.pl", '--events', $events);
run_json("${backend}_dispatch_oneshot", $^X, "$Bin/${backend}_dispatch_oneshot.pl", '--events', $events);
say "wrote $outdir";
