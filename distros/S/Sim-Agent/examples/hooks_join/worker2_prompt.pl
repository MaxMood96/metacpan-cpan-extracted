use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    my $file = $ENV{SIM_AGENT_INPUT} || 'examples/data/demo_metrics.csv';

    my $seed = $ctx->{inputs}{Worker1}{output}
        or die "Worker2 missing input key Worker1";

    open my $fh, '<', $file or die "Worker2 cannot open input file '$file': $!";

    my $max_lines = 30;
    my @lines;
    while (my $line = <$fh>) {
        $line =~ s/\r\n/\n/g;
        push @lines, $line;
        last if @lines >= $max_lines;
    }
    close $fh;

    die "Worker2 input file '$file' looks empty" unless @lines;

    my $snippet = join('', @lines);

    return <<"PROMPT";
You are Worker2. Produce Track A: compact quantitative-ish stats + simple trends.

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

TRACK_A
STATS:
- <5 bullets: counts/averages/ranges/distributions you can justify from snippet>
TRENDS:
- <3 bullets: simple patterns over time/service/region visible in snippet>
CAVEATS:
- <2 bullets: what limits confidence / missingness / sampling>
PROMPT
}
