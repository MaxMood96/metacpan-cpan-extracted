#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

use lib "$FindBin::Bin/../lib";
use App::SlimPacker qw(process name_gen needs_space);

# ── name_gen ──────────────────────────────────────────────────────────────
is name_gen(0),  'a',  'name_gen(0) = a';
is name_gen(1),  'b',  'name_gen(1) = b';
is name_gen(25), 'z',  'name_gen(25) = z';
is name_gen(26), 'aa', 'name_gen(26) = aa';
is name_gen(27), 'ab', 'name_gen(27) = ab';

# ── process: comment + POD stripping ──────────────────────────────────────
{
    my $out = process("use strict;\n# comment\nmy \$foo = 1;\n=head1 DOC\n=cut\nprint \"\$foo\\n\";\n");
    unlike $out, qr/comment/, 'comments stripped';
    unlike $out, qr/=head1/,  'POD stripped';
    like $out, qr/\$foo/,     'code preserved';
}

# ── process: whitespace stripping ─────────────────────────────────────────
{
    my $src = "use strict;\n\n\nuse warnings;\n";
    my $out = process($src);
    unlike $out, qr/\n\n/, 'blank lines collapsed';
}

# ── process: `use Foo VERSION (LIST)` keeps the space before the paren ────
# `use Foo 5.57(qw/x/)` (no space) is a Perl syntax error.
{
    my $src = "use Exporter 5.57   (qw/import/);\n1;\n";
    my $out = process($src);
    like $out, qr/5\.57 \(/, 'space preserved between VERSION and (LIST)';
    ok eval $out, 'minified use VERSION(LIST) still compiles';
}

# ── process: newline-split postfix `if` keeps a space before the keyword ──
# `push @x, $path\n  if $cond` must not become `$pathif$cond`.
{
    my $src = "my (\@dirs, \$path);\npush \@dirs, \$path\n  if \$path =~ /x/;\n1;\n";
    my $out = process($src);
    unlike $out, qr/\$pathif/, 'no bare-var/keyword merge across a newline';
    ok(do { no warnings 'uninitialized'; eval $out }, 'minified newline-split postfix if compiles');
}

# ── process: rename => 0 disables renaming ────────────────────────────────
{
    my $src = 'my $longname = 1; print $longname;';
    my $out = process($src, rename => 0);
    like $out, qr/\$longname/, 'rename=0 keeps variable names';
}

# ── process: renames variables ────────────────────────────────────────────
{
    my $src = 'my $longname = 1; print $longname;';
    my $out = process($src, rename => 1);
    unlike $out, qr/\$longname/, 'long variable renamed';
    like $out, qr/\$[a-z]+/,     'short name assigned';
}

# ── process: single-char names NOT renamed ────────────────────────────────
{
    my $src = 'my $x = 1; print $x;';
    my $out = process($src);
    like $out, qr/\$x/, 'single-char $x preserved';
}

# ── process: uppercase names NOT renamed ──────────────────────────────────
{
    my $src = 'my $COUNT = 1; print $COUNT;';
    my $out = process($src);
    like $out, qr/\$COUNT/, 'ALL_CAPS $COUNT preserved';
}

# ── process: %KEEP names NOT renamed ──────────────────────────────────────
{
    for my $name (qw(self class VERSION)) {
        my $src = "my \$$name = 1; print \$$name;";
        my $out = process($src);
        like $out, qr/\$$name/, "\%KEEP name \$$name preserved";
    }
}

# ── process: variables inside double-quoted strings NOT renamed ───────────
{
    my $src = q{my $title = "hello"; print "$title\n";};
    my $out = process($src);
    # $title is in a string → not renamed anywhere
    like $out, qr/\$title/, '$title preserved (in string)';
}

# ── process: variables inside m// NOT renamed ─────────────────────────────
{
    my $src = q{my $only = "foo"; $x =~ m!$only!;};
    my $out = process($src);
    like $out, qr/\$only/, '$only preserved (in regex m//)';
}

# ── process: variables inside s/// NOT renamed ────────────────────────────
{
    my $src = q{my $pkg_dir = "Foo"; $d =~ s/\Q$pkg_dir\E/$pkg_dir/i;};
    my $out = process($src);
    like $out, qr/\$pkg_dir/, '$pkg_dir preserved (in regex s///)';
}

# ── process: variables inside qr// NOT renamed ────────────────────────────
{
    my $src = q{my $file_regex = qr/\.pm$/; $f =~ /(.*$file_regex)$/;};
    my $out = process($src);
    like $out, qr/\$file_regex/, '$file_regex preserved (in qr//)';
}

# ── process: heredoc contents scanned for variable names ──────────────────
{
    my $src = "my \$greeting = \"hi\";\nmy \$tmpl = <<\"EOF\";\nhello \$greeting\nEOF\nprint \$tmpl;\n";
    my $out = process($src);
    like $out, qr/\$greeting/, 'name inside heredoc body preserved';
    unlike $out, qr/\$tmpl/,   'heredoc variable itself renamed';
}

# ── process: backtick / readline scanned for variable names ───────────────
{
    my $src = q{my $dir = "/tmp"; my $listing = `ls $dir`; my $self = <$fh>;};
    my $out = process($src);
    like $out, qr/\$dir/, 'name inside backticks preserved';
}

# ── process: ${var} brace form scanned for variable names ─────────────────
{
    my $src = q{my $yrs = 30; print "${yrs}yo";};
    my $out = process($src);
    like $out, qr/\$yrs/, '${name} inside string preserved';
}

# ── needs_space: every spacing rule, both outcomes ────────────────────────
use PPI ();
sub nt { my ($c, $s) = @_; my $cl = "PPI::Token::$c"; no strict 'refs'; return $cl->new($s) }
{
    # rule 1: word-char left, word-char right  → space
    is needs_space(nt('Word','foo'), nt('Word','bar')), 1, 'wc+wc → space';
    # rule 2: trailing sigil left, word right   → space
    is needs_space(nt('Symbol','$@'), nt('Word','zap')), 1, 'sigil+wc → space';
    # left neither word nor sigil end → no space on all rules
    is needs_space(nt('Word','foo'), nt('Symbol','$x')), 0, 'wc + nonwc → none';
    is needs_space(nt('Word',';'),   nt('Word','zz')), 0, '; + wc → none';
    # rule 3: word-char left, quote right       → space
    is needs_space(nt('Word','foo'), nt('Quote::Double','"1"')), 1, 'wc+quote → space';
    # rule 4: quote left, word-char right       → space
    is needs_space(nt('Quote::Double','""'), nt('Word','bar')), 1, 'quote+wc → space';
    is needs_space(nt('Quote::Double','""'), nt('Symbol','$x')), 0, 'quote + nonwc → none';
    # rule 5: symbol+symbol                     → space
    is needs_space(nt('Symbol','$a'), nt('Symbol','$b')), 1, 'sym+sym → space';
    is needs_space(nt('Symbol','$a'), nt('Word','b')), 1, 'sym($a)+wc(b) → space (else $ab)';
    # rule 6: word-char left, quote char right  → space
    is needs_space(nt('Word','eq'), nt('Word','"x"')), 1, 'wc+quotechar → space';
    # rule 7: regexp left, word-char right      → space
    is needs_space(nt('Regexp','abc/'), nt('Word','bar')), 1, 'regexp+wc → space';
    is needs_space(nt('Regexp','abc/'), nt('Symbol','$x')), 0, 'regexp + nonwc → none';
    # rule 2's A-true/B-false: sigil-ending left, non-word right
    is needs_space(nt('Symbol','$@'), nt('Word',';')), 0, 'sigil + nonwc → none';
    # Cast rule: bare sigil ($, @, %) must not be glued to the token before it
    is needs_space(nt('Symbol','$fh'), nt('Cast','$')), 1, 'sym+cast($) → space (prevents $$merge)';
    is needs_space(nt('Symbol','$fh'), nt('Cast','@')), 1, 'sym+cast(@) → space (prevents @$merge)';
    is needs_space(nt('Cast','$'), nt('Symbol','$src')), 0, 'cast+sym → no double-space (cast-sym stays glued)';
}

# ── process: empty source short-circuits ──────────────────────────────────
{
    is process(''), '', 'empty source → empty output';
}

# ── process: my ($a, $b) list declaration ─────────────────────────────────
{
    my $src = 'sub pair { my ($left_arg, $right_arg) = @_; return [$left_arg, $right_arg] }';
    my $out = process($src);
    unlike $out, qr/\$left_arg/,  'list-declared variable renamed';
    unlike $out, qr/\$right_arg/, 'list-declared variable renamed';
}

# ── process: local declaration is NOT a rename candidate ─────────────────
# `local $x` may be the package global $PKG::x read via a qualified
# reference elsewhere, so we conservatively leave it untouched. Only
# `my` (a true file lexical) is renamed.
{
    my $src = 'local $signal = 0; print $signal;';
    my $out = process($src);
    like $out, qr/\$signal/, 'local variable left unrenamed (may be a global)';
}

# ── process: repeated same-name declaration only renamed once ─────────────
{
    my $src = 'my $counter_val = 1; { my $counter_val = 2 } print $counter_val;';
    my $out = process($src);
    unlike $out, qr/\$counter_val/, 'duplicate declaration renamed consistently';
}

# ── process: variables inside <> NOT renamed ──────────────────────────────
{
    my $src = q{my $fh = "x"; open my $fh2, '<', $fh; while (<$fh2>) { print }};
    my $out = process($src);
    # $fh2 appears in <$fh2> readline → must not be renamed
    like $out, qr/\$fh2/, '$fh2 preserved (in readline <>)';
}

# ── process: variables inside heredocs NOT renamed ────────────────────────
{
    my $src = "my \$name = \"world\"; print <<\"EOT\";\nHello \$name\nEOT\n";
    my $out = process($src);
    like $out, qr/\$name/, '$name preserved (in heredoc)';
}

# ── process: variables inside ${} interpolation NOT renamed ───────────────
{
    my $src = q{my $path = "Foo"; print "${path}::Plugin";};
    my $out = process($src);
    like $out, qr/\$path/, '$path preserved (in "${path}")';
}

# ── process: variable used ONLY in code IS renamed ────────────────────────
{
    my $src = q{my $counter = 0; $counter++; print $counter;};
    my $out = process($src);
    unlike $out, qr/\$counter/, '$counter renamed (code only)';
}

# ── process: variable used in code AND string — not renamed ───────────────
{
    my $src = q{my $widget = "hi"; print "val=$widget\n";};
    my $out = process($src);
    like $out, qr/\$widget/, '$widget preserved (used in string)';
}

# ── process: @array in string not renamed ─────────────────────────────────
{
    my $src = q{my @items = (1,2); print "@items";};
    my $out = process($src);
    like $out, qr/\@items/, '\@items preserved (in string)';
}

# ── process: %hash in string not renamed ──────────────────────────────────
{
    my $src = q{my %map = (a=>1); print "%map";};
    my $out = process($src);
    like $out, qr/\%map/, '\%map preserved (in string)';
}

# ── process: package-qualified globals NOT renamed ────────────────────────
# `$Archive::Tar::WARN` is a cross-package global; renaming it to $p
# inside the current file silently breaks Archive::Tar's own logic.
{
    my $src = 'local $Archive::Tar::WARN = 0; print $Archive::Tar::WARN;';
    my $out = process($src);
    like $out, qr/\$Archive::Tar::WARN/, 'package-qualified global not renamed';
    unlike $out, qr/\$[a-z]{1,2}\b(?![.:])/, 'no short replacement used for package global';
}

# ── process: bare local globals NOT renamed (my is) ──────────────────────
# `local $warn` creates/localises the package global $PKG::warn; a reader
# via `$A::warn` must still resolve. Renaming it breaks that silently.
# `my $warn` is a file lexical and IS safe to rename.
{
    my $src = "package A;\nlocal \$warn = \"hi\";\npackage main;\nprint \$A::warn, \"\\n\";\n1;\n";
    my $out = process($src);
    like $out, qr/\$warn/,        'bare local global NOT renamed';
    like $out, qr/\$A::warn/,     'qualified read kept in sync';

    # Runtime proof: original and minified print identical output.
    require File::Temp;
    my $run = sub {
        my ($fh, $f) = File::Temp::tempfile(SUFFIX => '.pl');
        print $fh $_[0]; close $fh or return "write-fail";
        my $got = `$^X $f 2>&1`; unlink $f; return $got;
    };
    is $run->($out), $run->($src), 'minified local global prints identically to original';

    my $my_src = "package A;\nmy \$warn = 1;\npackage main;\nprint \$warn;\n1;\n";
    my $my_out = process($my_src);
    unlike $my_out, qr/\$warn/, 'my package-lexical still renamed';
}

# ── process: no crash on empty source ─────────────────────────────────────
{
    my $out = process("1;\n");
    like $out, qr/1;/, 'minimal valid source processed';
}

# ── process: $#array index renamed consistently with @array ───────────────
{
    my $src = 'my @letters = (1,2); print $#letters;';
    my $out = process($src);
    unlike $out, qr/\$#letters/, '$#letters renamed (matches @letters rename)';
    like $out, qr/\$#[a-z]+/,    'short $#name assigned';
}

# ── process: multiple variables with correct renaming ─────────────────────
{
    my $src = 'my $alpha = 1; my $beta = 2; print $alpha + $beta;';
    my $out = process($src);
    unlike $out, qr/\$alpha/, '$alpha renamed';
    unlike $out, qr/\$beta/,  '$beta renamed';
    # Both should get distinct short names
    my ($a1) = $out =~ /(\$[a-z]+)/;
    my @all = $out =~ /(\$[a-z]+)/g;
    ok scalar(@all) >= 2, 'multiple variables renamed';
}

done_testing;