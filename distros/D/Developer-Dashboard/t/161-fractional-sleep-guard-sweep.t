#!/usr/bin/env perl

use strict;
use warnings;

use File::Find qw(find);
use Cwd qw(abs_path);
use File::Spec;
use FindBin qw($RealBin);
use Test::More;

# _repo_path(@parts)
# Builds an absolute path rooted at the repository checkout, independent of
# the caller's own working directory.
# Input: path segment strings.
# Output: absolute path string.
sub _repo_path {
    return File::Spec->rel2abs( File::Spec->catfile( $RealBin, File::Spec->updir, @_ ) );
}

# DD-615: this baseline is empty on purpose. Every fractional sleep in the tree
# reaches Time::HiRes at the time this gate was written, so any hit at all is a
# genuinely new one and fails the suite on its own.
my %BASELINE = map { $_ => 1 } ();

# _code_only($path)
# Returns a file's source with everything that is NOT code removed: POD blocks,
# anything after __END__/__DATA__, whole-line comments, and trailing comments.
#
# THIS FUNCTION IS THE POINT OF THE FILE, not an implementation detail. A guard
# that greps raw source cannot tell code from the commentary about the code, so
# it would fail the moment somebody EXPLAINS the very construct it forbids - and
# the fix for this bug carries a comment naming "sleep 0.05" three times, as does
# the ticket trail. A spec that punishes documentation gets the documentation
# deleted, which is the opposite of what a guard is for.
#
# Known limit, stated rather than hidden: trailing comments are stripped from the
# first unescaped "#" preceded by whitespace, so a "#" inside a string literal
# would truncate that line early. That can only mask a fractional sleep written
# AFTER a #-bearing string on the same physical line, which does not occur here
# and would be visible in review. Dependency-free on purpose, exactly as
# t/159-dollar-question-guard-sweep.t is - a gate that needs a parser off CPAN is
# a gate that stops running.
#
# Input: file path string.
# Output: source text string containing code only.
sub _code_only {
    my ($path) = @_;
    open my $fh, '<', $path or die "Unable to read $path: $!";
    my @lines = <$fh>;
    close $fh or die "Unable to close $path: $!";

    my @code;
    my $in_pod = 0;
    for my $line (@lines) {
        last if $line =~ /\A __(?:END|DATA)__ \s* \z/x;
        if ( $line =~ /\A =\w+ /x ) { $in_pod = 1; }
        if ($in_pod) {
            $in_pod = 0 if $line =~ /\A =cut \b/x;
            next;
        }
        next if $line =~ /\A \s* \# /x;
        $line =~ s/ \s \# .* \z //x;
        push @code, $line;
    }
    return join q{}, @code;
}

