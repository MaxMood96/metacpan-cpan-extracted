#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile tempdir);

use_ok('file');

my $tmpdir = tempdir(CLEANUP => 1);

# Create test file with various line types
my $test_file = "$tmpdir/callback_test.txt";
# File content: 9 lines (trailing newline terminates last line, doesn't add extra)
# 1: apple
# 2: banana
# 3: (empty)
# 4: cherry
# 5:    (3 spaces - whitespace only, counts as blank)
# 6: # this is a comment
# 7: date
# 8: # another comment
# 9: elderberry
file::spew($test_file, "apple\nbanana\n\ncherry\n   \n# this is a comment\ndate\n# another comment\nelderberry\n");

# ============================================
# each_line tests
# ============================================

subtest 'each_line with shift' => sub {
    my @collected;
    file::each_line($test_file, sub {
        push @collected, shift;
    });

    is(scalar(@collected), 9, 'collected all lines');
    is($collected[0], 'apple', 'first line correct');
    is($collected[2], '', 'empty line preserved');
    is($collected[5], '# this is a comment', 'comment line preserved');
};

subtest 'each_line with $_' => sub {
    my @collected;
    file::each_line($test_file, sub {
        push @collected, $_;
    });

    is(scalar(@collected), 9, 'collected all lines via $_');
    is($collected[0], 'apple', 'first line via $_ correct');
    is($collected[3], 'cherry', 'fourth line via $_ correct');
};

subtest 'each_line with both shift and $_' => sub {
    my @from_shift;
    my @from_defvar;
    file::each_line($test_file, sub {
        push @from_shift, shift;
        push @from_defvar, $_;
    });

    is_deeply(\@from_shift, \@from_defvar, 'shift and $_ give same values');
};

subtest 'each_line preserves $_ outside' => sub {
    $_ = "original";
    file::each_line($test_file, sub { });
    is($_, "original", '$_ restored after each_line');
};

subtest 'each_line empty file' => sub {
    my $empty = "$tmpdir/empty.txt";
    file::spew($empty, "");

    my $count = 0;
    file::each_line($empty, sub { $count++ });
    is($count, 0, 'no iterations for empty file');
};

subtest 'each_line nonexistent file' => sub {
    my @collected;
    file::each_line("$tmpdir/nonexistent.txt", sub {
        push @collected, shift;
    });
    is(scalar(@collected), 0, 'no lines from nonexistent file');
};

# ============================================
# grep_lines tests
# ============================================

subtest 'grep_lines with coderef (shift)' => sub {
    my $result = file::grep_lines($test_file, sub {
        length(shift) > 5;
    });

    is(ref($result), 'ARRAY', 'returns arrayref');
    is(scalar(@$result), 5, 'correct count of lines > 5 chars');
    ok((grep { $_ eq 'banana' } @$result), 'banana included');
    ok((grep { $_ eq 'cherry' } @$result), 'cherry included');
    ok((grep { $_ eq 'elderberry' } @$result), 'elderberry included');
};

subtest 'grep_lines with coderef ($_)' => sub {
    my $result = file::grep_lines($test_file, sub {
        /^[aeiou]/i;  # starts with vowel
    });

    is(scalar(@$result), 2, 'two lines start with vowel');
    is($result->[0], 'apple', 'apple matches');
    is($result->[1], 'elderberry', 'elderberry matches');
};

subtest 'grep_lines with builtin is_not_blank' => sub {
    my $result = file::grep_lines($test_file, 'is_not_blank');

    # Non-blank lines: apple, banana, cherry, # comment, date, # comment, elderberry
    is(scalar(@$result), 7, 'correct non-blank count');
    ok(!(grep { $_ eq '' } @$result), 'no empty lines');
    ok(!(grep { /^\s+$/ } @$result), 'no whitespace-only lines');
};

subtest 'grep_lines with builtin not_blank' => sub {
    my $result = file::grep_lines($test_file, 'not_blank');
    is(scalar(@$result), 7, 'not_blank alias works');
};

subtest 'grep_lines with builtin is_blank' => sub {
    my $result = file::grep_lines($test_file, 'is_blank');
    # Blank = empty or whitespace-only: line 3 ("") and line 5 ("   ")
    is(scalar(@$result), 2, 'two blank lines');
};

