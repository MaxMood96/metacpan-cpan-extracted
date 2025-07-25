package Test::Differences;

=encoding utf8

=head1 NAME

Test::Differences - Test strings and data structures and show differences if not ok

=head1 SYNOPSIS

   use Test;    ## Or use Test::More
   use Test::Differences;

   eq_or_diff $got,  "a\nb\nc\n",   "testing strings";
   eq_or_diff \@got, [qw( a b c )], "testing arrays";

   ## Passing options:
   eq_or_diff $got, $expected, $name, { context => 300 };  ## options

   ## Using with DBI-like data structures

   use DBI;

   ... open connection & prepare statement and @expected_... here...

   eq_or_diff $sth->fetchall_arrayref, \@expected_arrays  "testing DBI arrays";
   eq_or_diff $sth->fetchall_hashref,  \@expected_hashes, "testing DBI hashes";

   ## To force textual or data line numbering (text lines are numbered 1..):
   eq_or_diff_text ...;
   eq_or_diff_data ...;

=head1 EXPORT

This module exports three test functions and four diff-style functions:

=over 4

=item * Test functions

=over 4

=item * C<eq_or_diff>

=item * C<eq_or_diff_data>

=item * C<eq_or_diff_text>

=back

=item * Diff style functions

=over 4

=item * C<table_diff> (the default)

=item * C<unified_diff>

=item * C<oldstyle_diff>

=item * C<context_diff>

=back

=back

=head1 DESCRIPTION

When the code you're testing returns multiple lines, records or data
structures and they're just plain wrong, an equivalent to the Unix
C<diff> utility may be just what's needed.  Here's output from an
example test script that checks two text documents and then two
(trivial) data structures:

 t/99example....1..3
 not ok 1 - differences in text
 #     Failed test ((eval 2) at line 14)
 #     +---+----------------+----------------+
 #     | Ln|Got             |Expected        |
 #     +---+----------------+----------------+
 #     |  1|this is line 1  |this is line 1  |
 #     *  2|this is line 2  |this is line b  *
 #     |  3|this is line 3  |this is line 3  |
 #     +---+----------------+----------------+
 not ok 2 - differences in whitespace
 #     Failed test ((eval 2) at line 20)
 #     +---+------------------+------------------+
 #     | Ln|Got               |Expected          |
 #     +---+------------------+------------------+
 #     |  1|        indented  |        indented  |
 #     *  2|        indented  |\tindented        *
 #     |  3|        indented  |        indented  |
 #     +---+------------------+------------------+
 not ok 3
 #     Failed test ((eval 2) at line 22)
 #     +----+-------------------------------------+----------------------------+
 #     | Elt|Got                                  |Expected                    |
 #     +----+-------------------------------------+----------------------------+
 #     *   0|bless( [                             |[                           *
 #     *   1|  'Move along, nothing to see here'  |  'Dry, humorless message'  *
 #     *   2|], 'Test::Builder' )                 |]                           *
 #     +----+-------------------------------------+----------------------------+
 # Looks like you failed 3 tests of 3.

eq_or_diff_...() compares two strings or (limited) data structures and
either emits an ok indication or a side-by-side diff.  Test::Differences
is designed to be used with Test.pm and with Test::Simple, Test::More,
and other Test::Builder based testing modules.  As the SYNOPSIS shows,
another testing module must be used as the basis for your test suite.

=head1 OPTIONS

The options to C<eq_or_diff> give some fine-grained control over the output.

=over 4

=item * C<context>

This allows you to control the amount of context shown:

   eq_or_diff $got, $expected, $name, { context => 50000 };

will show you lots and lots of context.  Normally, eq_or_diff() uses
some heuristics to determine whether to show 3 lines of context (like
a normal unified diff) or 25 lines.

=item * C<data_type>

C<text> or C<data>. This normally defaults to C<data>. If, however, neither of
C<$got> or C<$expected> is a reference then  it defaults to C<text>. You can
also force one or the other by calling C<eq_or_diff_text> or
C<eq_or_diff_data>.

