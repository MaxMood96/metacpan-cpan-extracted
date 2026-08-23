#!perl

# What the page diff REPORTS, as opposed to whether it fires. t/57 pins
# the firing: no corpus page moved. This pins the reading, because the
# only consumer is a person deciding whether to publish, and through
# 0.10 what they were handed was a bag of positioned words sorted by
# text - so replacing "may" with "we" printed five removed words and
# five added ones, in alphabetical order, and read as corruption:
#
#     Left     Aug change separately. ust we
#     Arrived  Au arately. gust sep
#
# Every assertion below is that sentence not happening again.

use strict;
use warnings;
use Test::More;
use PDF::Make::Markup::Render;
use PDF::Make::Markup::Diff;

local $ENV{SOURCE_DATE_EPOCH} = 1600000000;

sub render { PDF::Make::Markup::Render->render_markup($_[0]) }

sub compare {
    my ($a, $b) = @_;
    my $d = PDF::Make::Markup::Diff->diff(render($a), render($b));
    return ($d, $d->{pages}[0]);
}

my $BASE = "<doc><p>These terms may change separately. August 2026.</p></doc>\n";

subtest 'one word replaced names one word' => sub {
    my ($d, $p) = compare($BASE,
        "<doc><p>These terms we change separately. August 2026.</p></doc>\n");
    is $d->{changed}, 1, 'the page is flagged';
    is_deeply $p->{removed}, ['may'], 'only the word that went is reported';
    is_deeply $p->{added},   ['we'],  'only the word that arrived';
    is_deeply $p->{moved},   [],
        'the words the edit shifted along the line are not the news';
};

subtest 'identical renders report nothing' => sub {
    my ($d, $p) = compare($BASE, $BASE);
    is $d->{changed}, 0, 'no page changed';
    is_deeply [ @{$p}{qw(removed added moved)} ], [ [], [], [] ],
        'and nothing is reported';
};

subtest 'reading order survives' => sub {
    # The old sort was lexical over "text@x,y", so a page's report came
    # back alphabetised. Words inserted mid-sentence must read as the
    # phrase they are.
    my (undef, $p) = compare(
        "<doc><p>These terms may change.</p></doc>\n",
        "<doc><p>These terms may change without notice at any time.</p></doc>\n");
    is join(' ', @{ $p->{added} }), 'change without notice at any time.',
        'added words read left to right, not A to Z';
    is_deeply $p->{removed}, ['change.'], 'and the word they replaced';
};

subtest 'reading order runs down the page, not across it' => sub {
    my (undef, $p) = compare(
        "<doc><p>Alpha beta gamma.</p><p>Delta epsilon zeta.</p></doc>\n",
        "<doc><p>Alpha omega gamma.</p><p>Delta psi zeta.</p></doc>\n");
    is_deeply $p->{removed}, [ 'beta', 'epsilon' ],
        'the first line is reported before the second';
    is_deeply $p->{added}, [ 'omega', 'psi' ], 'on both sides';
};

subtest 'a deletion is a deletion' => sub {
    my (undef, $p) = compare($BASE,
        "<doc><p>These terms change separately. August 2026.</p></doc>\n");
    is_deeply $p->{removed}, ['may'], 'the word that went';
    is_deeply $p->{added}, [], 'and nothing arrived';
};

subtest 'a page that only reflowed reports its movement' => sub {
    # The engine-upgrade case, and the reason `moved` exists: every word
    # survived, in a new place. Nothing textual to report, and a report
    # of nothing would read as "no change".
    my ($d, $p) = compare(
        "<doc><p>These terms may change separately.</p></doc>\n",
        "<doc margin=\"80\"><p>These terms may change separately.</p></doc>\n");
    is $d->{changed}, 1, 'the page is still flagged';
    is_deeply [ @{$p}{qw(removed added)} ], [ [], [] ],
        'with nothing removed or added';
    is join(' ', @{ $p->{moved} }), 'These terms may change separately.',
        'and the moved words named, in reading order';
};

subtest 'a rewritten page reports both sides whole' => sub {
    my (undef, $p) = compare($BASE,
        "<doc><p>Nothing whatsoever in common here.</p></doc>\n");
    is join(' ', @{ $p->{removed} }),
        'These terms may change separately. August 2026.', 'all of the old';
    is join(' ', @{ $p->{added} }),
        'Nothing whatsoever in common here.', 'all of the new';
};

subtest 'the report is capped' => sub {
    my $many = join ' ', map { "word$_" } 1 .. 200;
    my (undef, $p) = compare(
        "<doc><p>$many</p></doc>\n",
        "<doc><p>@{[ join ' ', map { qq{other$_} } 1 .. 200 ]}</p></doc>\n");
    cmp_ok scalar @{ $p->{removed} }, '<=', 40, 'removed is capped';
    cmp_ok scalar @{ $p->{added} },   '<=', 40, 'added is capped';
    is $p->{removed}[0], 'word1', 'and capped from the front, so it reads';
};

subtest 'words come back whole, not in extraction fragments' => sub {
    # The other half of the corruption the report showed. Structured
    # extraction reports a word per text run, and the run boundaries are
    # the writer's business, not the sentence's: the same line came back
    # as "Aug" "ust" from one render and "Au" "gust" from the next, so a
    # comparison of the pieces reported four changes to a line nobody had
    # touched. Pieces with no gap between them are one word.
    my $pages = PDF::Make::Markup::Diff->pages(render(
        "<doc><p>One item is on back order and will follow separately."
      . " 28 August 2026.</p></doc>\n"));
    is_deeply [ map { $_->{text} } @{ $pages->[0] } ],
        [ qw(One item is on back order and will follow separately.
             28 August 2026.) ],
        'every word is the word, in reading order';
};

subtest 'an edit mid-sentence reports only the edit' => sub {
    # The customer report this file exists for, on the shape of document
    # it happened to: the whole line re-extracted, so all of it read as
    # changed and none of it read as English.
    my (undef, $p) = compare(
        "<doc><p>One item is on back order and will follow separately."
      . " 28 August 2026.</p></doc>\n",
        "<doc><p>One item is on back order and we change separately."
      . " 28 August 2026.</p></doc>\n");
    is join(' ', @{ $p->{removed} }), 'will follow', 'what went';
    is join(' ', @{ $p->{added} }),   'we change',   'what arrived';
};

subtest 'pages() hands back words in reading order' => sub {
    my $pages = PDF::Make::Markup::Diff->pages(render($BASE));
    is scalar @$pages, 1, 'one page';
    my @words = @{ $pages->[0] };
    ok scalar @words, 'with words in it';
    is $words[0]{text}, 'These', 'the first word is the first word';
    ok exists $words[0]{x} && exists $words[0]{y}, 'carrying coordinates';
    my $prev = $words[0];
    for my $w (@words[ 1 .. $#words ]) {
        ok $w->{y} < $prev->{y} || ($w->{y} == $prev->{y} && $w->{x} >= $prev->{x}),
            "'$w->{text}' follows '$prev->{text}' in reading order";
        $prev = $w;
    }
};

done_testing();
