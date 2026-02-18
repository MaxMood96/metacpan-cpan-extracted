use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $file = $ENV{SIM_AGENT_INPUT} || 'examples/data/demo_metrics.csv';

    open my $fh, '<', $file or die "Worker1: cannot open input file '$file': $!";

    my @lines;
    while (my $line = <$fh>) {
        $line =~ s/\r\n/\n/g;
        push @lines, $line;
        last if @lines >= 9; # header + 8 rows
    }
    close $fh;

    die "Worker1: '$file' needs at least 9 lines (header + 8 rows)\n" unless @lines == 9;

    my $header = $lines[0];
    chomp $header;

    my @cols = map { s/^\s+//; s/\s+$//; $_ } split /,/, $header, -1;
    my $cols = join(", ", @cols);

    my @excerpt = @lines[1..8];
    chomp @excerpt;

    my $ex = "";
    for my $i (0..$#excerpt) {
        my $n = $i + 1;
        $ex .= sprintf("%d|%s\n", $n, $excerpt[$i]);
    }

    my $problem = "We have service latency_ms and error_rate over time by service and region; we need to spot spikes and data quality issues.";
    my $question = "Which service/region/time rows show the biggest latency_ms and error_rate anomalies in this sample, and what checks should we do next?";

    my $block = <<"BLOCK";
CONTEXT
FILE: $file
COLUMNS: $cols
PROBLEM_STATEMENT: $problem
TARGET_QUESTION: $question
EXCERPT:
$ex
BLOCK

    return <<"PROMPT";
You are Worker1. Output plain text only.

ABSOLUTE RULES:
- Output MUST be EXACTLY the 14-line block below.
- Copy it verbatim (no extra lines, no label line like "Worker1", no markdown, no backticks).

BEGIN_BLOCK
$block
END_BLOCK
PROMPT
}