The difference is that in text mode lines are numbered from 1, but in data mode
from 0 (and are refered to as 'elements' (Elt) instead of lines):

    # +---+-------+----------+
    # | Ln|Got    |Expected  |
    # +---+-------+----------+
    # *  1|'foo'  |'bar'     *
    # +---+-------+----------+

    # +----+---------+----+----------+
    # | Elt|Got      | Elt|Expected  |
    # +----+---------+----+----------+
    # *   0|[        *   0|'bar'     *
    # *   1|  'foo'  *    |          |
    # *   2|]        *    |          |
    # +----+---------+----+----------+

The difference is purely cosmetic, it makes no difference to how comparisons
are performed.

=item * C<Sortkeys>

If passed, whatever value is added is used as the argument for L<Data::Dumper>
Sortkeys option. See the L<Data::Dumper> docs to understand how you can
control the Sortkeys behavior.

=item * C<filename_a> and C<filename_b>

The column headers to use in the output. They default to 'Got' and 'Expected'.

=back

=head1 DIFF STYLES

For extremely long strings, a table diff can wrap on your screen and be hard
to read.  If you are comfortable with different diff formats, you can switch
to a format more suitable for your data.  These are the four formats supported
by the L<Text::Diff> module and are set with the following functions:

=over 4

=item * C<table_diff> (the default)

=item * C<unified_diff>

=item * C<oldstyle_diff>

=item * C<context_diff>

=back

You can run the following to understand the different diff output styles:

 use Test::More 'no_plan';
 use Test::Differences;

 my $long_string = join '' => 1..40;

 TODO: {
     local $TODO = 'Testing diff styles';

     # this is the default and does not need to explicitly set unless you need
     # to reset it back from another diff type
     table_diff;
     eq_or_diff $long_string, "-$long_string", 'table diff';

     unified_diff;
     eq_or_diff $long_string, "-$long_string", 'unified diff';

     context_diff;
     eq_or_diff $long_string, "-$long_string", 'context diff';

     oldstyle_diff;
     eq_or_diff $long_string, "-$long_string", 'oldstyle diff';
 }

=head1 UNICODE

Generally you'll find that the following test output is disappointing.

    use Test::Differences;
    use utf8;

    my $want = { 'Traditional Chinese' => '中國' };
    my $have = { 'Traditional Chinese' => '中国' };

    eq_or_diff $have, $want, 'Unicode, baby';

Here's what you get:

    #   Failed test 'Unicode, baby'
    #   at t/unicode.t line 12.
    # +----+-----------------------+-----------------------+
    # | Elt|Got                    |Expected               |
    # +----+-----------------------+-----------------------+
    # |   0|'Traditional Chinese'  |'Traditional Chinese'  |
    # *   1|'\x{4e2d}\x{56fd}'     |'\x{4e2d}\x{570b}'     *
    # +----+-----------------------+-----------------------+
    # Looks like you failed 1 test of 1.
    Dubious, test returned 1 (wstat 256, 0x100)
    Failed 1/1 subtests

A patch to fix this would be *most* welcome.

=head1 Unknown::Values

L<Unknown::Values> is a module which provides values which will never compare as being
the same as anything else, not even the same as itself.

If code looks too hard at one of these values (and Test::Differences looks very hard indeed)
that is a fatal error. This means that while we can detect the presence of these beasties,
and tell you that they compare different, for Complicated Internals Reasons we can't show you
much context. Sorry.

NB that the support for these is experimental and relies on an undocumented unstable
interface in Unknown::Values. If that fails then Test::Differences will I<probably> just die
when it sees them instead of telling you that the comparison failed.

=cut

our $VERSION = "0.72"; # or "0.001_001" for a dev release
$VERSION = eval $VERSION;

use Exporter;

