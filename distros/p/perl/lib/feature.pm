# -*- mode: Perl; buffer-read-only: t -*-
# !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
# This file is built by regen/feature.pl.
# Any changes made here will be lost!

package feature;
our $VERSION = '1.97';

our %feature = (
    fc                              => 'feature_fc',
    isa                             => 'feature_isa',
    say                             => 'feature_say',
    try                             => 'feature_try',
    class                           => 'feature_class',
    defer                           => 'feature_defer',
    state                           => 'feature_state',
    switch                          => 'feature_switch',
    bitwise                         => 'feature_bitwise',
    indirect                        => 'feature_indirect',
    evalbytes                       => 'feature_evalbytes',
    signatures                      => 'feature_signatures',
    smartmatch                      => 'feature_smartmatch',
    current_sub                     => 'feature___SUB__',
    keyword_all                     => 'feature_keyword_all',
    keyword_any                     => 'feature_keyword_any',
    module_true                     => 'feature_module_true',
    refaliasing                     => 'feature_refaliasing',
    postderef_qq                    => 'feature_postderef_qq',
    unicode_eval                    => 'feature_unieval',
    declared_refs                   => 'feature_myref',
    unicode_strings                 => 'feature_unicode',
    multidimensional                => 'feature_multidimensional',
    bareword_filehandles            => 'feature_bareword_filehandles',
    extra_paired_delimiters         => 'feature_more_delims',
    apostrophe_as_package_separator => 'feature_apos_as_name_sep',
);

our %feature_bundle = (
    "5.10"    => [qw(apostrophe_as_package_separator bareword_filehandles indirect multidimensional say smartmatch state switch)],
    "5.11"    => [qw(apostrophe_as_package_separator bareword_filehandles indirect multidimensional say smartmatch state switch unicode_strings)],
    "5.15"    => [qw(apostrophe_as_package_separator bareword_filehandles current_sub evalbytes fc indirect multidimensional say smartmatch state switch unicode_eval unicode_strings)],
    "5.23"    => [qw(apostrophe_as_package_separator bareword_filehandles current_sub evalbytes fc indirect multidimensional postderef_qq say smartmatch state switch unicode_eval unicode_strings)],
    "5.27"    => [qw(apostrophe_as_package_separator bareword_filehandles bitwise current_sub evalbytes fc indirect multidimensional postderef_qq say smartmatch state switch unicode_eval unicode_strings)],
    "5.35"    => [qw(apostrophe_as_package_separator bareword_filehandles bitwise current_sub evalbytes fc isa postderef_qq say signatures smartmatch state unicode_eval unicode_strings)],
    "5.37"    => [qw(apostrophe_as_package_separator bitwise current_sub evalbytes fc isa module_true postderef_qq say signatures smartmatch state unicode_eval unicode_strings)],
    "5.39"    => [qw(apostrophe_as_package_separator bitwise current_sub evalbytes fc isa module_true postderef_qq say signatures smartmatch state try unicode_eval unicode_strings)],
    "5.41"    => [qw(bitwise current_sub evalbytes fc isa module_true postderef_qq say signatures state try unicode_eval unicode_strings)],
    "all"     => [qw(apostrophe_as_package_separator bareword_filehandles bitwise class current_sub declared_refs defer evalbytes extra_paired_delimiters fc indirect isa keyword_all keyword_any module_true multidimensional postderef_qq refaliasing say signatures smartmatch state switch try unicode_eval unicode_strings)],
    "default" => [qw(apostrophe_as_package_separator bareword_filehandles indirect multidimensional smartmatch)],
);

