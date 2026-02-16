use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $file = $ENV{SIM_AGENT_INPUT} || 'examples/data/demo_metrics.csv';

    my $seed = $ctx->{inputs}{Worker1}{output}
        or die "Worker3 missing input key Worker1";

    open my $fh, '<', $file or die "Worker3 cannot open input file '$file': $!";

    my $max_lines = 30;
    my @lines;
    while (my $line = <$fh>) {
        $line =~ s/\r\n/\n/g;
        push @lines, $line;
        last if @lines >= $max_lines;
    }
    close $fh;

    die "Worker3 input file '$file' looks empty" unless @lines;

    my $snippet = join('', @lines);

    return <<"PROMPT";
You are Worker3. Produce Track B: anomalies + risks (data quality + operational).

Seed context from Worker1 (authoritative framing; do not rewrite it):
$seed

Raw CSV snippet (use only what is here; do not assume more rows than shown):
$snippet

Output rules (VERY IMPORTANT):
- No preamble. No code fences.
- If you cannot comply, output exactly: FAIL: <reason>
- Max 18 lines total.
- Use ONLY this schema and headers, in this order.
- Bullets must start with "- " exactly.
- Each bullet must be short (<= 90 chars).

SCHEMA:

TRACK_B
ANOMALIES:
- <5 bullets: outliers, missing fields, impossible values, spikes, inconsistencies>
RISKS:
- <3 bullets: what could go wrong if we trust this / likely causes / impact>
CHECKS:
- <2 bullets: concrete follow-up checks to confirm/refute anomalies>
PROMPT
}