@ISA    = qw( Exporter );
@EXPORT = qw(
  eq_or_diff
  eq_or_diff_text
  eq_or_diff_data
  unified_diff
  context_diff
  oldstyle_diff
  table_diff
);

use strict;
use warnings;

use Carp;
use Text::Diff;
use  Data::Dumper;

{
    my $diff_style = 'Table';
    my %allowed_style = map { $_ => 1 } qw/Unified Context OldStyle Table/;
    sub _diff_style {
        return $diff_style unless @_;
        my $requested_style = shift;
        unless ( $allowed_style{$requested_style} ) {
           Carp::croak("Uknown style ($requested_style) requested for diff");
        }
        $diff_style = $requested_style;
    }
}

sub unified_diff  { _diff_style('Unified') }
sub context_diff  { _diff_style('Context') }
sub oldstyle_diff { _diff_style('OldStyle') }
sub table_diff    { _diff_style('Table') }

sub _identify_callers_test_package_of_choice {
    ## This is called at each test in case Test::Differences was used before
    ## the base testing modules.
    ## First see if %INC tells us much of interest.
    my $has_builder_pm = grep $_ eq "Test/Builder.pm", keys %INC;
    my $has_test_pm    = grep $_ eq "Test.pm",         keys %INC;

    return "Test"          if $has_test_pm  && !$has_builder_pm;
    return "Test::Builder" if !$has_test_pm && $has_builder_pm;

    if ( $has_test_pm && $has_builder_pm ) {
        ## TODO: Look in caller's namespace for hints.  For now, assume Builder.
        ## This should only ever be an issue if multiple test suites end
        ## up in memory at once.
        return "Test::Builder";
    }
}

my $warned_of_unknown_test_lib;

sub eq_or_diff_text { $_[3] = { data_type => "text" }; goto &eq_or_diff; }
sub eq_or_diff_data { $_[3] = { data_type => "data" }; goto &eq_or_diff; }

## This string is a cheat: it's used to see if the two arrays of values
## are identical.  The stringified values are joined using this joint
## and compared using eq.  This is a deep equality comparison for
## references and a shallow one for scalars.
my $joint = chr(0) . "A" . chr(1);

sub _isnt_ARRAY_of_scalars {
    return 1 if ref ne "ARRAY";
    return scalar grep ref, @$_;
}

sub _isnt_HASH_of_scalars {
    return 1 if ref ne "HASH";
    return scalar grep ref, values %$_;
}

use constant ARRAY_of_scalars           => "ARRAY of scalars";
use constant ARRAY_of_ARRAYs_of_scalars => "ARRAY of ARRAYs of scalars";
use constant ARRAY_of_HASHes_of_scalars => "ARRAY of HASHes of scalars";
use constant HASH_of_scalars            => "HASH of scalars";

sub _grok_type {
    local $_ = shift if @_;
    return "SCALAR" unless ref;
    if ( ref eq "ARRAY" ) {
        return undef unless @$_;
        return ARRAY_of_scalars
          unless _isnt_ARRAY_of_scalars;
        return ARRAY_of_ARRAYs_of_scalars
          unless grep _isnt_ARRAY_of_scalars, @$_;
        return ARRAY_of_HASHes_of_scalars
          unless grep _isnt_HASH_of_scalars, @$_;
        return 0;
    }
    elsif ( ref eq 'HASH' ) {
        return HASH_of_scalars
          unless _isnt_HASH_of_scalars($_);
        return 0;
    }
}