# _fractional_sleep_hits(@roots)
# Sweeps every Perl file under the given roots for a bare "sleep" called with a
# fractional literal in a file that never imports sleep from Time::HiRes.
#
# CORE::sleep takes integer seconds, so it truncates 0.05 to 0 and returns 0. It
# does not warn and it does not die - the call simply does nothing, which is why
# this class of bug survives review and a green suite. Its two recorded instances
# on this project are a poll loop widened from 60 to 150 iterations that bought
# exactly zero seconds, and DD-615's own extraction, which moved a 50ms Windows
# rename backoff into a module that did not import Time::HiRes.
#
# A fully-qualified Time::HiRes::sleep(0.05) is correct and is not a hit.
#
# Input: list of directory path strings.
# Output: hash reference keyed "relative/path.pm:LINE" for every hit.
sub _fractional_sleep_hits {
    my (@roots) = @_;
    my @files;
    for my $root (@roots) {
        next if !-d $root;
        find(
            {   wanted   => sub { push @files, $File::Find::name if -f $File::Find::name && /\.(?:pm|pl|t)\z/ },
                no_chdir => 1,
            },
            $root
        );
    }

    my $repo = _repo_path();
    my %hits;
    for my $file ( sort @files ) {
        # This guard's own source necessarily contains the construct it forbids -
        # in the detecting regex and in the failure message. Excluding it by its
        # real path (not by name) is the same distinction the comment-stripping
        # above draws: a file that DESCRIBES the construct is not a file that
        # RUNS it. Anything else makes the guard fail on itself the first time
        # it is run, which is how this was found.
        next if abs_path($file) eq abs_path(__FILE__);
        my $code = _code_only($file);
        next if $code =~ /use \s+ Time::HiRes [^;]* \b sleep \b/x;

        my $line_no = 0;
        for my $line ( split /\n/, $code ) {
            $line_no++;
            next if $line =~ /Time::HiRes::sleep/;
            next if $line !~ / (?<! :) \b sleep \s* \(? \s* (\d* \. \d+) /x;

            # Capture BEFORE anything else can match. The substitution below is a
            # match, so it resets $1 - the first version of this file read $1
            # after building $rel and reported every hit as "calls sleep "
            # with the literal missing, which is the one detail a reader needs.
            my $literal = $1;

            my $rel = $file;
            $rel =~ s/\A \Q$repo\E \/? //x;
            $hits{"$rel:$line_no"} = $literal;
        }
    }
    return \%hits;
}

my $hits = _fractional_sleep_hits( _repo_path('lib'), _repo_path('script'), _repo_path('t'), _repo_path('bin') );

for my $key ( sort keys %{$hits} ) {
    next if $BASELINE{$key};
    fail("$key calls sleep $hits->{$key} without importing sleep from Time::HiRes - CORE::sleep truncates it to 0");
}

ok( 1, 'fractional-sleep sweep ran' );

# The sweep must be able to SEE a hit, or a clean report proves nothing about the
# tree. This asserts the detector on a known-bad sample rather than trusting that
# zero findings means zero bugs - the instrument is falsified here, in the file,
# instead of by hand once and never again.
{
    my $dir = File::Spec->catdir( File::Spec->tmpdir, "dd615-sleep-probe-$$" );
    mkdir $dir or die "Unable to create $dir: $!";
    my $sample = File::Spec->catfile( $dir, "Probe.pm" );
    open my $fh, '>', $sample or die "Unable to write $sample: $!";
    print {$fh} "package Probe;\nsub wait_a_bit { sleep 0.05; }\n1;\n";
    close $fh or die "Unable to close $sample: $!";

    my $probe = _fractional_sleep_hits($dir);
    my ($found) = grep { /Probe\.pm/ } keys %{$probe};
    ok( $found, 'the sweep detects a fractional sleep with no Time::HiRes import' );

    unlink $sample or die "Unable to remove $sample: $!";
    rmdir $dir  or die "Unable to remove $dir: $!";
}

# And it must NOT fire on a file that merely DISCUSSES the construct, which is
# the failure mode that would get the explanation deleted.
{
    my $dir = File::Spec->catdir( File::Spec->tmpdir, "dd615-sleep-comment-$$" );
    mkdir $dir or die "Unable to create $dir: $!";
    my $sample = File::Spec->catfile( $dir, "Prose.pm" );
    open my $fh, '>', $sample or die "Unable to write $sample: $!";
    print {$fh} "package Prose;\n# never write sleep 0.05 without Time::HiRes\nsub noop { return 1; }\n1;\n";
    close $fh or die "Unable to close $sample: $!";

    my $probe = _fractional_sleep_hits($dir);
    my ($found) = grep { /Prose\.pm/ } keys %{$probe};
    ok( !$found, 'the sweep ignores a fractional sleep that appears only in a comment' );

    unlink $sample or die "Unable to remove $sample: $!";
    rmdir $dir  or die "Unable to remove $dir: $!";
}

done_testing();

__END__

=head1 NAME

t/161-fractional-sleep-guard-sweep.t - fail the build when a fractional sleep cannot reach Time::HiRes

=head1 PURPOSE

Sweep every Perl file under lib/, script/, t/ and bin/ for a bare C<sleep> called
with a fractional literal in a file that never imports C<sleep> from
L<Time::HiRes>, and fail on any hit.

=head1 WHY IT EXISTS

C<CORE::sleep> takes integer seconds. Handed C<0.05> it truncates to zero,
sleeps for no time at all, and returns 0 - without warning and without dying.
The call still looks like a delay in every reading of the source, so the defect
survives review, survives a green suite, and is only visible to someone who
measures elapsed time.

This project has shipped it twice. Once a flaky test was "fixed" by widening a
poll loop from 60 to 150 iterations, in a file that never imported Time::HiRes,
so the change bought exactly zero seconds and was found later by a forensic
pass. Again in DD-615, where extracting shared process-supervision helpers moved
a 50ms Windows rename-retry backoff into a new module that did not import
Time::HiRes - a refactor advertised as behaviour-preserving that did not preserve
behaviour, invisible to the Linux suite because the loop sits behind an
is_windows guard.

A guard that exists only in a reviewer's memory is not a guard, which is the same
reasoning that produced t/159-dollar-question-guard-sweep.t for the C<$?> class.

=head1 WHEN TO USE

It runs in the ordinary suite. Consult it when adding any sub-second delay, or
when a retry loop that should back off appears to spin.

=head1 HOW TO USE

    prove -l t/161-fractional-sleep-guard-sweep.t

A failure names the file, the line and the literal. The fix is to import the
faster sleep - C<use Time::HiRes qw(sleep);> - or to call
C<Time::HiRes::sleep> fully qualified, which the sweep accepts.

=head1 WHAT USES IT

Nothing programmatic; it is a standing guard run by C<prove -lr t> and by the
coverage gate.

=head1 EXAMPLES

Detected, because CORE::sleep truncates the argument to zero:

    package Retry;
    sub back_off { sleep 0.05; }

Accepted, because the fractional sleep resolves to Time::HiRes:

    package Retry;
    use Time::HiRes qw(sleep);
    sub back_off { sleep 0.05; }

Also accepted - prose about the construct is not the construct, so documenting
this trap never fails the build:

    # never write sleep 0.05 without importing Time::HiRes

=cut
