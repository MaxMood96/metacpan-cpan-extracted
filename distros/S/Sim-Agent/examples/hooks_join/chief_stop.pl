use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $pkt = $ctx->{input_packet} || {};
    my $out = defined $pkt->{output} ? $pkt->{output} : '';

    $out =~ s/\r\n/\n/g;

    # Allow explicit FAIL to be recorded, but still stop deterministically.
    if ($out =~ /\AFAIL:\s*(.+?)\s*\z/s) {
        my $why = $1; $why =~ s/\s+/ /g;
        return { status => 'stop', critique => "Final worker returned FAIL: $why" };
    }

    my @lines = split /\n/, $out, -1;
    for (@lines) { s/\s+$//; }
    @lines = grep { $_ ne '' } @lines;

    my @need = qw(
        REPORT
        SUMMARY:
        KEY_STATS:
        TOP_TRENDS:
        TOP_ANOMALIES:
        RISKS:
        NEXT_STEPS:
    );

    my %seen;
    for my $ln (@lines) {
        $seen{$ln} = 1 if grep { $_ eq $ln } @need;
    }

    for my $h (@need) {
        unless ($seen{$h}) {
            return { status => 'stop', critique => "REPORT schema fail: missing '$h'" };
        }
    }

    # Light bullet sanity: at least one bullet under each section header.
    my %bul;
    my $cur = '';
    for my $ln (@lines) {
        if ($ln =~ /\A(?:SUMMARY|KEY_STATS|TOP_TRENDS|TOP_ANOMALIES|RISKS|NEXT_STEPS):\z/) {
            $cur = $ln;
            $bul{$cur} ||= 0;
            next;
        }
        if ($cur && $ln =~ /\A-\s+\S/) {
            $bul{$cur}++;
        }
    }
    for my $sec (qw(SUMMARY: KEY_STATS: TOP_TRENDS: TOP_ANOMALIES: RISKS: NEXT_STEPS:)) {
        return { status => 'stop', critique => "REPORT schema fail: no bullets under '$sec'" }
            unless ($bul{$sec} || 0) >= 1;
    }

    return { status => 'stop' };
}
