use strict;
use warnings;

sub _extract_bullets {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\r\n/\n/g;
    my @lines = split /\n/, $s, -1;
    @lines = grep { defined($_) && length($_) } @lines;
    my @b = grep { /\A-\s+\S/ } @lines;
    return @b;
}

sub _pad_trunc {
    my ($arr, $n) = @_;
    my @a = @$arr;
    @a = @a[0..$n-1] if @a > $n;
    while (@a < $n) { push @a, "- (missing)"; }
    return @a;
}

return sub {
    my ($ctx, $agent, $runner) = @_;

    my $inputs = $ctx->{inputs} || {};
    die "Worker4: no inputs received\n" unless %$inputs;

    my $scan_first = sub {
        my ($re) = @_;
        for my $k (sort keys %$inputs) {
            my $pkt = $inputs->{$k};
            next unless $pkt && ref($pkt) eq 'HASH';
            my $out = $pkt->{output};
            next unless defined $out;
            $out =~ s/\r\n/\n/g;
            return $pkt if $out =~ $re;
        }
        return undef;
    };

    my $pkt_a = $inputs->{Worker2} || $inputs->{Critic2} || $scan_first->(qr/\ATRACK_A\b/);
    my $pkt_b = $inputs->{Worker3} || $inputs->{Critic3} || $scan_first->(qr/\ATRACK_B\b/);

    die "Worker4: missing TRACK_A input. Have keys: " . join(", ", sort keys %$inputs) . "\n"
        unless $pkt_a && defined $pkt_a->{output};

    die "Worker4: missing TRACK_B input. Have keys: " . join(", ", sort keys %$inputs) . "\n"
        unless $pkt_b && defined $pkt_b->{output};

    my @a = _extract_bullets($pkt_a->{output});
    my @b = _extract_bullets($pkt_b->{output});

    my @summary = (
        "- Latency/error_rate anomalies exist in the sample; see KEY_STATS and TOP_ANOMALIES.",
        "- Data quality issues (missing region / invalid latency) require verification.",
    );

    my @key_stats  = _pad_trunc([ grep { /rows=|latency_ms|min=|max=|avg=|worst_/i } @a ], 3);
    my @top_trends = _pad_trunc([ grep { /checkout|search|auth|spike|highest|trend/i } @a ], 3);

    my @anoms      = _pad_trunc([ grep { /missing|negative|high latency|high error_rate/i } @b ], 3);
    my @risks      = _pad_trunc([ grep { /data quality|incident|sample|average|mislead/i } @b ], 3);

    my @next_steps = (
        "- Validate outliers (negative latency, missing region) in ingestion/ETL logs.",
        "- Investigate worst_latency and worst_error rows for service health/incidents.",
        "- Add alert thresholds for latency_ms>=500 and error_rate>=0.10.",
        "- Re-run on full dataset/time window and compare per-service baselines.",
    );

    my $block = join("\n",
        "REPORT",
        "SUMMARY:",
        @summary,
        "KEY_STATS:",
        @key_stats,
        "TOP_TRENDS:",
        @top_trends,
        "TOP_ANOMALIES:",
        @anoms,
        "RISKS:",
        @risks,
        "NEXT_STEPS:",
        @next_steps,
    );

    return <<"PROMPT";
You are Worker4. Output plain text only.

ABSOLUTE RULES:
- Output MUST be EXACTLY the block below.
- Copy it verbatim (no extra lines, no label line like "Worker4", no markdown, no backticks).

BEGIN_BLOCK
$block
END_BLOCK
PROMPT
};
