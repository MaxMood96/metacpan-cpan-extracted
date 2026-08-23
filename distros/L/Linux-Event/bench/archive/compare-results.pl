#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use Getopt::Long qw(GetOptions);

my ($a,$b);
GetOptions('a=s'=>\$a,'b=s'=>\$b) or die "usage: $0 --a DIR --b DIR\n";
die "usage: $0 --a DIR --b DIR\n" unless $a && $b;

sub load_dir ($dir) {
    my %r;
    for my $file (glob "$dir/*.json") {
        next if $file =~ /summary\.json$/;
        open my $fh, '<', $file or die $!;
        my $j = decode_json(do { local $/; <$fh> });
        my $key;
        if (($j->{bench}//'') =~ /echo_tcp/) { $key = 'echo_' . $j->{clients}; }
        elsif (($j->{bench}//'') =~ /read_only/) { $key = 'dispatch_read_only'; }
        elsif (($j->{bench}//'') =~ /oneshot/) { $key = 'dispatch_oneshot'; }
        elsif (($j->{bench}//'') =~ /read_write/) { $key = 'dispatch_read_write'; }
        else { next; }
        $r{$key} = $j;
    }
    return \%r;
}

my $ra = load_dir($a); my $rb = load_dir($b);
printf "% -24s %14s %14s %10s\n", 'bench', 'A rate', 'B rate', 'B vs A';
printf "%s\n", '-' x 68;
for my $key (sort keys %{{%$ra,%$rb}}) {
    next unless $ra->{$key} && $rb->{$key};
    my $ar = $ra->{$key}{rate} // $ra->{$key}{messages_per_second} // $ra->{$key}{callbacks_per_second} // next;
    my $br = $rb->{$key}{rate} // $rb->{$key}{messages_per_second} // $rb->{$key}{callbacks_per_second} // next;
    my $pct = (($br/$ar)-1)*100;
    printf "%-24s %14.2f %14.2f %+9.1f%%\n", $key, $ar, $br, $pct;
}