$feature_bundle{"5.12"} = $feature_bundle{"5.11"};
$feature_bundle{"5.13"} = $feature_bundle{"5.11"};
$feature_bundle{"5.14"} = $feature_bundle{"5.11"};
$feature_bundle{"5.16"} = $feature_bundle{"5.15"};
$feature_bundle{"5.17"} = $feature_bundle{"5.15"};
$feature_bundle{"5.18"} = $feature_bundle{"5.15"};
$feature_bundle{"5.19"} = $feature_bundle{"5.15"};
$feature_bundle{"5.20"} = $feature_bundle{"5.15"};
$feature_bundle{"5.21"} = $feature_bundle{"5.15"};
$feature_bundle{"5.22"} = $feature_bundle{"5.15"};
$feature_bundle{"5.24"} = $feature_bundle{"5.23"};
$feature_bundle{"5.25"} = $feature_bundle{"5.23"};
$feature_bundle{"5.26"} = $feature_bundle{"5.23"};
$feature_bundle{"5.28"} = $feature_bundle{"5.27"};
$feature_bundle{"5.29"} = $feature_bundle{"5.27"};
$feature_bundle{"5.30"} = $feature_bundle{"5.27"};
$feature_bundle{"5.31"} = $feature_bundle{"5.27"};
$feature_bundle{"5.32"} = $feature_bundle{"5.27"};
$feature_bundle{"5.33"} = $feature_bundle{"5.27"};
$feature_bundle{"5.34"} = $feature_bundle{"5.27"};
$feature_bundle{"5.36"} = $feature_bundle{"5.35"};
$feature_bundle{"5.38"} = $feature_bundle{"5.37"};
$feature_bundle{"5.40"} = $feature_bundle{"5.39"};
$feature_bundle{"5.42"} = $feature_bundle{"5.41"};
$feature_bundle{"5.9.5"} = $feature_bundle{"5.10"};
my %noops = (
    postderef => 1,
    lexical_subs => 1,
);
my %removed = (
    array_base => 1,
);

our $hint_shift   = 26;
our $hint_mask    = 0x3c000000;
our @hint_bundles = qw( default 5.10 5.11 5.15 5.23 5.27 5.35 5.37 5.39 5.41 );

# This gets set (for now) in $^H as well as in %^H,
# for runtime speed of the uc/lc/ucfirst/lcfirst functions.
# See HINT_UNI_8_BIT in perl.h.
our $hint_uni8bit = 0x00000800;

# TODO:
# - think about versioned features (use feature switch => 2)

=encoding utf8

=head1 NAME

feature - Perl pragma to enable new features

=head1 SYNOPSIS

    use feature qw(fc say);

    # Without the "use feature" above, this code would not be able to find
    # the built-ins "say" or "fc":
    say "The case-folded version of $x is: " . fc $x;


    # set features to match the :5.36 bundle, which may turn off or on
    # multiple features (see "FEATURE BUNDLES" below)
    use feature ':5.36';


    # implicitly loads :5.36 feature bundle
    use v5.36;

=head1 DESCRIPTION

It is usually impossible to add new syntax to Perl without breaking
some existing programs.  This pragma provides a way to minimize that
risk. New syntactic constructs, or new semantic meanings to older
constructs, can be enabled by C<use feature 'foo'>, and will be parsed
only when the appropriate feature pragma is in scope.  (Nevertheless, the
C<CORE::> prefix provides access to all Perl keywords, regardless of this
pragma.)

=head2 Lexical effect

Like other pragmas (C<use strict>, for example), features have a lexical
effect.  C<use feature qw(foo)> will only make the feature "foo" available
from that point to the end of the enclosing block.

    {
        use feature 'say';
        say "say is available here";
    }
    print "But not here.\n";

=head2 C<no feature>

Features can also be turned off by using C<no feature "foo">.  This too
has lexical effect.

    use feature 'say';
    say "say is available here";
    {
        no feature 'say';
        print "But not here.\n";
    }
    say "Yet it is here.";

C<no feature> with no features specified will reset to the default group.  To
disable I<all> features (an unusual request!) use C<no feature ':all'>.

=head1 AVAILABLE FEATURES

Read L</"FEATURE BUNDLES"> for the feature cheat sheet summary.

=head2 The 'say' feature

C<use feature 'say'> tells the compiler to enable the Raku-inspired
C<say> function.

See L<perlfunc/say> for details.

This feature is available starting with Perl 5.10.