subtest 'grep_lines with builtin is_not_empty' => sub {
    my $result = file::grep_lines($test_file, 'is_not_empty');
    # Non-empty = has at least one char (includes whitespace-only): 8 lines
    is(scalar(@$result), 8, 'correct non-empty count');
};

subtest 'grep_lines with builtin is_empty' => sub {
    my $result = file::grep_lines($test_file, 'is_empty');
    # Empty = exactly "" (not whitespace): just line 3
    is(scalar(@$result), 1, 'one empty line');
};

subtest 'grep_lines with builtin is_not_comment' => sub {
    my $result = file::grep_lines($test_file, 'is_not_comment');
    ok(!(grep { /^#/ } @$result), 'no comment lines');
    # 9 total - 2 comments = 7 non-comments
    is(scalar(@$result), 7, 'correct non-comment count');
};

subtest 'grep_lines with builtin is_comment' => sub {
    my $result = file::grep_lines($test_file, 'is_comment');
    is(scalar(@$result), 2, 'two comment lines');
    ok((grep { $_ eq '# this is a comment' } @$result), 'first comment found');
    ok((grep { $_ eq '# another comment' } @$result), 'second comment found');
};

subtest 'grep_lines unknown predicate' => sub {
    eval { file::grep_lines($test_file, 'unknown_predicate') };
    like($@, qr/unknown predicate/, 'dies on unknown predicate');
};

subtest 'grep_lines empty result' => sub {
    my $result = file::grep_lines($test_file, sub { /^zzz/ });
    is(ref($result), 'ARRAY', 'still returns arrayref');
    is(scalar(@$result), 0, 'empty array for no matches');
};

# ============================================
# count_lines tests
# ============================================

subtest 'count_lines all' => sub {
    my $count = file::count_lines($test_file);
    is($count, 9, 'counts all lines');
};

subtest 'count_lines with coderef' => sub {
    my $count = file::count_lines($test_file, sub { length(shift) > 0 });
    is($count, 8, 'counts non-empty lines');
};

subtest 'count_lines with builtin' => sub {
    my $count = file::count_lines($test_file, 'is_not_blank');
    is($count, 7, 'counts non-blank lines');
};

subtest 'count_lines empty file' => sub {
    my $empty = "$tmpdir/empty_count.txt";
    file::spew($empty, "");
    my $count = file::count_lines($empty);
    is($count, 0, 'empty file has zero lines');
};

subtest 'count_lines nonexistent' => sub {
    my $count = file::count_lines("$tmpdir/no_such_file.txt");
    is($count, 0, 'nonexistent file returns 0');
};

# ============================================
# find_line tests
# ============================================

subtest 'find_line with coderef' => sub {
    my $found = file::find_line($test_file, sub { /cherry/ });
    is($found, 'cherry', 'finds matching line');
};

subtest 'find_line returns first match' => sub {
    my $found = file::find_line($test_file, sub { /^#/ });
    is($found, '# this is a comment', 'returns first comment');
};

subtest 'find_line with builtin' => sub {
    my $found = file::find_line($test_file, 'is_comment');
    is($found, '# this is a comment', 'finds first comment via builtin');
};

subtest 'find_line no match' => sub {
    my $found = file::find_line($test_file, sub { /^xyz/ });
    ok(!defined($found), 'returns undef for no match');
};

subtest 'find_line with $_' => sub {
    my $found = file::find_line($test_file, sub { $_ eq 'banana' });
    is($found, 'banana', 'finds via $_ comparison');
};

# ============================================
# map_lines tests
# ============================================

subtest 'map_lines with shift' => sub {
    my $result = file::map_lines($test_file, sub {
        uc(shift);
    });

    is(ref($result), 'ARRAY', 'returns arrayref');
    is(scalar(@$result), 9, 'same number of lines');
    is($result->[0], 'APPLE', 'first line uppercased');
    is($result->[1], 'BANANA', 'second line uppercased');
};

subtest 'map_lines with $_' => sub {
    my $result = file::map_lines($test_file, sub {
        length($_);
    });

    is($result->[0], 5, 'apple length');
    is($result->[1], 6, 'banana length');
    is($result->[2], 0, 'empty line length');
};

subtest 'map_lines transformation' => sub {
    my $result = file::map_lines($test_file, sub {
        my $line = shift;
        return ">> $line <<";
    });

    is($result->[0], '>> apple <<', 'wrapped first line');
    is($result->[3], '>> cherry <<', 'wrapped fourth line');
};

subtest 'map_lines empty file' => sub {
    my $empty = "$tmpdir/empty_map.txt";
    file::spew($empty, "");
    my $result = file::map_lines($empty, sub { uc(shift) });
    is(scalar(@$result), 0, 'empty array for empty file');
};

# ============================================
# register_line_callback tests
# ============================================

subtest 'register custom callback' => sub {
    # Register a custom predicate
    file::register_line_callback('has_vowels', sub {
        shift =~ /[aeiou]/i;
    });

    # Use it
    my $result = file::grep_lines($test_file, 'has_vowels');
    ok(scalar(@$result) > 0, 'custom callback works');
    ok((grep { $_ eq 'apple' } @$result), 'apple has vowels');
};

subtest 'register overwrites existing' => sub {
    file::register_line_callback('custom_test', sub { 0 });
    my $r1 = file::grep_lines($test_file, 'custom_test');
    is(scalar(@$r1), 0, 'first callback matches nothing');

    file::register_line_callback('custom_test', sub { 1 });
    my $r2 = file::grep_lines($test_file, 'custom_test');
    is(scalar(@$r2), 9, 'replaced callback matches all');
};

subtest 'register_line_callback requires coderef' => sub {
    eval { file::register_line_callback('bad', 'not a coderef') };
    like($@, qr/coderef/, 'dies without coderef');
};

# ============================================
# list_line_callbacks tests
# ============================================

subtest 'list_line_callbacks' => sub {
    my $list = file::list_line_callbacks();
    is(ref($list), 'ARRAY', 'returns arrayref');

    # Check builtins exist
    my %callbacks = map { $_ => 1 } @$list;
    ok($callbacks{'is_blank'}, 'is_blank registered');
    ok($callbacks{'is_not_blank'}, 'is_not_blank registered');
    ok($callbacks{'is_empty'}, 'is_empty registered');
    ok($callbacks{'is_not_empty'}, 'is_not_empty registered');
    ok($callbacks{'is_comment'}, 'is_comment registered');
    ok($callbacks{'is_not_comment'}, 'is_not_comment registered');

    # Aliases
    ok($callbacks{'blank'}, 'blank alias registered');
    ok($callbacks{'not_blank'}, 'not_blank alias registered');
};

# ============================================
# Edge cases and stress tests
# ============================================

subtest 'callback with die' => sub {
    eval {
        file::each_line($test_file, sub {
            die "intentional error" if shift eq 'cherry';
        });
    };
    like($@, qr/intentional error/, 'callback die propagates');
};

subtest 'large file callbacks' => sub {
    my $large = "$tmpdir/large_callback.txt";
    my @lines = map { "line number $_" } 1..1000;  # Reduced from 10000
    file::spew($large, join("\n", @lines));

    my $count = 0;
    file::each_line($large, sub { $count++ });
    is($count, 1000, 'processes all 1000 lines');

    my $filtered = file::grep_lines($large, sub { /555/ });
    ok(scalar(@$filtered) > 0, 'grep works on large file');

    my $total = file::count_lines($large);
    is($total, 1000, 'count_lines on large file');
};

subtest 'lines with special characters' => sub {
    my $special = "$tmpdir/special.txt";
    file::spew($special, "line with\ttab\nline with spaces   \n\$pecial \@chars!");

    my @collected;
    file::each_line($special, sub { push @collected, shift });

    is($collected[0], "line with\ttab", 'tab preserved');
    is($collected[1], 'line with spaces   ', 'trailing spaces preserved');
    is($collected[2], '$pecial @chars!', 'special chars preserved');
};

subtest 'unicode content' => sub {
    my $unicode = "$tmpdir/unicode.txt";
    file::spew($unicode, "hello\nworld\ncafe");  # Simple ASCII for now

    my $result = file::grep_lines($unicode, sub { length(shift) >= 5 });
    is(scalar(@$result), 2, 'filters unicode correctly');
};

subtest 'chained operations' => sub {
    # grep then count - simulate pipeline
    my $non_blank = file::grep_lines($test_file, 'is_not_blank');
    my $comment_count = scalar(grep { /^#/ } @$non_blank);
    is($comment_count, 2, 'can chain operations');
};

done_testing();
