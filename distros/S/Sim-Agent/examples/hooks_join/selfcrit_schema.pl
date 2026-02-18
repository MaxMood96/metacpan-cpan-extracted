use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $name = $agent->{name} // '';
    my $out  = $ctx->{current_output} // '';

    my @L = _norm($out);

    return { status => 'revise', critique => 'empty output' } unless @L;

    if ($name eq 'Worker2') {
        return _check_track_a(\@L);
    }
    if ($name eq 'Worker3') {
        return _check_track_b(\@L);
    }
    if ($name eq 'Worker4') {
        return _check_report(\@L);
    }

    return { status => 'ok' };
};

sub _norm {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\r\n/\n/g;
    $s =~ s/\r/\n/g;

    my @lines = split /\n/, $s, -1;
    for (@lines) { s/\s+$//; }

    shift @lines while @lines && $lines[0] eq '';

    if (@lines && $lines[0] =~ /\A(?:Worker\d+|Critic\d+|Chief\d+)\z/) {
        shift @lines;
        shift @lines while @lines && $lines[0] eq '';
    }

    if (@lines && $lines[0] =~ /\A```/) {
        shift @lines;
        shift @lines while @lines && $lines[0] eq '';
    }
    pop @lines if @lines && $lines[-1] =~ /\A```/;

    @lines = grep { $_ ne '' } @lines;
    return @lines;
}

sub _check_track_a {
    my ($L) = @_;

    return { status => 'revise', critique => 'TRACK_A must be 14 non-empty lines' } unless @$L == 14;
    return { status => 'revise', critique => 'line1 must be TRACK_A' }         unless $L->[0]  eq 'TRACK_A';
    return { status => 'revise', critique => 'line2 must be STATS:' }          unless $L->[1]  eq 'STATS:';
    for my $i (2..6) { return { status=>'revise', critique=>"bad STATS bullet" } unless $L->[$i] =~ /\A-\s+\S/; }
    return { status => 'revise', critique => 'line8 must be TRENDS:' }         unless $L->[7]  eq 'TRENDS:';
    for my $i (8..10){ return { status=>'revise', critique=>"bad TRENDS bullet" } unless $L->[$i] =~ /\A-\s+\S/; }
    return { status => 'revise', critique => 'line12 must be CAVEATS:' }       unless $L->[11] eq 'CAVEATS:';
    for my $i (12..13){return { status=>'revise', critique=>"bad CAVEATS bullet" } unless $L->[$i] =~ /\A-\s+\S/; }

    return { status => 'ok' };
}

sub _check_track_b {
    my ($L) = @_;

    return { status => 'revise', critique => 'TRACK_B must be 14 non-empty lines' } unless @$L == 14;
    return { status => 'revise', critique => 'line1 must be TRACK_B' }             unless $L->[0]  eq 'TRACK_B';
    return { status => 'revise', critique => 'line2 must be ANOMALIES:' }          unless $L->[1]  eq 'ANOMALIES:';
    for my $i (2..6) { return { status=>'revise', critique=>"bad ANOMALIES bullet" } unless $L->[$i] =~ /\A-\s+\S/; }
    return { status => 'revise', critique => 'line8 must be RISKS:' }              unless $L->[7]  eq 'RISKS:';
    for my $i (8..10){ return { status=>'revise', critique=>"bad RISKS bullet" } unless $L->[$i] =~ /\A-\s+\S/; }
    return { status => 'revise', critique => 'line12 must be CHECKS:' }            unless $L->[11] eq 'CHECKS:';
    for my $i (12..13){return { status=>'revise', critique=>"bad CHECKS bullet" } unless $L->[$i] =~ /\A-\s+\S/; }

    return { status => 'ok' };
}

sub _check_report {
    my ($L) = @_;

    return { status => 'revise', critique => 'report must start with REPORT' } unless $L->[0] eq 'REPORT';

    my @need = qw(SUMMARY: KEY_STATS: TOP_TRENDS: TOP_ANOMALIES: RISKS: NEXT_STEPS:);
    my %seen;
    for my $x (@$L) { $seen{$x}++ }
    for my $h (@need) {
        return { status => 'revise', critique => "missing $h" } unless $seen{$h};
    }

    # Don’t over-tighten content; revision hook will canonicalize.
    return { status => 'ok' };
}