sub eq_or_diff {
    my ( @vals, $name, $options );
    $options = pop if @_ > 2 && ref $_[-1];
    ( $vals[0], $vals[1], $name ) = @_;

    my @types = map { _grok_type($_) } @vals;
    my $dump_it = !$types[0] || !$types[1];

    my($data_type, $filename_a, $filename_b);
    if($options) {
        $data_type  = $options->{data_type};
        $filename_a = $options->{filename_a};
        $filename_b = $options->{filename_b};
    }
    $data_type ||= "text" unless ref $vals[0] || ref $vals[1];
    $data_type ||= "data";

    $filename_a ||= 'Got';
    $filename_b ||= 'Expected';

    my @widths;

    local $Data::Dumper::Deparse   = 1
        unless($Test::Differences::NoDeparse);
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Purity    = 0;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Deepcopy  = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Useperl   = 1;
    local $Data::Dumper::Sortkeys =
        exists $options->{Sortkeys} ? $options->{Sortkeys} : 1;

    my $unknown_value_in_got;
    my $unknown_value_in_expected;
    my @unknown_flags = (\$unknown_value_in_got, \$unknown_value_in_expected);

    my($got, $expected) = map {
        my $t = eval { [ split /^/, Data::Dumper::Dumper($_) ] };

        my $unknown_flag = shift(@unknown_flags);
        if($@ =~ /^Dereferencing cannot be performed on unknown values at .*Unknown.Values.Instance/) {
            ${$unknown_flag} = 1;
        }

        $t;
    } @vals;

    my $caller = caller;

    my $passed =
        !defined($unknown_value_in_got) &&
        !defined($unknown_value_in_expected) &&
        join( $joint, @$got ) eq join( $joint, @$expected );

    my $diff;
    unless ($passed) {
        if($unknown_value_in_got) { $got = \"got something containing an Unknown::Values::unknown value" };
        if($unknown_value_in_expected) { $expected = \"expected something containing an Unknown::Values::unknown value" };
        my $context;

        $context = $options->{context}
          if exists $options->{context};

        $context = $dump_it ? 2**31 : grep( @$_ > 25, $got, $expected ) ? 3 : 25
            unless defined $context;

        confess "context must be an integer: '$context'\n"
          unless $context =~ /\A\d+\z/;

        $diff = diff $got, $expected,
          { CONTEXT     => $context,
            STYLE       => _diff_style(),
            FILENAME_A  => $filename_a,
            FILENAME_B  => $filename_b,
            OFFSET_A    => $data_type eq "text" ? 1 : 0,
            OFFSET_B    => $data_type eq "text" ? 1 : 0,
            INDEX_LABEL => $data_type eq "text" ? "Ln" : "Elt",
          };
        chomp $diff;
        $diff .= "\n";
    }

    my $which = _identify_callers_test_package_of_choice;

    if ( $which eq "Test" ) {
        @_
          = $passed
          ? ( "", "", $name )
          : ( "\n$diff", "No differences", $name );
        goto &Test::ok;
    }
    elsif ( $which eq "Test::Builder" ) {
        my $test = Test::Builder->new;
        ## TODO: Call exported_to here?  May not need to because the caller
        ## should have imported something based on Test::Builder already.
        $test->ok( $passed, $name );
        $test->diag($diff) unless $passed;
    }
    else {
        unless ($warned_of_unknown_test_lib) {
            Carp::cluck
              "Can't identify test lib in use, doesn't seem to be Test.pm or Test::Builder based\n";
            $warned_of_unknown_test_lib = 1;
        }
        ## Play dumb and hope nobody notices the fool drooling in the corner
        if ($passed) {
            print "ok\n";
        }
        else {
            $diff =~ s/^/# /gm;
            print "not ok\n", $diff;
        }
    }
}

=head1 LIMITATIONS

=head2 C<Test> or C<Test::More>

This module "mixes in" with Test.pm or any of the test libraries based on
Test::Builder (Test::Simple, Test::More, etc).  It does this by peeking to see
whether Test.pm or Test/Builder.pm is in %INC, so if you are not using one of
those, it will print a warning and play dumb by not emitting test numbers (or
incrementing them).  If you are using one of these, it should interoperate
nicely.

=head2 Exporting

Exports all 3 functions by default (and by design).  Use

    use Test::Differences ();

to suppress this behavior if you don't like the namespace pollution.

