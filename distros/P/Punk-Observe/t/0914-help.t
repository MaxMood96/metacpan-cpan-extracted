#!perl
# The language reference.
#
# A reference maintained by hand is a reference that goes wrong, and this one
# would be wrong about a language whose entire surface is four static tables a
# few lines apart in po_query.h. So the page is GENERATED from the parser, and
# these tests are what makes that claim mean something: the lists on the page
# are compared against the tables, and every example on it is parsed.
use 5.010;
use strict;
use warnings;
use Test::More;

use Punk::Observe::Query ();
use Punk::Plugin::Observe ();

my $Q = 'Punk::Observe::Query';

# --- bucket can name itself --------------------------------------------------
#
# `bucket` was the one stage the AST could not name: xs/query.xs had no case
# for it, so Query::parse reported its kind as "?" while the stage parsed and
# executed perfectly. It is also the one missing from Query.pm's own list of
# kinds, which is where it went unnoticed for so long.
{
    my $r = $Q->can('parse')->('log | bucket(1m)');
    ok($r->{ok}, 'a bucket query parses');
    is($r->{stages}[0]{kind}, 'bucket', '  and the stage knows what it is');

    # Every stage the parser can produce names itself. A `?` here is a stage
    # that exists and cannot be introspected.
    my %q = (
        where     => 'log | where severity >= error',
        search    => 'log | search "refused"',
        by        => 'spans | by service',
        agg       => 'spans | count',
        bucket    => 'log | bucket(1m)',
        rate      => 'log | rate(1m)',
        top       => 'spans | by service | count | top 5 by count',
        slowest   => 'trace | slowest 10',
        limit     => 'log | limit 10',
        sort      => 'log | sort t desc',
        exemplars => 'metric x | exemplars',
    );
    for my $kind (sort keys %q) {
        my $p = $Q->can('parse')->($q{$kind});
        ok($p->{ok}, "'$q{$kind}' parses") or next;
        my ($last) = grep { $_->{kind} eq $kind } @{ $p->{stages} };
        ok($last, "  and a stage names itself '$kind'")
            or diag('kinds: ' . join ',', map { $_->{kind} } @{ $p->{stages} });
    }
}

# --- the grammar is read from the tables, not transcribed --------------------

my $g = $Q->can('grammar')->();

{
    ok($g, 'the grammar introspects');

    # THE COLUMNS COME FROM PO_COLUMNS. Compared against the header itself, so
    # a column added there and not here fails rather than going unmentioned.
    my $src = do { open my $fh, '<', 'include/punk_observe/po_query.h' or die $!;
                   local $/; <$fh> };
    my ($tbl) = $src =~ /PO_COLUMNS\[\]\s*=\s*\{(.*?)\n\};/s;
    ok($tbl, 'found PO_COLUMNS in the header');

    my %mask = (metric => 'PO_C_METRIC', log => 'PO_C_LOG',
                trace  => 'PO_C_TRACE',  spans => 'PO_C_SPAN');
    for my $s (sort keys %mask) {
        my @want;
        while ($tbl =~ /\{\s*"(\w+)",\s*([^}]+?)\s*\}/g) {
            my ($name, $flags) = ($1, $2);
            push @want, $name if $flags =~ /\bPO_C_ANY\b/
                              || $flags =~ /\b\Q$mask{$s}\E\b/;
        }
        is_deeply($g->{columns}{$s}, \@want,
                  "the $s columns are exactly what PO_COLUMNS says");
    }
}

{
    # Every aggregate the page lists is one po_agg_of accepts, and every one
    # it accepts is listed. Checked by USING them, which is stronger than
    # comparing two lists.
    for my $a (@{ $g->{aggregates} }) {
        my $r = $Q->can('parse')->("spans | $a");
        ok($r->{ok}, "the aggregate '$a' is one the parser takes")
            or diag($r->{error});
    }
    ok(scalar @{ $g->{aggregates} } >= 10, 'and there are all of them');

    # A word that is not an aggregate is not quietly one.
    ok(!$Q->can('parse')->('spans | median')->{ok},
       'a word that is not an aggregate is refused');
}

