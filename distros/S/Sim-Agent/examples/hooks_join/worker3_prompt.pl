use strict;
use warnings;

sub _read_csv_rows {
    my ($file, $max_rows) = @_;

    open my $fh, '<', $file or die "Worker3: cannot open '$file': $!";

    my $hdr = <$fh>;
    die "Worker3: empty CSV '$file'\n" unless defined $hdr;

    $hdr =~ s/\r\n/\n/g;
    chomp $hdr;

    my @cols = split /,/, $hdr, -1;
    my %idx;

    for my $i (0..$#cols) {
        (my $c = $cols[$i]) =~ s/^\s+//;
        $c =~ s/\s+$//;
        $idx{$c} = $i;
    }

    for my $need (qw(timestamp service region latency_ms error_rate)) {
        die "Worker3: CSV missing column '$need'\n" unless exists $idx{$need};
    }

    my @rows;
    while (my $line = <$fh>) {
        $line =~ s/\r\n/\n/g;
        chomp $line;
        next unless length $line;

        my @f = split /,/, $line, -1;

        my %r;
        @r{qw(timestamp service region latency_ms error_rate)} =
            @f[@idx{qw(timestamp service region latency_ms error_rate)}];

        push @rows, \%r;
        last if @rows >= $max_rows;
    }

    close $fh;
    return \@rows;
}

sub _pad_trunc {
    my ($arr, $n) = @_;
    my @a = @$arr;

    @a = @a[0..$n-1] if @a > $n;
    while (@a < $n) { push @a, "- (missing anomaly)"; }

    # ensure "- " prefix
    @a = map { my $x = $_; $x =~ s/\A-\s*/- /; $x } @a;
    return @a;
}

return sub {
    my ($ctx, $agent, $runner) = @_;

    my $inputs  = $ctx->{inputs} || {};
    my $ctx_pkt = $inputs->{Worker1} || $inputs->{Critic1};

    if (!$ctx_pkt || !defined $ctx_pkt->{output} || $ctx_pkt->{output} !~ /\ACONTEXT\b/) {
        for my $k (sort keys %$inputs) {
            my $p = $inputs->{$k};
            next unless $p && ref($p) eq 'HASH';
            next unless defined $p->{output};
            if ($p->{output} =~ /\ACONTEXT\b/) { $ctx_pkt = $p; last; }
        }
    }

    my $seed = ($ctx_pkt && defined $ctx_pkt->{output})
        ? $ctx_pkt->{output}
        : "CONTEXT\nFILE: (missing)\nCOLUMNS: (missing)\nPROBLEM_STATEMENT: (missing)\nTARGET_QUESTION: (missing)\nEXCERPT:\n";

    my $file = $ENV{SIM_AGENT_INPUT} || 'examples/data/demo_metrics.csv';
    my $rows = _read_csv_rows($file, 200);

    my @anom;

    for my $r (@$rows) {
        my $ts  = $r->{timestamp} // '?';
        my $svc = $r->{service}   // '?';
        my $reg = (defined($r->{region}) && length($r->{region})) ? $r->{region} : "(missing)";

        if (defined $r->{latency_ms} && $r->{latency_ms} =~ /\A-?\d+(?:\.\d+)?\z/) {
            my $lat = 0 + $r->{latency_ms};
            push @anom, sprintf("- %s %s %s negative latency_ms=%s", $ts, $svc, $reg, $r->{latency_ms}) if $lat < 0;
            push @anom, sprintf("- %s %s %s high latency_ms=%s",     $ts, $svc, $reg, $r->{latency_ms}) if $lat >= 500;
        }

        if (!defined($r->{region}) || $r->{region} eq '') {
            push @anom, sprintf("- %s %s missing region", $ts, $svc);
        }

        if (defined $r->{error_rate} && $r->{error_rate} =~ /\A-?\d+(?:\.\d+)?\z/) {
            my $er = 0 + $r->{error_rate};
            push @anom, sprintf("- %s %s %s high error_rate=%s", $ts, $svc, $reg, $r->{error_rate}) if $er >= 0.10;
        }
    }

    # de-dup while keeping order
    my %seen;
    @anom = grep { !$seen{$_}++ } @anom;

    @anom = _pad_trunc(\@anom, 5);

    my @risks = (
        "- data quality issues (missing region / invalid latency) can mislead conclusions.",
        "- spikes may indicate a real incident; relying on averages can hide them.",
        "- small sample window; need full-range verification before acting broadly.",
    );

    my @checks = (
        "- validate outliers (negative latency, missing region) at ingestion/ETL stage.",
        "- re-run the same checks on the full CSV (not just the excerpt) and compare.",
    );

    my $block = join("\n",
        "TRACK_B",
        "ANOMALIES:",
        @anom,
        "RISKS:",
        @risks,
        "CHECKS:",
        @checks,
    );

    return <<"PROMPT";
You are Worker3 (Track B). Output plain text only.

Context (do not rewrite):
$seed

ABSOLUTE RULES:
- Output MUST be EXACTLY the block below.
- Copy it verbatim (no extra lines, no label line like "Worker3", no markdown, no backticks).

BEGIN_BLOCK
$block
END_BLOCK
PROMPT
};
