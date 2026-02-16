use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $file = $ENV{SIM_AGENT_INPUT} || 'examples/data/demo_metrics.csv';

    open my $fh, '<', $file or die "Worker1 cannot open input file '$file': $!";

    my @lines;
    while (my $line = <$fh>) {
        $line =~ s/\r\n/\n/g;
        push @lines, $line;
        last if @lines >= 9; # header + 8 rows
    }
    close $fh;

    die "Worker1 input file '$file' looks empty" unless @lines;

    my $header = $lines[0];
    chomp $header;
    my @cols = map { s/^\s+//; s/\s+$//; $_ } split /,/, $header, -1;
    my $cols = join(", ", @cols);

    my @excerpt = @lines[1 .. $#lines];
    chomp @excerpt;

    my $ex = "";
    for my $i (0 .. $#excerpt) {
        my $n = $i + 1;
        $ex .= sprintf("%d|%s\n", $n, $excerpt[$i]);
    }

    return <<"PROMPT";
You are Worker1. You will see a CSV header and 8 example rows from a local file.

Task: produce a tiny, strict CONTEXT block to seed downstream workers.

Rules:
- No preamble. No code fences.
- Exactly the schema below.
- PROBLEM_STATEMENT must be 1 sentence.
- TARGET_QUESTION must be 1 sentence, practical and answerable from this file.
- Keep the whole output <= 16 lines.
- EXCERPT lines must be copied EXACTLY from the provided EXCERPT (including punctuation/spaces after the pipe).

CSV_FILE: $file
COLUMNS: $cols

EXCERPT_TO_COPY:
$ex
OUTPUT_SCHEMA (copy headers exactly):

CONTEXT
FILE: <CSV_FILE>
COLUMNS: <COLUMNS>
PROBLEM_STATEMENT: <one sentence>
TARGET_QUESTION: <one sentence>
EXCERPT:
1|...
2|...
3|...
4|...
5|...
6|...
7|...
8|...
PROMPT
}
