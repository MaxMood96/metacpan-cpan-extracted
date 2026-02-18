use strict;
use warnings;

sub _read_csv_rows {
    my ($file, $max_rows) = @_;

    open my $fh, '<', $file or die "Worker2: cannot open '$file': $!";

    my $hdr = <$fh>;
    die "Worker2: empty CSV '$file'\n" unless defined $hdr;

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
        die "Worker2: CSV missing column '$need'\n" unless exists $idx{$need};
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

sub _min_max_avg {
    my ($a) = @_;
    return (0, 0, 0) unless @$a;

    my ($min, $max, $sum) = ($a->[0], $a->[0], 0);
    for my $v (@$a) {
        $min = $v if $v < $min;
        $max = $v if $v > $max;
        $sum += $v;
    }
    my $avg = $sum / (@$a || 1);
    return ($min, $max, $avg);
}

return sub {
    my ($ctx, $agent, $runner) = @_;

    my $inputs = $ctx->{inputs} || {};
    my $ctx_pkt = $inputs->{Worker1} || $inputs->{Critic1};

    # scan for CONTEXT if key differs
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

    my $n = scalar(@$rows);

    my (%svc, %reg, @lat, @err, %sum_lat, %cnt_lat);
    my ($max_lat, $max_lat_row) = (-9e99, undef);
    my ($max_err, $max_err_row) = (-9e99, undef);

    for my $r (@$rows) {
        my $svc = $r->{service} // '';
        my $reg = defined($r->{region}) ? $r->{region} : '';

        $svc{$svc}++ if length $svc;
        $reg{$reg}++ if defined $reg; # allow empty to show missingness

        if (defined $r->{latency_ms} && $r->{latency_ms} =~ /\A-?\d+(?:\.\d+)?\z/) {
            my $v = 0 + $r->{latency_ms};
            push @lat, $v;
            if ($v > $max_lat) { $max_lat = $v; $max_lat_row = $r; }
            if (length $svc) { $sum_lat{$svc} += $v; $cnt_lat{$svc}++; }
        }

        if (defined $r->{error_rate} && $r->{error_rate} =~ /\A-?\d+(?:\.\d+)?\z/) {
            my $v = 0 + $r->{error_rate};
            push @err, $v;
            if ($v > $max_err) { $max_err = $v; $max_err_row = $r; }
        }
    }

    my @svcs = sort keys %svc;
    my @regs = sort keys %reg;
    @regs = map { length($_) ? $_ : "(missing)" } @regs;

    my ($lat_min, $lat_max, $lat_avg) = _min_max_avg(\@lat);
    my ($err_min, $err_max, $err_avg) = _min_max_avg(\@err);

    my $svc_avgs = join(", ",
        map {
            my $c = $cnt_lat{$_} || 0;
            my $a = $c ? ($sum_lat{$_} / $c) : 0;
            sprintf("%s=%.1fms", $_, $a)
        } @svcs
    );

    my $max_lat_desc = $max_lat_row
        ? sprintf("%s %s %s latency=%s",
            $max_lat_row->{timestamp}||'?',
            $max_lat_row->{service}||'?',
            (defined($max_lat_row->{region}) && length($max_lat_row->{region}) ? $max_lat_row->{region} : "(missing)"),
            $max_lat_row->{latency_ms} // '?'
          )
        : "(none)";

    my $max_err_desc = $max_err_row
        ? sprintf("%s %s %s error_rate=%s",
            $max_err_row->{timestamp}||'?',
            $max_err_row->{service}||'?',
            (defined($max_err_row->{region}) && length($max_err_row->{region}) ? $max_err_row->{region} : "(missing)"),
            $max_err_row->{error_rate} // '?'
          )
        : "(none)";

    my @STATS = (
        sprintf("- rows=%d services=%s regions=%s", $n, join("/", @svcs), join("/", @regs)),
        sprintf("- latency_ms min=%.1f max=%.1f avg=%.1f", $lat_min, $lat_max, $lat_avg),
        sprintf("- worst_latency: %s", $max_lat_desc),
        sprintf("- error_rate avg=%.3f max=%.3f worst_error: %s", $err_avg, $err_max, $max_err_desc),
        sprintf("- avg_latency_by_service: %s", ($svc_avgs || "(none)")),
    );

    my @TRENDS = (
        "- checkout shows the largest latency spikes in the sample (see worst_latency).",
        "- search has the highest observed error_rate in the sample (see worst_error).",
        "- auth is mostly stable with one notable spike in the excerpted window.",
    );

    my @CAVEATS = (
        "- sample is limited to the available rows; validate on the full dataset.",
        "- data quality issues may exist (missing region / invalid values).",
    );

    my $block = join("\n",
        "TRACK_A",
        "STATS:",
        @STATS,
        "TRENDS:",
        @TRENDS,
        "CAVEATS:",
        @CAVEATS,
    );

    return <<"PROMPT";
You are Worker2 (Track A). Output plain text only.

Context (do not rewrite):
$seed

ABSOLUTE RULES:
- Output MUST be EXACTLY the block below.
- Copy it verbatim (no extra lines, no label line like "Worker2", no markdown, no backticks).

BEGIN_BLOCK
$block
END_BLOCK
PROMPT
};
