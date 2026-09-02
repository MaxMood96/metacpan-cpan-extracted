#!/usr/bin/env perl

use strict;
use warnings;

use File::Spec;
use FindBin;
use Test::More;

my $ROOT     = File::Spec->rel2abs( File::Spec->catdir( $FindBin::Bin, File::Spec->updir ) );
my $WORKFLOW = File::Spec->catfile( $ROOT, '.github', 'workflows', 'test.yml' );

# -e rather than -d on .git: a linked worktree keeps .git as a FILE holding a
# gitdir pointer, and a -d test here switched this whole guard off in exactly the
# place all ticket work is authored (DD-441 era, guarded by t/139).
plan skip_all => "not a source tree, or no workflow at $WORKFLOW"
  if !-e File::Spec->catdir( $ROOT, '.git' ) || !-f $WORKFLOW;

my $yaml = do { open my $fh, '<', $WORKFLOW or die $!; local $/; <$fh> };

# WHY THIS FILE EXISTS (DD-568)
#   The Test job runs its steps in sequence, so a failure anywhere before the
#   verification steps SKIPS them, and the run reports only the early failure.
#   That destroyed the verdicts this job mostly exists to produce, twice:
#
#     - 23 consecutive runs across ten days in which tests, coverage and both CVE
#       audits executed zero times;
#     - five consecutive merges on 2026-08-16, blocked by an advisory against the
#       perl INTERPRETER, which is not a declared dependency of this distribution.
#
#   Both times every local run truthfully reported PASS, so nothing looked wrong
#   from here. A skipped step is not a passed step - but it reads like silence,
#   and silence from a checker is indistinguishable from one that found nothing.

# Purpose: the block of YAML belonging to one named step, up to the next step.
# Input:   step name
# Output:  that step's text, or undef when there is no such step
sub step_block {
    my ($name) = @_;
    return undef if $yaml !~ /^\s*- name: \Q$name\E\s*$/m;
    my ($block) = $yaml =~ /^(\s*- name: \Q$name\E\s*\n.*?)(?=^\s*- name: |\z)/ms;
    return $block;
}

# 'Install test tools and export project environment' is in this list for a
# reason found the hard way (DD-568): it installs Devel::Cover and exports
# PERL5LIB, and it sits AFTER the audits. Marking only the two verification steps
# would mean that when an audit fails - the exact case this guards - that step is
# skipped and the tests fire into an environment nobody prepared, failing for want
# of PERL5LIB rather than for want of correctness. That converts "no verdict" into
# a FALSE FAILING verdict, which is worse than the skip it replaced. The first
# version of this guard asserted only the two verification steps and would not
# have caught it.
for my $step ( 'Install test tools and export project environment', 'Run tests', 'Verify all-metric lib coverage' ) {
    my $block = step_block($step);
    ok( defined $block, "the '$step' step is still in the workflow" );

    # THE PROPERTY. Without it, one broken gate earlier in the job hides every
    # gate behind it, and the run says nothing about whether the code works.
    like( $block, qr/^\s*if:\s*always\(\)\s*$/m,
        "'$step' runs even when an earlier step failed" );
}

# The setup steps must NOT carry it. Running the suite against a half-built tree
# produces failures that look real and mean nothing, and this project has already
# lost time to a gate that measured a tree it could not attribute. So the
# distinction is asserted, not merely intended.
for my $setup ( 'Checkout', 'Install project dependencies' ) {
    my $block = step_block($setup);
  SKIP: {
        skip "no '$setup' step in this workflow", 1 if !defined $block;
        unlike( $block, qr/^\s*if:\s*always\(\)\s*$/m,
            "'$setup' does NOT run unconditionally - a half-built tree must fail fast" );
    }
}

# Nothing here weakens the job: a failing step must still fail the run. There is
# no `continue-on-error` anywhere, which is the shortcut that WOULD weaken it -
# it would let a real advisory in the isolated dependency root pass unnoticed.
unlike( $yaml, qr/continue-on-error:\s*true/,
    'no step is allowed to fail silently - always() keeps the verdicts, it does not forgive them' );

done_testing;

__END__

=head1 NAME

t/157-ci-verdicts-survive-an-early-failure.t - keep the test and coverage
verdicts even when an earlier CI step fails

=head1 PURPOSE

Assert that the Test workflow's verification steps run unconditionally, that its
setup steps do not, and that no step is marked C<continue-on-error>.

=head1 WHY IT EXISTS

CI steps run in sequence, so a failure before the verification steps skips them
and the run reports only the early failure. This project has lost its test and
coverage verdicts to that twice - once for 23 consecutive runs over ten days, and
once for five consecutive merges - while every local run reported PASS.

=head1 WHEN TO USE

Whenever the Test workflow's steps are reordered or added to, and before
believing a CI run that reports only an early failure - a skipped verification
step is a verdict you did not get, not a verdict that passed.

=head1 WHAT IT DOES NOT DO

It does not make CI more permissive. A failing step still fails the job. The
change it guards affects only whether later verdicts are produced, not whether
earlier failures are forgiven, which is why the absence of C<continue-on-error>
is asserted here too.

=head1 HOW TO USE

  PERL5LIB="$HOME/perl5/lib/perl5" prove -lv t/157-ci-verdicts-survive-an-early-failure.t

=head1 WHAT USES IT

The suite, through C<prove -lr t>. Its subject is F<.github/workflows/test.yml>,
the workflow that produces this project's remote test and coverage verdicts.

=head1 EXAMPLES

To watch it fail, remove C<if: always()> from the "Run tests" step and rerun.

=cut
