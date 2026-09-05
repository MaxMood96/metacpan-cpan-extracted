package App::SlimPacker;
use strict;
use warnings;
use PPI;
use Exporter 'import';
our $VERSION = '0.02';
our @EXPORT_OK = qw(process name_gen needs_space perl_switches plugin_search_paths inline_plugins module_deps);

sub needs_space {
    my ($l, $r) = @_;
    my $lc = $l->content; my $rc = $r->content;
    my $lr = ref($l);     my $rr = ref($r);
    return 1 if $lc =~ /\w$/ && $rc =~ /^\w/;
    return 1 if $lc =~ /[\$\@\%]$/ && $rc =~ /^\w/;
    return 1 if $lc =~ /\w$/ && $rr =~ /Quote/;
    return 1 if $lr =~ /Quote/ && $rc =~ /^\w/;
    return 1 if $lr =~ /Symbol/ && $rr =~ /Symbol/;
    # A bare Cast sigil (`$`, `@`, `%`) must not be glued to the token before
    # it: `print $fh $$source` -> `print$fh$$source` (or `$fh@$source`)
    # silently changes meaning / breaks parsing.
    return 1 if $rr =~ /Cast/;
    return 1 if $lc =~ /\w$/ && $rc =~ /^['"\/]/;
    return 1 if $lr =~ /Regexp/ && $rc =~ /^\w/;
    # `use Foo VERSION (LIST)` needs the space before the paren; dropping it
    # (e.g. `use Foo 5.57(qw/x/)`) is a Perl syntax error. The paren arrives as
    # a Structure whose content starts with '('.
    return 1 if $lr =~ /Number/ && $rc =~ /^\(/;
    return 0;
}

my @_chars = ('a'..'z');
sub name_gen {
    my ($n) = @_;
    my $out = '';
    $n++;
    while ($n > 0) { $out = $_chars[($n-1)%26] . $out; $n = int(($n-1)/26) }
    return $out;
}

my %KEEP = map { $_ => 1 } qw(
    _ a b 0 1 2 3 4 5 6 7 8 9
    ENV INC ISA ARGV ARGVOUT STDOUT STDERR STDIN
    VERSION AUTOLOAD self class
);

sub process {
    my ($src, %opts) = @_;
    my $rename_vars = $opts{rename} // 1;
    my $doc = PPI::Document->new(\$src) or return $src;
    $doc->prune('PPI::Token::Comment');
    $doc->prune('PPI::Token::Pod');

    return $doc->serialize unless $doc->children;

    my %rename;     # original name -> short name (global per file)
    my $counter = 0;

    if ($rename_vars) {
        my %in_string;

        # Pass 1a: collect variable names inside opaque tokens
        # These embed vars as text, not as PPI::Token::Symbol:
        #   Quote::Double/Interpolate  — "$var", "${var}"
        #   Regexp::Match/Substitute   — m/$var/, s/$old/$new/
        #   QuoteLike::Regexp/Readline/Backtick — qr/$var/, <$fh>, `$cmd`
        #   HereDoc                    — <<"EOF" with $var inside
        my $tok = $doc->first_token;
        while ($tok) {
            my $r = ref($tok);
            if ($r =~ /^PPI::Token::(?:Quote::(?:Interpolate|Double)|Regexp::(?:Match|Substitute)|QuoteLike::(?:Regexp|Readline|Backtick)|HereDoc)$/) {
                my $str = $tok->content;
                $str .= join('', $tok->heredoc) if $r eq 'PPI::Token::HereDoc' && $tok->can('heredoc');
                while ($str =~ /[\$\@]\{?(\w{2,})\b/g) { $in_string{$1} = 1 }
            }
            $tok = $tok->next_token;
        }

        # Pass 1b: collect rename candidates from my declarations only.
        # `local $x` declares a package global (even bare: it localises
        # $PKG::x), and `our $x` is likewise a package global; renaming a
        # global while any surviving $PKG::x reference reads it would break
        # cross-package semantics. `my $x` is a true file lexical, never
        # reachable as a package global, so it is always safe to rename.
        my @decl_names;
        $tok = $doc->first_token;
        while ($tok) {
            if (ref($tok) eq 'PPI::Token::Word' && $tok->content eq 'my') {
                my $next = $tok->snext_sibling or do { $tok = $tok->next_token; next };
                my @syms;
                if ($next->isa('PPI::Token::Symbol')) {
                    @syms = ($next);
                } elsif ($next->isa('PPI::Structure::List')) {
                    @syms = @{ $next->find('PPI::Token::Symbol') // [] };
                }
                for my $sym (@syms) {
                    my (undef, $name) = $sym->content =~ /^([\$\@\%])(.+)$/ or next;
                    # Never rename package globals ($Foo::Bar) or pseudo-vars;
                    # renaming them breaks cross-package semantics. (Bare
                    # `local`/`our` globals are now excluded at the `my`-only
                    # gate above; this guard defends the qualified form.)
                    next if $name =~ /::/;
                    next if length($name) <= 1 || $KEEP{$name}
                         || $name =~ /^[A-Z_]+$/ || $in_string{$name};
                    push @decl_names, $name unless $rename{$name};
                }
            }
            $tok = $tok->next_token;
        }

        # Pass 1c: reserve every symbol name that survives unrenamed,
        # so generated short names can never shadow or collide with them
        my %reserved;
        $tok = $doc->first_token;
        while ($tok) {
            if (ref($tok) eq 'PPI::Token::Symbol' || ref($tok) eq 'PPI::Token::ArrayIndex') {
                my (undef, $name) = $tok->content =~ /^((?:\$#|[\$\@\%]))(.+)$/;
                $reserved{$name} = 1 if defined $name && length $name;
            }
            $tok = $tok->next_token;
        }

        # Assign short names in declaration order
        for my $name (@decl_names) {
            next if exists $rename{$name};
            my $short;
            do { $short = name_gen($counter++) } while $KEEP{$short} || $reserved{$short};
            $rename{$name} = $short;
        }
    }

    # Pass 2: strip whitespace + optionally rename symbols
    my $tok = $doc->first_token;
    while ($tok) {
        my $ref = ref($tok);

        if ($ref eq 'PPI::Token::Whitespace') {
            my $prev = $tok->previous_sibling;
            my $next = $tok->next_sibling;
            $prev = $prev->previous_sibling while $prev && ref($prev) eq 'PPI::Token::Whitespace';
            $next = $next->next_sibling     while $next && ref($next) eq 'PPI::Token::Whitespace';
            $tok->set_content(($prev && $next && needs_space($prev, $next)) ? ' ' : '');
        } elsif ($rename_vars && ($ref eq 'PPI::Token::Symbol' || $ref eq 'PPI::Token::ArrayIndex')) {
            my ($sigil, $name) = $tok->content =~ /^((?:\$#|[\$\@\%]))(.+)$/ or do {
                $tok = $tok->next_token; next;
            };
            if (exists $rename{$name}) {
                $tok->set_content($sigil . $rename{$name});
            }
        }

        $tok = $tok->next_token;
    }

    return $doc->serialize;
}

# Build a perl program from -m/-M/-e/-E switch arguments, perl-binary style.
#   perl_switches(\@m, \@M, \@e, \@E) -> program text
#   -m Foo          -> use Foo ();
#   -M Foo          -> use Foo;
#   -M Foo=bar,baz  -> use Foo qw(bar baz);
#   -M Foo=5.010    -> use Foo 5.010;
#   -M 5.010        -> use 5.010;
#   -E CODE         -> use feature qw(:all); CODE
sub perl_switches {
    my ($m, $M, $e, $E) = @_;
    $_ ||= [] for ($m, $M, $e, $E);
    my @out;
    for my $arg (@$m) { push @out, _use_line($arg, 0) }
    for my $arg (@$M) { push @out, _use_line($arg, 1) }
    if (@$E) { push @out, 'use feature qw(:all);' }
    if (@$e || @$E) { push @out, join("\n", @$e, @$E) }
    return join("\n", @out) . "\n";
}

sub _use_line {
    my ($arg, $with_imports) = @_;
    my ($mod, $terms) = $arg =~ /^([^=\s]+)(?:=(.*))?$/;
    die "bad -m/-M argument: '$arg'\n" unless defined $mod;
    $terms = '' unless defined $terms;
    return "use $mod ();" unless $with_imports;
    return "use $mod;" unless length $terms;
    my @t = split /,/, $terms;
    if (@t == 1 && $t[0] =~ /^(?:\d[\d.]*|v[\d.]+)$/) {
        return "use $mod $t[0];";
    }
    return "use $mod qw(@t);";
}

# Extract the Module::Pluggable search_path(s) from a program's
# 'use Module::Pluggable (...)' statement. Returns a hashref of namespace => 1.
sub plugin_search_paths {
    my ($program) = @_;
    my %searched;
    if ($program =~ m{\buse\s+Module::Pluggable\s*\((.*?)\)\s*;}s) {
        my $args = $1;
        while ($args =~ m~search_path\s*=>\s*(?:(\[[^\]]*\])|("[^"]*")|('[^']*')|(q\{[^}]*\}|q\([^)]*\)|q\[[^\]]*\]|q<[^>]*>))~g) {
            my ($array, $double, $single, $q) = ($1, $2, $3, $4);
            my $spec = defined $array ? $array : defined $double ? $double
                     : defined $single ? $single : $q;
            if (defined $array) {
                $searched{$_} = 1 for _quoted_values($array);
            } else {
                my ($v) = _quoted_values($spec);
                $searched{$v} = 1 if defined $v;
            }
        }
    }
    return \%searched;
}

# Pull the string contents out of any common Perl quote form.
sub _quoted_values {
    my ($s) = @_;
    my @v;
    while ($s =~ m~(?:'([^']*)'|"([^"]*)"|q\{([^}]*)\}|q\(([^)]*)\)|q\[([^\]]*)\]|q<([^>]*)>)~g) {
        my @m = grep { defined } ($1, $2, $3, $4, $5, $6);
        push @v, $m[0];
    }
    return @v;
}

# Extract the statically-declared module dependencies from Perl source.
# Returns a list of module names found via `use`, `require`, `use base`,
# `use parent`, and string-form `require "Foo/Bar.pm"`.  Pragmas (strict,
# warnings, lib, etc.) are skipped.
sub module_deps {
    my ($src) = @_;
    my $doc = PPI::Document->new(\$src) // die "PPI parse failed";
    my @deps;
    my $incs = $doc->find('PPI::Statement::Include') || [];
    for my $i (@$incs) {
        my $type = $i->type;
        next unless defined $type && ($type eq 'use' || $type eq 'require');
        my $mod = $i->module;
        if (defined $mod && length $mod) {
            if ($mod eq 'parent' || $mod eq 'base') {
                for my $tok ($i->arguments) {
                    if ($tok->isa('PPI::Token::QuoteLike::Words')) {
                        push @deps, $tok->literal;
                    } elsif ($tok->isa('PPI::Token::Quote')) {
                        my $str = $tok->string;
                        push @deps, $str if defined $str && length $str;
                    }
                }
                next;
            }
            next if $i->pragma;
            push @deps, $mod;
        } elsif ($type eq 'require') {
            for my $tok ($i->schildren) {
                next unless $tok->isa('PPI::Token::Quote')
                         || $tok->isa('PPI::Token::HereDoc');
                my $str = $tok->string // next;
                next unless $str =~ s{\.pm$}{};
                $str =~ s{/}{::}g;
                push @deps, $str if length $str && $str !~ /[\$\@\%\$\{]/;
            }
        }
    }
    return @deps;
}

# Inline a plugin class list into plugins() based on the Module::Pluggable
# search_path(s) in $program and the available $classes (Class::Name => 1).
# Classes are matched one level deep (Module::Pluggable's default), sorted.
# The 'use Module::Pluggable' statement is removed so it never loads. Programs
# without Module::Pluggable (or without a search_path) are returned unchanged.
sub inline_plugins {
    my ($program, $classes) = @_;
    $classes ||= {};
    my $searched = plugin_search_paths($program);
    return $program unless %$searched;

    my @plugins;
    for my $ns (sort keys %$searched) {
        for my $cp (sort grep { m{^\Q$ns\E::[^:]+$} } keys %$classes) {
            push @plugins, $cp;
        }
    }

my $list = join(',', map { "\"$_\"" } @plugins);
    my $requires = join '', map {
        (my $path = $_) =~ s{::}{/}g; $path .= '.pm'; "require \"$path\";"
    } @plugins;
    $program =~ s{\buse\s+Module::Pluggable\s*\(.*?\)\s*;}{$requires}gs;
    $program =~ s{plugins\(\)}{($list)}gs;
    return $program;
}

1;

=head1 NAME

App::SlimPacker - PPI-based minifier and fatpack-style bundler for standalone Perl scripts

=head1 VERSION

Version 0.02

=head1 SYNOPSIS

    use App::SlimPacker qw(process module_deps inline_plugins);

    # Minify Perl source (strip comments/POD, collapse whitespace, rename vars)
    my $minified = process($source, rename => 1);

    # Extract static dependencies from source
    my @deps = module_deps('use App::Foo; require App::Bar;');

    # Inline Module::Pluggable plugin list
    my $boot = inline_plugins($program, \%classes);

=head1 DESCRIPTION

App::SlimPacker provides a PPI-based minifier and bundling helpers for building
standalone Perl scripts.  It is used by the C<slimpack> CLI to assemble
fatpacked, minified executables.

The minifier (C<process>) strips comments and POD, collapses whitespace, and
optionally renames C<my> variables to short names while respecting
string interpolation, regexes, heredocs, and readlines. C<local>/C<our>
declarations are left untouched because they may be package globals reachable
by a fully-qualified C<$PKG::name> reference elsewhere.

The bundling helpers resolve static dependencies, inline Module::Pluggable
plugin lists, and build perl-style switch programs from C<-m>/C<-M>/C<-e>/C<-E>
arguments.

Unlike C<fatpack>, which copies bundled modules verbatim, the C<slimpack>
pipeline runs every module through the PPI minifier.  Packing this C<Moo>
hello-world into a self-contained script:

    package MyGreeter;
    use Moo;
    has name => (is => 'ro', default => sub { 'world' });
    sub greet { my $self = shift; return "Hello, " . $self->name . "!\n"; }
    package main;
    print MyGreeter->new->greet;

with Moo on the module path:

    fatpack pack helloworld.pl > helloworld.fatpack.pl
    slimpack -o helloworld.slimpack.pl helloworld.pl

C<fatpack> produced 294 KB across 9,929 lines, C<slimpack> 59 KB across 27
lines; both print C<Hello, world!> with no C<Moo> and no C<PERL5LIB> at run
time.  Sizes vary with the module set.

=head1 EXPORTS

Nothing is exported by default.  All functions are available for import:

    use App::SlimPacker qw(process module_deps);

=head1 FUNCTIONS

=head2 process($source, %options)

Minifies Perl source code using PPI.  Returns the minified string.

Options:

=over 4

=item rename => 0|1

Rename C<my> variables to short names (C<a>, C<b>, ... C<aa>, ...).
Enabled by default.  Set to C<0> to keep variable names intact (useful for
C<fatlib> core modules).

=back

Variable renaming skips names used inside strings, regexes, heredocs, readlines,
backticks, C<%KEEP> names, ALL_CAPS names, and single-character names.

=head2 module_deps($source)

Returns a list of module names statically declared as dependencies in the given
Perl source.  Extracts modules from C<use>, C<require>, C<use base>,
C<use parent>, and string-form C<require "Foo/Bar.pm">.  Pragmas (C<strict>,
C<warnings>, C<lib>, etc.) are skipped.

=head2 plugin_search_paths($program)

Extracts C<Module::Pluggable> search paths from a program's
C<use Module::Pluggable (...)> statement.  Returns a hashref of
C<< namespace => 1 >>.

=head2 inline_plugins($program, \%classes)

Inlines a plugin class list into C<plugins()> calls based on the
C<Module::Pluggable> search paths in C<$program> and the available classes
(hashref of C<< Class::Name => 1 >>).  Classes are matched one level deep
(Module::Pluggable's default), sorted.  The C<use Module::Pluggable> statement
is removed so it never loads at runtime.

Returns the modified program text.  Programs without C<Module::Pluggable> or
without a C<search_path> are returned unchanged.

=head2 perl_switches(\@m, \@M, \@e, \@E)

Builds a Perl program string from C<-m>/C<-M>/C<-e>/C<-E> switch arguments
(perl-binary style).  Returns the program text with appropriate C<use>
statements prepended.

=head2 name_gen($n)

Returns a short variable name for the index C<$n>: C<0> -> C<a>, C<1> -> C<b>,
C<25> -> C<z>, C<26> -> C<aa>, etc.

=head2 needs_space($left_token, $right_token)

Returns 1 if a space is needed between two PPI tokens to prevent them from
merging into a single token, 0 otherwise.

=head1 AUTHOR

Nicolas Mendoza, C<< <mendoza at pvv.ntnu.no> >>

=head1 LICENSE AND COPYRIGHT

This software is licensed under the Artistic License 2.0.  See the F<LICENSE>
file in this distribution for the full text.

=head1 SEE ALSO

L<slimpack>, L<PPI>, L<App::FatPacker>

=cut