=head2 The 'state' feature

C<use feature 'state'> tells the compiler to enable C<state>
variables.

See L<perlsub/"Persistent Private Variables"> for details.

This feature is available starting with Perl 5.10.

=head2 The 'smartmatch' feature

C<use feature 'smartmatch'> tells the compiler to enable the
smartmatch operator C<~~>.  It is enabled by default, but can be
turned off to disallow the C<~~> operator.

This feature is disabled by default in the 5.42 feature bundle
onwards:

  $x ~~ $y; # fine
  use v5.42;
  $x ~~ $y; # error

This has no effect on the implicit smartmatches done by C<when>.

See L<perlop/"Smartmatch Operator"> for details.

=head2 The 'switch' feature

C<use feature 'switch'> tells the compiler to enable the Raku
given/when construct.

See L<perlsyn/"Switch Statements"> for details.

This feature is available starting with Perl 5.10.  It is enabled by
feature bundles 5.10 through 5.34, and disabled from the 5.36 feature
bundle onwards.

=head2 The 'unicode_strings' feature

C<use feature 'unicode_strings'> tells the compiler to use Unicode rules
in all string operations executed within its scope (unless they are also
within the scope of either C<use locale> or C<use bytes>).  The same applies
to all regular expressions compiled within the scope, even if executed outside
it.  It does not change the internal representation of strings, but only how
they are interpreted.

C<no feature 'unicode_strings'> tells the compiler to use the traditional
Perl rules wherein the native character set rules is used unless it is
clear to Perl that Unicode is desired.  This can lead to some surprises
when the behavior suddenly changes.  (See
L<perlunicode/The "Unicode Bug"> for details.)  For this reason, if you are
potentially using Unicode in your program, the
C<use feature 'unicode_strings'> subpragma is B<strongly> recommended.

This feature is available starting with Perl 5.12; was almost fully
implemented in Perl 5.14; and extended in Perl 5.16 to cover C<quotemeta>;
was extended further in Perl 5.26 to cover L<the range
operator|perlop/Range Operators>; and was extended again in Perl 5.28 to
cover L<special-cased whitespace splitting|perlfunc/split>.

=head2 The 'unicode_eval' and 'evalbytes' features

Together, these two features are intended to replace the legacy string
C<eval> function, which behaves problematically in some instances.  They are
available starting with Perl 5.16, and are enabled by default by a
S<C<use 5.16>> or higher declaration.

C<unicode_eval> changes the behavior of plain string C<eval> to work more
consistently, especially in the Unicode world.  Certain (mis)behaviors
couldn't be changed without breaking some things that had come to rely on
them, so the feature can be enabled and disabled.  Details are at
L<perlfunc/Under the "unicode_eval" feature>.

C<evalbytes> is like string C<eval>, but it treats its argument as a byte
string. Details are at L<perlfunc/evalbytes EXPR>.  Without a
S<C<use feature 'evalbytes'>> nor a S<C<use v5.16>> (or higher) declaration in
the current scope, you can still access it by instead writing
C<CORE::evalbytes>.

=head2 The 'current_sub' feature

This provides the C<__SUB__> token that returns a reference to the current
subroutine or C<undef> outside of a subroutine.

This feature is available starting with Perl 5.16.

=head2 The 'array_base' feature

