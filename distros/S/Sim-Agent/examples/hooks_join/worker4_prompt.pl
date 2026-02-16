use strict;
use warnings;

sub {
    my ($ctx, $agent, $runner) = @_;

    die "Worker4 missing input key Worker2" unless exists $ctx->{inputs}{Worker2};
    die "Worker4 missing input key Worker3" unless exists $ctx->{inputs}{Worker3};
    die "Worker4 missing input key Worker1" unless exists $ctx->{inputs}{Worker1};

    my $w1 = $ctx->{inputs}{Worker1}{output} // '';
    my $w2 = $ctx->{inputs}{Worker2}{output} // '';
    my $w3 = $ctx->{inputs}{Worker3}{output} // '';

    my $t2 = $ctx->{inputs}{Worker2}{tainted} ? "1" : "0";
    my $t3 = $ctx->{inputs}{Worker3}{tainted} ? "1" : "0";

    return <<"PROMPT";
You are Worker4. Join Track A + Track B into one final report.

Inputs (verbatim):
--- CONTEXT (Worker1) ---
$w1

--- TRACK_A (Worker2) [tainted=$t2] ---
$w2

--- TRACK_B (Worker3) [tainted=$t3] ---
$w3

Output rules:
- No preamble. No code fences.
- If you cannot comply, output exactly: FAIL: <reason>
- Max 28 lines total.
- Use ONLY this schema and headers, in this order.
- Bullets must start with "- " exactly.
- Keep bullets short (<= 95 chars).

SCHEMA:

REPORT
SUMMARY:
- <2 bullets: direct answer to TARGET_QUESTION + overall health>
KEY_STATS:
- <3 bullets: pick the most defensible stats from TRACK_A>
TOP_TRENDS:
- <3 bullets: pick the most defensible trends from TRACK_A>
TOP_ANOMALIES:
- <3 bullets: pick the most important anomalies from TRACK_B>
RISKS:
- <3 bullets: highest-impact risks (operational + data quality)>
NEXT_STEPS:
- <4 bullets: concrete actions, ordered by urgency>
PROMPT
}
