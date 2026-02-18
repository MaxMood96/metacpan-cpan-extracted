use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $name = $agent->{name} // '';
    my $out  = $ctx->{current_output} // '';

    my @L = _norm($out);

    return _fix_track_a(\@L) if $name eq 'Worker2';
    return _fix_track_b(\@L) if $name eq 'Worker3';
    return _fix_report(\@L)  if $name eq 'Worker4';

    return $out;
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

sub _bullets_under {
    my ($L, $hdr) = @_;
    my @b;

    for my $i (0 .. $#$L) {
        next unless $L->[$i] eq $hdr;
        for my $j ($i+1 .. $#$L) {
            last if $L->[$j] =~ /\A[A-Z_]+:\z/;
            my $x = $L->[$j];
            $x =~ s/^\s+//;
            next unless length $x;
            if ($x =~ /\A-\s+\S/) { push @b, $x; next; }
            if ($x =~ /\A-\S/)    { $x =~ s/\A-/- /; push @b, $x; next; }
        }
        last;
    }

    return @b;
}

sub _pad_trunc {
    my ($arr, $n) = @_;
    my @a = @$arr;
    @a = @a[0..$n-1] if @a > $n;
    while (@a < $n) { push @a, "- (missing)"; }
    return @a;
}

sub _fix_track_a {
    my ($L) = @_;

    my @stats   = _bullets_under($L, 'STATS:');
    my @trends  = _bullets_under($L, 'TRENDS:');
    my @caveats = _bullets_under($L, 'CAVEATS:');

    if (!@stats && !@trends && !@caveats) {
        my @all = grep { /\A-/ } @$L;
        @stats = @all if @all;
    }

    @stats   = _pad_trunc(\@stats, 5);
    @trends  = _pad_trunc(\@trends, 3);
    @caveats = _pad_trunc(\@caveats, 2);

    return join("\n",
        "TRACK_A",
        "STATS:",
        @stats,
        "TRENDS:",
        @trends,
        "CAVEATS:",
        @caveats,
        ""
    );
}

sub _fix_track_b {
    my ($L) = @_;

    my @anom   = _bullets_under($L, 'ANOMALIES:');
    my @risks  = _bullets_under($L, 'RISKS:');
    my @checks = _bullets_under($L, 'CHECKS:');

    if (!@anom) {
        my @all = grep { /\A-/ } @$L;
        @anom = @all if @all;
    }

    @anom   = _pad_trunc(\@anom, 5);
    @risks  = _pad_trunc(\@risks, 3);
    @checks = _pad_trunc(\@checks, 2);

    return join("\n",
        "TRACK_B",
        "ANOMALIES:",
        @anom,
        "RISKS:",
        @risks,
        "CHECKS:",
        @checks,
        ""
    );
}

sub _fix_report {
    my ($L) = @_;

    my %want = (
        'SUMMARY:'       => 2,
        'KEY_STATS:'     => 3,
        'TOP_TRENDS:'    => 3,
        'TOP_ANOMALIES:' => 3,
        'RISKS:'         => 3,
        'NEXT_STEPS:'    => 4,
    );

    my @sec = qw(SUMMARY: KEY_STATS: TOP_TRENDS: TOP_ANOMALIES: RISKS: NEXT_STEPS:);

    my %b;
    for my $h (@sec) {
        my @x = _bullets_under($L, $h);
        @x = _pad_trunc(\@x, $want{$h});
        $b{$h} = \@x;
    }

    return join("\n",
        "REPORT",
        "SUMMARY:",       @{ $b{'SUMMARY:'} },
        "KEY_STATS:",     @{ $b{'KEY_STATS:'} },
        "TOP_TRENDS:",    @{ $b{'TOP_TRENDS:'} },
        "TOP_ANOMALIES:", @{ $b{'TOP_ANOMALIES:'} },
        "RISKS:",         @{ $b{'RISKS:'} },
        "NEXT_STEPS:",    @{ $b{'NEXT_STEPS:'} },
        ""
    );
}