This feature supported the legacy C<$[> variable.  See L<perlvar/$[>.
It was on by default but disabled under C<use v5.16> (see
L</IMPLICIT LOADING>, below) and unavailable since perl 5.30.

This feature is available under this name starting with Perl 5.16.  In
previous versions, it was simply on all the time, and this pragma knew
nothing about it.

=head2 The 'fc' feature

C<use feature 'fc'> tells the compiler to enable the C<fc> function,
which implements Unicode casefolding.

See L<perlfunc/fc> for details.

This feature is available from Perl 5.16 onwards.

=head2 The 'lexical_subs' feature

In Perl versions prior to 5.26, this feature enabled
declaration of subroutines via C<my sub foo>, C<state sub foo>
and C<our sub foo> syntax.  See L<perlsub/Lexical Subroutines> for details.

This feature is available from Perl 5.18 onwards.  From Perl 5.18 to 5.24,
it was classed as experimental, and Perl emitted a warning for its
usage, except when explicitly disabled:

  no warnings "experimental::lexical_subs";

As of Perl 5.26, use of this feature no longer triggers a warning, though
the C<experimental::lexical_subs> warning category still exists (for
compatibility with code that disables it).  In addition, this syntax is
not only no longer experimental, but it is enabled for all Perl code,
regardless of what feature declarations are in scope.

=head2 The 'postderef' and 'postderef_qq' features

The 'postderef_qq' feature extends the applicability of L<postfix
dereference syntax|perlref/Postfix Dereference Syntax> so that
postfix array dereference, postfix scalar dereference, and
postfix array highest index access are available in double-quotish interpolations.
For example, it makes the following two statements equivalent:

  my $s = "[@{ $h->{a} }]";
  my $s = "[$h->{a}->@*]";

This feature is available from Perl 5.20 onwards. In Perl 5.20 and 5.22, it
was classed as experimental, and Perl emitted a warning for its
usage, except when explicitly disabled:

  no warnings "experimental::postderef";

As of Perl 5.24, use of this feature no longer triggers a warning, though
the C<experimental::postderef> warning category still exists (for
compatibility with code that disables it).

The 'postderef' feature was used in Perl 5.20 and Perl 5.22 to enable
postfix dereference syntax outside double-quotish interpolations. In those
versions, using it triggered the C<experimental::postderef> warning in the
same way as the 'postderef_qq' feature did. As of Perl 5.24, this syntax is
not only no longer experimental, but it is enabled for all Perl code,
regardless of what feature declarations are in scope.

=head2 The 'signatures' feature

This enables syntax for declaring subroutine arguments as lexical variables.
For example, for this subroutine:

    sub foo ($left, $right) {
        return $left + $right;
    }

Calling C<foo(3, 7)> will assign C<3> into C<$left> and C<7> into C<$right>.

See L<perlsub/Signatures> for details.

This feature is available from Perl 5.20 onwards. From Perl 5.20 to 5.34,
it was classed as experimental, and Perl emitted a warning for its usage,
except when explicitly disabled:

  no warnings "experimental::signatures";

As of Perl 5.36, use of this feature no longer triggers a warning, though the
C<experimental::signatures> warning category still exists (for compatibility
with code that disables it). This feature is now considered stable, and is
enabled automatically by C<use v5.36> (or higher).

=head2 The 'refaliasing' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::refaliasing";

This enables aliasing via assignment to references:

    \$a = \$b; # $a and $b now point to the same scalar
    \@a = \@b; #                     to the same array
    \%a = \%b;
    \&a = \&b;
    foreach \%hash (@array_of_hash_refs) {
        ...
    }

See L<perlref/Assigning to References> for details.

This feature is available from Perl 5.22 onwards.

=head2 The 'bitwise' feature

This makes the four standard bitwise operators (C<& | ^ ~>) treat their
operands consistently as numbers, and introduces four new dotted operators
(C<&. |. ^. ~.>) that treat their operands consistently as strings.  The
same applies to the assignment variants (C<&= |= ^= &.= |.= ^.=>).

See L<perlop/Bitwise String Operators> for details.

This feature is available from Perl 5.22 onwards.  Starting in Perl 5.28,
C<use v5.28> will enable the feature.  Before 5.28, it was still
experimental and would emit a warning in the "experimental::bitwise"
category.

=head2 The 'declared_refs' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::declared_refs";

This allows a reference to a variable to be declared with C<my>, C<state>,
or C<our>, or localized with C<local>.  It is intended mainly for use in
conjunction with the "refaliasing" feature.  See L<perlref/Declaring a
Reference to a Variable> for examples.

This feature is available from Perl 5.26 onwards.

=head2 The 'isa' feature

This allows the use of the C<isa> infix operator, which tests whether the
scalar given by the left operand is an object of the class given by the
right operand. See L<perlop/Class Instance Operator> for more details.

This feature is available from Perl 5.32 onwards.  From Perl 5.32 to 5.34,
it was classed as experimental, and Perl emitted a warning for its usage,
except when explicitly disabled:

    no warnings "experimental::isa";

As of Perl 5.36, use of this feature no longer triggers a warning (though the
C<experimental::isa> warning category still exists for compatibility with
code that disables it). This feature is now considered stable, and is enabled
automatically by C<use v5.36> (or higher).

=head2 The 'indirect' feature

This feature allows the use of L<indirect object
syntax|perlobj/Indirect Object Syntax> for method calls, e.g.  C<new
Foo 1, 2;>. It is enabled by default, but can be turned off to
disallow indirect object syntax.

This feature is available under this name from Perl 5.32 onwards. In
previous versions, it was simply on all the time.  To disallow (or
warn on) indirect object syntax on older Perls, see the L<indirect>
CPAN module.  It is disabled from the 5.36 feature bundle onwards.

=head2 The 'multidimensional' feature

This feature enables multidimensional array emulation, a perl 4 (or
earlier) feature that was used to emulate multidimensional arrays with
hashes.  This works by converting code like C<< $foo{$x, $y} >> into
C<< $foo{join($;, $x, $y)} >>.  It is enabled by default, but can be
turned off to disable multidimensional array emulation.

When this feature is disabled the syntax that is normally replaced
will report a compilation error.

This feature is available under this name from Perl 5.34 onwards. In
previous versions, it was simply on all the time.  It is disabled from
the 5.36 feature bundle onwards.

You can use the L<multidimensional> module on CPAN to disable
multidimensional array emulation for older versions of Perl.

=head2 The 'bareword_filehandles' feature

This feature enables bareword filehandles for builtin functions
operations, a generally discouraged practice.  It is enabled by
default, but can be turned off to disable bareword filehandles, except
for the exceptions listed below.

The perl built-in filehandles C<STDIN>, C<STDOUT>, C<STDERR>, C<DATA>,
C<ARGV>, C<ARGVOUT> and the special C<_> are always enabled.

This feature is available under this name from Perl 5.34 onwards.  In
previous versions it was simply on all the time.  It is disabled from
the 5.38 feature bundle onwards.

You can use the L<bareword::filehandles> module on CPAN to disable
bareword filehandles for older versions of perl.

=head2 The 'try' feature

B<WARNING>: This feature is still partly experimental, and the implementation
may change or be removed in future versions of Perl.

This feature enables the C<try> and C<catch> syntax, which allows exception
handling, where exceptions thrown from the body of the block introduced with
C<try> are caught by executing the body of the C<catch> block.

This feature is available starting in Perl 5.34. Before Perl 5.40 it was
classed as experimental, and Perl emitted a warning for its usage, except when
explicitly disabled:

    no warnings "experimental::try";

As of Perl 5.40, use of this feature without a C<finally> block no longer
triggers a warning.  The optional C<finally> block is still considered
experimental and emits a warning, except when explicitly disabled as above.

For more information, see L<perlsyn/"Try Catch Exception Handling">.

=head2 The 'defer' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::defer";

This feature enables the C<defer> block syntax, which allows a block of code
to be deferred until when the flow of control leaves the block which contained
it. For more details, see L<perlsyn/defer>.

This feature is available starting in Perl 5.36.

=head2 The 'extra_paired_delimiters' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::extra_paired_delimiters";

This feature enables the use of more paired string delimiters than the
traditional four, S<C<< <  > >>>, S<C<( )>>, S<C<{ }>>, and S<C<[ ]>>.  When
this feature is on, for example, you can say S<C<qrE<171>patE<187>>>.

As with any usage of non-ASCII delimiters in a UTF-8-encoded source file, you
will want to ensure the parser will decode the source code from UTF-8 bytes
with a declaration such as C<use utf8>.

This feature is available starting in Perl 5.36.

For a full list of the available characters, see
L<perlop/List of Extra Paired Delimiters>.

=head2 The 'module_true' feature

This feature removes the need to return a true value at the end of a module
loaded with C<require> or C<use>. Any errors during compilation will cause
failures, but reaching the end of the module when this feature is in effect
will prevent C<perl> from throwing an exception that the module "did not return
a true value".

=head2 The 'class' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::class";

This feature enables the C<class> block syntax and other associated keywords
which implement the "new" object system, previously codenamed "Corinna".

=head2 The 'apostrophe_as_package_separator' feature

This feature enables use C<'> (apostrophe) as an alternative to using
C<::> as a separate in package and other global names.

This is enabled by default, but disabled from the 5.42 feature bundle
onwards.  In previous versions it was enabled all the time.

This only disables C<'> in symbols in your source code, the internal
conversion from C<'> to C<::>, including for symbolic references, is
always enabled.

=head2 The 'keyword_any' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::keyword_any";

This feature enables the L<C<any>|perlfunc/any BLOCK LIST> operator keyword.
This allow testing whether any of the values in a list satisfy a given
condition, with short-circuiting behaviour as soon as it finds one.

=head2 The 'keyword_all' feature

B<WARNING>: This feature is still experimental and the implementation may
change or be removed in future versions of Perl.  For this reason, Perl will
warn when you use the feature, unless you have explicitly disabled the warning:

    no warnings "experimental::keyword_all";

This feature enables the L<C<all>|perlfunc/all BLOCK LIST> operator keyword.
This allow testing whether all of the values in a list satisfy a given
condition, with short-circuiting behaviour as soon as it finds one that does
not.

=head1 FEATURE BUNDLES

It's possible to load multiple features together, using
a I<feature bundle>.  The name of a feature bundle is prefixed with
a colon, to distinguish it from an actual feature.

  use feature ":5.10";

The following feature bundles are available:

  bundle    features included
  --------- -----------------
  :default  indirect multidimensional
            bareword_filehandles
            apostrophe_as_package_separator smartmatch

  :5.10     apostrophe_as_package_separator
            bareword_filehandles indirect
            multidimensional say smartmatch state switch

  :5.12     apostrophe_as_package_separator
            bareword_filehandles indirect
            multidimensional say smartmatch state switch
            unicode_strings

  :5.14     apostrophe_as_package_separator
            bareword_filehandles indirect
            multidimensional say smartmatch state switch
            unicode_strings

  :5.16     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional say smartmatch
            state switch unicode_eval unicode_strings

  :5.18     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional say smartmatch
            state switch unicode_eval unicode_strings

  :5.20     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional say smartmatch
            state switch unicode_eval unicode_strings

  :5.22     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional say smartmatch
            state switch unicode_eval unicode_strings

  :5.24     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional postderef_qq
            say smartmatch state switch unicode_eval
            unicode_strings

  :5.26     apostrophe_as_package_separator
            bareword_filehandles current_sub evalbytes
            fc indirect multidimensional postderef_qq
            say smartmatch state switch unicode_eval
            unicode_strings

  :5.28     apostrophe_as_package_separator
            bareword_filehandles bitwise current_sub
            evalbytes fc indirect multidimensional
            postderef_qq say smartmatch state switch
            unicode_eval unicode_strings

  :5.30     apostrophe_as_package_separator
            bareword_filehandles bitwise current_sub
            evalbytes fc indirect multidimensional
            postderef_qq say smartmatch state switch
            unicode_eval unicode_strings

  :5.32     apostrophe_as_package_separator
            bareword_filehandles bitwise current_sub
            evalbytes fc indirect multidimensional
            postderef_qq say smartmatch state switch
            unicode_eval unicode_strings

  :5.34     apostrophe_as_package_separator
            bareword_filehandles bitwise current_sub
            evalbytes fc indirect multidimensional
            postderef_qq say smartmatch state switch
            unicode_eval unicode_strings

  :5.36     apostrophe_as_package_separator
            bareword_filehandles bitwise current_sub
            evalbytes fc isa postderef_qq say signatures
            smartmatch state unicode_eval
            unicode_strings

  :5.38     apostrophe_as_package_separator bitwise
            current_sub evalbytes fc isa module_true
            postderef_qq say signatures smartmatch state
            unicode_eval unicode_strings

  :5.40     apostrophe_as_package_separator bitwise
            current_sub evalbytes fc isa module_true
            postderef_qq say signatures smartmatch state
            try unicode_eval unicode_strings

  :5.42     bitwise current_sub evalbytes fc isa
            module_true postderef_qq say signatures
            state try unicode_eval unicode_strings

The C<:default> bundle represents the feature set that is enabled before
any C<use feature> or C<no feature> declaration.

Specifying sub-versions such as the C<0> in C<5.14.0> in feature bundles has
no effect.  Feature bundles are guaranteed to be the same for all sub-versions.

  use feature ":5.14.0";    # same as ":5.14"
  use feature ":5.14.1";    # same as ":5.14"

You can also do:

  use feature ":all";

or

  no feature ":all";

but the first may enable features in a later version of Perl that
change the meaning of your code, and the second may disable mechanisms
that are part of Perl's current behavior that have been turned into
features, just as C<indirect> and C<bareword_filehandles> were.

=head1 IMPLICIT LOADING

Instead of loading feature bundles by name, it is easier to let Perl do
implicit loading of a feature bundle for you.

There are two ways to load the C<feature> pragma implicitly:

=over 4

=item *

By using the C<-E> switch on the Perl command-line instead of C<-e>.
That will enable the feature bundle for that version of Perl in the
main compilation unit (that is, the one-liner that follows C<-E>).

=item *

By explicitly requiring a minimum Perl version number for your program, with
the C<use VERSION> construct.  That is,

    use v5.36.0;

will do an implicit

    no feature ':all';
    use feature ':5.36';

and so on.  Note how the trailing sub-version
is automatically stripped from the
version.

But to avoid portability warnings (see L<perlfunc/use>), you may prefer:

    use 5.036;

with the same effect.

If the required version is older than Perl 5.10, the ":default" feature
bundle is automatically loaded instead.

Unlike C<use feature ":5.12">, saying C<use v5.12> (or any higher version)
also does the equivalent of C<use strict>; see L<perlfunc/use> for details.

=back

=head1 CHECKING FEATURES

C<feature> provides some simple APIs to check which features are enabled.

These functions cannot be imported and must be called by their fully
qualified names.  If you don't otherwise need to set a feature you will
need to ensure C<feature> is loaded with:

  use feature ();

=over

=item feature_enabled($feature)

=item feature_enabled($feature, $depth)

  package MyStandardEnforcer;
  use feature ();
  use Carp "croak";
  sub import {
    croak "disable indirect!" if feature::feature_enabled("indirect");
  }

Test whether a named feature is enabled at a given level in the call
stack, returning a true value if it is.  C<$depth> defaults to 1,
which checks the scope that called the scope calling
feature::feature_enabled().

croaks for an unknown feature name.

=item features_enabled()

=item features_enabled($depth)

  package ReportEnabledFeatures;
  use feature "say";
  sub import {
    say STDERR join " ", feature::features_enabled();
  }

Returns a list of the features enabled at a given level in the call
stack.  C<$depth> defaults to 1, which checks the scope that called
the scope calling feature::features_enabled().

=item feature_bundle()

=item feature_bundle($depth)

Returns the feature bundle, if any, selected at a given level in the
call stack.  C<$depth> defaults to 1, which checks the scope that called
the scope calling feature::feature_bundle().

Returns an undefined value if no feature bundle is selected in the
scope.

The bundle name returned will be for the earliest bundle matching the
selected bundle, so:

  use feature ();
  use v5.12;
  BEGIN { print feature::feature_bundle(0); }

will print C<5.11>.

This returns internal state, at this point C<use v5.12;> sets the
feature bundle, but C< use feature ":5.12"; > does not set the feature
bundle.  This may change in a future release of perl.

=back

=cut

sub import {
    shift;

    if (!@_) {
        croak("No features specified");
    }

    __common(1, @_);
}

sub unimport {
    shift;

    # A bare C<no feature> should reset to the default bundle
    if (!@_) {
	$^H &= ~($hint_uni8bit|$hint_mask);
	return;
    }

    __common(0, @_);
}


sub __common {
    my $import = shift;
    my $bundle_number = $^H & $hint_mask;
    my $features = $bundle_number != $hint_mask
      && $feature_bundle{$hint_bundles[$bundle_number >> $hint_shift]};
    if ($features) {
	# Features are enabled implicitly via bundle hints.
	# Delete any keys that may be left over from last time.
	delete @^H{ values(%feature) };
	$^H |= $hint_mask;
	for (@$features) {
	    $^H{$feature{$_}} = 1;
	    $^H |= $hint_uni8bit if $_ eq 'unicode_strings';
	}
    }
    while (@_) {
        my $name = shift;
        if (substr($name, 0, 1) eq ":") {
            my $v = substr($name, 1);
            if (!exists $feature_bundle{$v}) {
                $v =~ s/^([0-9]+)\.([0-9]+).[0-9]+$/$1.$2/;
                if (!exists $feature_bundle{$v}) {
                    unknown_feature_bundle(substr($name, 1));
                }
            }
            unshift @_, @{$feature_bundle{$v}};
            next;
        }
        if (!exists $feature{$name}) {
            if (exists $noops{$name}) {
                next;
            }
            if (!$import && exists $removed{$name}) {
                next;
            }
            unknown_feature($name);
        }
	if ($import) {
	    $^H{$feature{$name}} = 1;
	    $^H |= $hint_uni8bit if $name eq 'unicode_strings';
	} else {
            delete $^H{$feature{$name}};
            $^H &= ~ $hint_uni8bit if $name eq 'unicode_strings';
        }
    }
}

sub unknown_feature {
    my $feature = shift;
    croak(sprintf('Feature "%s" is not supported by Perl %vd',
            $feature, $^V));
}

sub unknown_feature_bundle {
    my $feature = shift;
    croak(sprintf('Feature bundle "%s" is not supported by Perl %vd',
            $feature, $^V));
}

sub croak {
    require Carp;
    Carp::croak(@_);
}

sub features_enabled {
    my ($depth) = @_;

    $depth //= 1;
    my @frame = caller($depth+1)
      or return;
    my ($hints, $hinthash) = @frame[8, 10];

    my $bundle_number = $hints & $hint_mask;
    if ($bundle_number != $hint_mask) {
        return $feature_bundle{$hint_bundles[$bundle_number >> $hint_shift]}->@*;
    }
    else {
        my @features;
        for my $feature (sort keys %feature) {
            if ($hinthash->{$feature{$feature}}) {
                push @features, $feature;
            }
        }
        return @features;
    }
}

sub feature_enabled {
    my ($feature, $depth) = @_;

    $depth //= 1;
    my @frame = caller($depth+1)
      or return;
    my ($hints, $hinthash) = @frame[8, 10];

    my $hint_feature = $feature{$feature}
      or croak "Unknown feature $feature";
    my $bundle_number = $hints & $hint_mask;
    if ($bundle_number != $hint_mask) {
        my $bundle = $hint_bundles[$bundle_number >> $hint_shift];
        for my $bundle_feature ($feature_bundle{$bundle}->@*) {
            return 1 if $bundle_feature eq $feature;
        }
        return 0;
    }
    else {
        return $hinthash->{$hint_feature} // 0;
    }
}

sub feature_bundle {
    my $depth = shift;

    $depth //= 1;
    my @frame = caller($depth+1)
      or return;
    my $bundle_number = $frame[8] & $hint_mask;
    if ($bundle_number != $hint_mask) {
        return $hint_bundles[$bundle_number >> $hint_shift];
    }
    else {
        return undef;
    }
}

1;

# ex: set ro ft=perl:
