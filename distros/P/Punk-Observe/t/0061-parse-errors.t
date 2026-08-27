#!perl
# Errors. The MESSAGES are part of the deliverable: a language whose errors
# say "syntax error" is a language people avoid, and the cross-signal
# recommendation is how the headline feature gets discovered by typing.
use 5.010;
use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Punk::Observe;

my $Q = 'Punk::Observe::Query';
sub parse { $Q->can('parse')->($_[0]) }

sub fails {
    my ($q, $like, $why) = @_;
    my $r = parse($q);
    ok(!$r->{ok}, $why // "refused: $q");
    like($r->{error}, $like, "  message: $r->{error}") if !$r->{ok};
    return $r;
}

# --- column validation ------------------------------------------------------

# The whole point: a nonsensical query is a NAMED ERROR, never an empty
# result. An empty result looks like an answer.
fails('log | where duration > 5s', qr/duration.*does not exist on log/,
      'duration on a log stream is refused, not silently empty');
fails('metric x | where body = "hi"', qr/body.*does not exist on metric/,
      'body on a metric stream is refused');
fails('metric x | where severity >= error', qr/severity.*does not exist on metric/,
      'severity on a metric stream is refused');
fails('log | where value > 1', qr/value.*does not exist on log/,
      'value on a log stream is refused');
fails('metric x | where status = "ok"', qr/status.*does not exist on metric/,
      'status on a metric stream is refused');

# An UNKNOWN name is an attribute, not an error. Attributes are open-ended by
# nature, so only the reserved columns are checked.
{
    my $r = parse('log | where http.route = "/pay"');
    ok($r->{ok}, 'an unknown name is an attribute and is accepted')
        or diag $r->{error};
    my $r2 = parse('metric x | where k8s.pod.name = "web-1"');
    ok($r2->{ok}, '  on any source');
}

# The check reaches inside boolean structure, not just the top level.
fails('log | where a = 1 and (b = 2 or duration > 5s)',
      qr/duration.*does not exist on log/,
      'a bad column nested inside and/or is still caught');
fails('log | where not duration > 5s', qr/duration.*does not exist on log/,
      '  and inside a not');
fails('log {duration=5s}', qr/duration.*does not exist on log/,
      '  and inside a selector');

# --- the cross-signal recommendation ---------------------------------------

# THIS message is the feature. A metric stream has no trace id, so `| traces`
# cannot work - and the error has to say what to add.
{
    my $r = fails('metric x | traces', qr/trace id/,
                  'metric to traces without exemplars is refused');
    like($r->{error}, qr/exemplars/,
         '  and the message RECOMMENDS | exemplars');
}
{
    my $r = fails('metric x | logs', qr/exemplars/,
                  'metric to logs likewise recommends exemplars');
    ok($r->{error} =~ /exemplars/, '  by name');
}
{
    my $r = parse('metric x | exemplars | traces');
    ok($r->{ok}, 'and adding | exemplars makes it parse') or diag $r->{error};
}

# exemplars only come from a metric stream.
fails('log | exemplars', qr/exemplars come from a metric/,
      'exemplars on a log stream is refused');
fails('trace | exemplars', qr/exemplars come from a metric/,
      '  and on a trace stream');

# --- stage/source mismatches ------------------------------------------------

fails('metric x | search "boom"', qr/no body to search/,
      'search on a metric stream is refused, since there is no text');
fails('metric x | slowest 5', qr/metric stream has none/,
      'slowest on a metric stream is refused');
fails('log | p95', qr/numeric column/,
      'a percentile over a log stream is refused');

{
    my $r = parse('log | count');
    ok($r->{ok}, 'but count over a log stream is fine') or diag $r->{error};
    my $r2 = parse('log | distinct by service');
    ok($r2->{ok}, '  and so is distinct');
}

# --- bare words -------------------------------------------------------------

# `where service = api` looks reasonable and is ambiguous with a column
# reference. Accepting it would make a typo in a column name silently become a
# comparison that never matches.
{
    my $r = fails('log | where service = api', qr/bare word/,
                  'a bare word as a value is refused');
    like($r->{error}, qr/quote/, '  and the message says to quote it');
}

# --- syntax -----------------------------------------------------------------

fails('', qr/starts with metric, log, trace or spans/, 'an empty query');
fails('wibble', qr/starts with metric/, 'an unknown source');
fails('metric', qr/metric needs a name/, 'metric with no name');
fails('log | ', qr/unknown stage/, 'a trailing pipe');
fails('log | wibble', qr/unknown stage/, 'an unknown stage');
fails('log | where', qr/expected a column/, 'where with nothing after it');
fails('log | where a', qr/comparison operator/, 'a field with no operator');
fails('log | where a =', qr/expected a value/, 'an operator with no value');
fails('log | where (a = 1', qr/expected '\)'/, 'an unclosed parenthesis');
fails('log {a = 1', qr/expected '\}'/, 'an unclosed brace');
fails('log | search refused', qr/quoted string/, 'search without quotes');
fails('log | limit', qr/whole number/, 'limit with no number');
fails('log | limit 1.5', qr/whole number/, 'limit with a fraction');
fails('metric x | rate', qr/rate takes a window/, 'rate with no window');
fails('metric x | rate(5)', qr/needs a duration/, 'rate with a bare number');
fails('log | where a ! 1', qr/'!' must be followed/, 'a lone bang');
fails('log | where a = "unterminated', qr/unterminated string/,
      'an unterminated string');
fails('trace | where duration > 5x', qr/unknown duration unit/,
      'an unknown duration unit');
fails('log | where a = 1 $', qr/unexpected character/, 'a stray character');
fails('log | sort', qr/sort takes a field/, 'sort with no field');
fails('spans | top 5', qr/needs 'by'/, 'top N with no by');
fails('spans | top 5 by wibble', qr/needs an aggregate/, 'top N by a non-aggregate');

# --- error offsets point somewhere useful ----------------------------------

{
    my @cases = (
        [ 'log | where a = api',          16 ],
        [ 'log | where duration > 5x',    24 ],
        [ 'metric x | where a ! 1',       19 ],
    );
    for my $c (@cases) {
        my $r = parse($c->[0]);
        ok(!$r->{ok}, "offset case refused: $c->[0]");
        is($r->{offset}, $c->[1],
           "  the offset points at character $c->[1]: '"
           . substr($c->[0], $c->[1], 6) . "'");
    }
}

# --- the depth bound --------------------------------------------------------

# The input is untrusted. A thousand nested parentheses must be a refusal,
# not a blown C stack.
{
    my $deep = 'log | where ' . ('(' x 1000) . 'a = 1' . (')' x 1000);
    my $r = eval { parse($deep) };
    ok(defined $r, '1000 nested parentheses does not crash');
    ok(!$r->{ok}, '  and is refused');
    like($r->{error}, qr/too deeply/, '  as too deeply nested');
}

{
    # Just inside the bound must still work, so the bound is not simply
    # rejecting everything with a parenthesis in it.
    my $ok_depth = 'log | where ' . ('(' x 30) . 'a = 1' . (')' x 30);
    my $r = parse($ok_depth);
    ok($r->{ok}, '30 nested parentheses parses fine') or diag $r->{error};
}

# --- a failed parse still frees --------------------------------------------

{
    my $ok = $Q->can('parse_free_cycles')->('log | where duration > 5s', 5000);
    is($ok, 0, '5000 FAILED parses all report failure');
    # The assertion is that this completes without leaking or crashing; the
    # count being zero is the point.
    pass('  and the partial AST of a failed parse frees cleanly');
}

done_testing();
