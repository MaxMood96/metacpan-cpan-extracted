#!perl
# A SOURCE CHECK, because the bug it names is invisible at runtime here.
#
# SvIV, SvUV and SvNV mention their argument more than once until 5.37.1, and
# SvTRUE did until 5.32, so SvIV(POPs) pops once per mention: the value is read
# from whatever sits below the one that was returned. A modern perl evaluates
# once and runs the same line correctly, so no behavioural test can fail on it
# here. Only reading the source catches it, on every perl including this one.
#
# TOPs is (*sp) and has no side effect, so multi-evaluating it is harmless -
# this guard deliberately does not flag it.
#
# The fix is always the same shape: pop into a variable, then convert that.
use strict;
use warnings;
use Test::More;

my @src = grep { -f } ('APIKey.xs', glob('xs/*.xs'), glob('include/pak/*.h'));
plan skip_all => 'XS sources are not in this tree' unless @src;

# The macros that were fixed in 5.32 (SvTRUE) and 5.37.1 (SvIV/SvUV/SvNV).
# SvOK, SvROK and SvTYPE are single-mention and are deliberately not here.
my $MULTI = qr/\bSv(?:TRUE(?:_nomg)?|IV|UV|NV|PV(?:byte|utf8)?(?:_nolen)?)\s*\(/;

my $checked = 0;
for my $file (@src) {
    open my $fh, '<', $file or die "$file: $!";
    my $src = do { local $/; <$fh> };
    close $fh;
    $checked++;

    # Blank out comments and literals, keeping every newline so the line
    # numbers still name the code. Without this the guard reports the prose
    # explaining the trap as an instance of it.
    $src =~ s{
        ( " (?: \\. | [^"\\]  )*  "      )   # a string
      | ( ' (?: \\. | [^'\\\n] )   '      )   # a character
      | ( /\* .*? \*/                     )   # a block comment
      | ( // [^\n]*                       )   # a line comment
    }{ my $t = $&; $t =~ s/[^\n]/ /g; $t }gsex;

    my @bad;
    while ($src =~ /$MULTI/g) {
        my $open = pos($src) - 1;      # the '(' the macro name ended on
        my ($depth, $i) = (0, $open);
        my $len = length $src;
        # Walk to the matching close paren so the argument is the whole
        # argument, not whatever fitted on one line.
        while ($i < $len) {
            my $c = substr($src, $i, 1);
            $depth++ if $c eq '(';
            if ($c eq ')') { $depth--; last if $depth == 0 }
            $i++;
        }
        my $arg = substr($src, $open + 1, $i - $open - 1);
        next unless $arg =~ /\bPOP[a-z]?\b/;
        my $line = 1 + (() = substr($src, 0, $open) =~ /\n/g);
        push @bad, "$file:$line: " . join(' ', split ' ', $arg);
    }

    is(scalar @bad, 0, "$file pops before it converts")
        or diag("a multi-eval Sv macro pops the stack once per mention:\n  "
                . join("\n  ", @bad));
}

cmp_ok($checked, '>', 1, 'more than one source was read');

done_testing;
