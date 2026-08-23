#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use FindBin qw($Bin);
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use JSON::PP qw(decode_json encode_json);
use Time::HiRes qw(time);

my $outdir = "$Bin/results/phase18f";
my $clients = '1,10,50,100';
my $messages = 1000;
my $bytes = 64;
my $events = 100_000;
my $build = 0;
GetOptions(
    'out=s'      => \$outdir,
    'clients=s'  => \$clients,
    'messages=i' => \$messages,
    'bytes=i'    => \$bytes,
    'events=i'   => \$events,
    'build!'     => \$build,
) or die "bad options\n";

my $root = "$Bin/..";
if ($build) {
    system($^X, 'Makefile.PL') == 0 or die "Makefile.PL failed\n";
    system('make') == 0 or die "make failed\n";
    system('make', 'test') == 0 or die "make test failed\n";
}

make_path($outdir);
$ENV{PERL5LIB} = join(':', "$root/blib/lib", "$root/blib/arch", ($ENV{PERL5LIB}//()));

sub run_json ($name, @cmd) {
    say "== $name ==";
    my $txt = qx{@cmd};
    my $status = $? >> 8;
    print $txt;
    die "$name failed with exit $status\n" if $status != 0;
    my $data = decode_json($txt);
    open my $fh, '>', "$outdir/$name.json" or die $!;
    print {$fh} JSON::PP->new->canonical->pretty->encode($data);
    return $data;
}

my @results;
for my $c (split /,/, $clients) {
    push @results, run_json("phase18_echo_${c}", $^X, "$Bin/phase18_echo_tcp.pl", '--clients', $c, '--messages', $messages, '--bytes', $bytes);
}
run_json('phase18_dispatch_read_only', $^X, "$Bin/phase18_dispatch_read_only.pl", '--events', $events);
run_json('phase18_dispatch_read_write', $^X, "$Bin/phase18_dispatch_read_write.pl", '--messages', $events);
run_json('phase18_dispatch_oneshot', $^X, "$Bin/phase18_dispatch_oneshot.pl", '--events', $events);

my $summary = {
    phase => 'phase18f',
    generated_at => scalar localtime,
    clients => [split /,/, $clients],
    messages_per_client => $messages,
    bytes => $bytes,
    events => $events,
    result_files => [sort glob "$outdir/*.json"],
};
open my $sfh, '>', "$outdir/summary.json" or die $!;
print {$sfh} JSON::PP->new->canonical->pretty->encode($summary);
say "wrote $outdir";