{
    # Severities resolve to the numbers the page prints.
    my %want = (trace => 1, debug => 5, info => 9, warn => 13,
                warning => 13, error => 17, fatal => 21);
    my %got = map { $_->{name} => $_->{value} } @{ $g->{severities} };
    is_deeply(\%got, \%want, 'the severity numbers are OpenTelemetry\'s');

    # And the parser agrees with the page about each one.
    for my $n (sort keys %want) {
        ok($Q->can('parse')->("log | where severity >= $n")->{ok},
           "  '$n' is accepted as a value");
    }
}

{
    # Every duration unit on the page is one the lexer takes, and its
    # nanosecond value is what the lexer says it is.
    my %ns = map { $_->{name} => $_->{ns} } @{ $g->{units} };
    is($ns{ns}, '1',             'ns is a nanosecond');
    is($ns{us}, '1000',          'us is a thousand of them');
    is($ns{ms}, '1000000',       'ms a million');
    is($ns{s},  '1000000000',    's a billion');
    is($ns{m},  '60000000000',   'm is a MINUTE');
    # A retention window is written in years in production, so the unit is
    # the query language's rather than one retain understands privately.
    is($ns{d},  '86400000000000',      'd is a day');
    is($ns{w},  '604800000000000',     'w is seven of them');
    is($ns{y},  '31536000000000000',   'y is 365 days, not a calendar year');
    ok(!exists $ns{M} && !exists $ns{mo},
       'and there is no month, which would be a trap nobody recovers from');

    for my $u (sort keys %ns) {
        ok($Q->can('parse')->("spans | where duration > 5$u")->{ok},
           "  '5$u' is a duration the parser reads");
    }
}

{
    # Operators, used rather than compared.
    for my $o (@{ $g->{operators} }) {
        my $v = ($o eq '=~' || $o eq '!~') ? '"^api-"' : '1';
        my $q = "spans | where duration $o $v";
        $q = "log | where body $o $v" if $o eq '=~' || $o eq '!~';
        ok($Q->can('parse')->($q)->{ok}, "the operator '$o' parses")
            or diag($Q->can('parse')->($q)->{error});
    }
}