This module will not override functions like ok(), is(), is_deeply(), etc.  If
it did, then you could C<eval "use Test::Differences qw( is_deeply );"> to get
automatic upgrading to diffing behaviors without the C<sub my_ok> shown above.
Test::Differences intentionally does not provide this behavior because this
would mean that Test::Differences would need to emulate every popular test
module out there, which would require far more coding and maintenance that I'm
willing to do.  Use the eval and my_ok deployment shown above if you want some
level of automation.

=head2 Booleans

Historically, true and false (whether resulting from logical-not C<!> or from
equality checks like C<==>) were represented in perl as numeric C<1> for true
and the empty string C<''> for false. In perl 5.36.0 they became real Boolean
values which for backward compatibility also have their old numeric/string
values. In 5.38 (and in dev releases from 5.37.2 onwards) L<Data::Dumper>
belatedly learned about this, and so Test::Differences (which uses Data::Dumper
under the bonnet) can also tell the difference.

This means that `eq_or_diff(1, !!1)` will behave differently depending on
whether you are using perl 5.38 or later (in which case it will say they are
different) or 5.36 or earlier (which will say they are the same).

=head2 Unicode

Perls before 5.6.0 don't support characters > 255 at all, and 5.6.0
seems broken.  This means that you might get odd results using perl5.6.0
with unicode strings.

=head2 C<Data::Dumper> and older Perls.

Relies on Data::Dumper (for now), which, prior to perl5.8, will not always
report hashes in the same order.  C< $Data::Dumper::Sortkeys > I<is> set to 1,
so on more recent versions of Data::Dumper, this should not occur.  Check CPAN
to see if it's been peeled out of the main perl distribution and backported.
Reported by Ilya Martynov <ilya@martynov.org>, although the Sortkeys "future
perfect" workaround has been set in anticipation of a new Data::Dumper for a
while.  Note that the two hashes should report the same here:

    not ok 5
    #     Failed test (t/ctrl/05-home.t at line 51)
    # +----+------------------------+----+------------------------+
    # | Elt|Got                     | Elt|Expected                |
    # +----+------------------------+----+------------------------+
    # |   0|{                       |   0|{                       |
    # |   1|  'password' => '',     |   1|  'password' => '',     |
    # *   2|  'method' => 'login',  *    |                        |
    # |   3|  'ctrl' => 'home',     |   2|  'ctrl' => 'home',     |
    # |    |                        *   3|  'method' => 'login',  *
    # |   4|  'email' => 'test'     |   4|  'email' => 'test'     |
    # |   5|}                       |   5|}                       |
    # +----+------------------------+----+------------------------+

Data::Dumper also overlooks the difference between

    $a[0] = \$a[1];
    $a[1] = \$a[0];   # $a[0] = \$a[1]

and

    $x = \$y;
    $y = \$x;
    @a = ( $x, $y );  # $a[0] = \$y, not \$a[1]

The former involves two scalars, the latter 4: $x, $y, and @a[0,1].
This was carefully explained to me in words of two syllables or less by
Yves Orton <demerphq@hotmail.com>.  The plan to address this is to allow
you to select Data::Denter or some other module of your choice as an
option.

=head2 Code-refs

Test::Differences turns on C<$Data::Dumper::Deparse>, so any code-refs in your
data structures will be turned into text before they are examined, using
L<B::Deparse>. The precise text generated for a sub-ref might not be what you
expect as it is generated from the compiled version of the code, but it should
at least be consistent and spot differences correctly.

You can turn this behaviour off by setting C<$Test::Differences::NoDeparse>.

=head1 AUTHORS

    Barrie Slaymaker <barries@slaysys.com> - original author

    Curtis "Ovid" Poe <ovid@cpan.org>

    David Cantrell <david@cantrell.org.uk>

=head1 LICENSE

Copyright Barrie Slaymaker, Curtis "Ovid" Poe, and David Cantrell.

All Rights Reserved.

You may use, distribute and modify this software under the terms of the GNU
public license, any version, or the Artistic license.

=cut

1;