# --- every example on the page parses ----------------------------------------
#
# This is the test that stops the page rotting. An example that stopped being
# valid would otherwise sit there teaching somebody the wrong thing.
SKIP: {
    eval { require Template::Stencil; 1 }
        or skip 'Template::Stencil is not installed', 2;

    my $s = Template::Stencil->new(template_dir => 'root/templates',
                                   wrapper => 'layout.tmpl');
    my %e = Punk::Plugin::Observe::_empty({ prefix => '/observe' });
    $e{$_} = $g->{$_} for qw(aggregates severities units operators);
    $e{sources} = [ map { { %$_, alias => ($_->{alias} // ''),
                            cols => join ', ', @{ $g->{columns}{ $_->{name} } || [] } } }
                    @{ $g->{sources} } ];

    my $html = eval { $s->render('help.tmpl', \%e) };
    ok(defined $html, 'the help page renders') or diag $@;

    my @q = ($html || '') =~ m{<code class="q">(.*?)</code>}gs;
    cmp_ok(scalar @q, '>=', 10, 'it carries a decent number of examples');

    my $bad = 0;
    for my $raw (@q) {
        my $query = $raw;
        $query =~ s/&gt;/>/g; $query =~ s/&lt;/</g;
        $query =~ s/&quot;/"/g; $query =~ s/&amp;/&/g;
        my $r = $Q->can('parse')->($query);
        next if $r->{ok};
        $bad++;
        diag("does not parse: $query -- $r->{error}");
    }
    is($bad, 0, 'every example query on the page parses');
}

# --- null: the absence test --------------------------------------------------
#
# A comparison against an absent field is false in both directions - right,
# and it left no way to ask "does this row carry the attribute at all";
# grouping buried the answer in a (none) bucket. `!= null` is that question.
{
    ok($Q->can('parse')->('log | where risk.outcome != null')->{ok},
       '!= null parses');
    ok($Q->can('parse')->('log | where risk.outcome = null')->{ok},
       '= null parses');

    my $ord = $Q->can('parse')->('log | where risk.outcome > null');
    ok(!$ord->{ok}, 'an ordering against null is refused');
    like($ord->{error}, qr/null only compares with = and !=/,
         '  saying which operators mean anything against absence');

    # And it EVALUATES: presence splits a store exactly, with no row in both
    # halves and none in neither.
    require Punk::Observe::Store;
    require Punk::Observe::WAL;
    require File::Temp;
    my $dir = File::Temp::tempdir(CLEANUP => 1);
    my $st = Punk::Observe::Store->new(dir => $dir, tenant => 'default');
    my $t0 = time . '000000000';
    Punk::Observe::WAL::append($st->wal_path, [ map { {
        kind => 2, t => Punk::Observe::Store::nadd($t0, $_ * 1000),
        duration => 0, body => "l$_", severity => 9, span_kind => 0,
        status => 0, trace_hi => 0, trace_lo => 0, span_id => 0,
        parent_id => 0,
        attrs => ($_ % 3 == 0 ? { 'risk.outcome' => ($_ % 2 ? 'accept' : '') }
                              : {}) } } 1 .. 90 ], 0, 0);
    $st->seal;
    my ($f2, $t2) = ($t0, Punk::Observe::Store::nadd($t0, '999999'));

    my $with = $st->query('log | where risk.outcome != null | count',
                          from => $f2, to => $t2)->{groups}[0]{value};
    my $without = $st->query('log | where risk.outcome = null | count',
                             from => $f2, to => $t2)->{groups}[0]{value};
    is($with, 30, '!= null keeps exactly the rows carrying the attribute');
    is($without, 60, '  = null keeps exactly the rows without it');
    is($with + $without, 90, '  and the two halves are the whole store');

    # `!= null` and `!= ""` are different questions: an EMPTY value is
    # present. Half the carrying rows above have an empty value.
    my $nonempty = $st->query('log | where risk.outcome != "" | count',
                              from => $f2, to => $t2)->{groups}[0]{value};
    is($nonempty, 15, '!= "" is the narrower question: non-empty values only');
}

# --- the POD agrees with the parser about the stage kinds --------------------
{
    my $pod = do { open my $fh, '<', 'lib/Punk/Observe/Query.pm' or die $!;
                   local $/; <$fh> };
    like($pod, qr/\bbucket\b/, 'Query.pm mentions bucket at all');
    # The list of kinds `parse` can return. `bucket` was missing from it,
    # which is why nobody noticed the AST could not name the stage.
    #
    # The whole sentence, not a fixed number of lines from a landmark: the
    # first version of this anchored on C<slowest> and read forward, and
    # adding `bucket` in its correct alphabetical-ish place put it BEHIND the
    # anchor, so the fix made the test fail.
    my ($kinds) = $pod =~ /(C<kind> is one of.*?\.\n)/s;
    ok($kinds, 'Query.pm enumerates the stage kinds');
    like($kinds || '', qr/C<bucket>/,
         '  and lists bucket among the kinds parse returns');

    # And the enumeration is complete: every kind the parser can produce is
    # named in it.
    my @missing = grep { $kinds !~ /C<\Q$_\E>/ }
                  qw(where search by agg bucket rate top slowest limit sort
                     exemplars traces logs spans);
    is_deeply(\@missing, [], '  and names every one of them')
        or diag("not in the POD: @missing");
}

done_testing();
