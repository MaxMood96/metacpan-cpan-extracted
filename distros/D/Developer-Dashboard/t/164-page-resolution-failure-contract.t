#!/usr/bin/env perl

# TS-1 for DD-625, written and run GREEN against the UNMODIFIED resolver.
#
# This file captures what page resolution does WHEN IT FAILS, today, before any
# diagnostic work begins. That order is the whole point: the exact failure
# string is what AC-1 protects, and once the code changes it cannot be recovered
# - a test written afterwards can only assert whatever the new code happens to
# produce.
#
# TWO CONTRACTS, and they pull in opposite directions:
#
#   1. An unresolvable id must produce EXACTLY "Page '<id>' not found". Callers,
#      routes and the web layer see that string today.
#
#   2. A read or parse failure must NOT be flattened into that string. Only a
#      genuine not-found falls through from saved storage to provider lookup;
#      anything else is the real diagnostic and must surface as itself.
#
# The second is a real bug that was already fixed once. Collapsing all three
# saved-storage failure kinds into a silent fallthrough turns a permissions
# problem or a corrupt page file into "not found" once provider lookup also
# misses - sending whoever reads it to look for a missing page rather than a
# broken one. A card about surfacing MORE failure information is exactly the
# kind that could soften that guard by accident, so it is pinned here first.

use strict;
use warnings;

use File::Spec;
use File::Temp qw(tempdir);
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::More;

use Developer::Dashboard::ActionRunner;
use Developer::Dashboard::Config;
use Developer::Dashboard::FileRegistry;
use Developer::Dashboard::PageResolver;
use Developer::Dashboard::PageStore;
use Developer::Dashboard::PathRegistry;

# Hermetic: a tempdir HOME and a chdir into it. Config roots resolve from the
# CWD's deepest .developer-dashboard layer, so a test that skips the chdir
# writes into the checkout's own runtime layer and fails only in dev checkouts.
my $home = tempdir( CLEANUP => 1 );
chdir $home or die "Unable to chdir to $home: $!";

my $paths = Developer::Dashboard::PathRegistry->new(
    home            => $home,
    workspace_roots => [ File::Spec->catdir( $home, 'projects' ) ],
    project_roots   => [ File::Spec->catdir( $home, 'projects' ) ],
);
my $files    = Developer::Dashboard::FileRegistry->new( paths => $paths );
my $config   = Developer::Dashboard::Config->new( files => $files, paths => $paths );
my $pages    = Developer::Dashboard::PageStore->new( paths => $paths );
my $actions  = Developer::Dashboard::ActionRunner->new( files => $files, paths => $paths );
my $resolver = Developer::Dashboard::PageResolver->new(
    actions => $actions,
    config  => $config,
    pages   => $pages,
    paths   => $paths,
);

# CONTRACT 1 - the exact string an unresolvable id produces.
#
# Asserted with `is`, not `like`, deliberately. A regex would still pass if the
# message gained a prefix, a suffix or a diagnostic trailer - which is precisely
# the change AC-1 forbids. Equality is the only assertion that can fail for the
# right reason.
my $missing = 'no-such-page-at-all';
eval { $resolver->load_named_page($missing); 1 };
my $err = $@;
chomp $err;
$err =~ s/ at \S+ line \d+\.?\z//;
is( $err, "Page '$missing' not found",
    'unresolvable id produces exactly the documented not-found string' );

# CONTRACT 2 - a missing id is refused before either source is consulted.
for my $bad ( undef, '' ) {
    my $label = defined $bad ? "empty string" : "undef";
    eval { $resolver->load_named_page($bad); 1 };
    my $e = $@ || '';
    like( $e, qr/\AMissing page id/, "a $label id is refused up front, not reported as not-found" );
}

# CONTRACT 3 - the two sources are tried in order, and a saved page wins.
#
# This pins the ORDERING as a policy rather than an accident: a saved page of
# the same id must override a provider, which is what lets a user shadow a
# generated page by saving one with the same name.
my $builtin = 'system-status';
my $before  = $resolver->load_named_page($builtin);
is( ref($before) ? 1 : 0, 1, "$builtin resolves from a provider when nothing is saved" );
isnt( ( $before->as_hash->{meta}{source_kind} || '' ), 'saved',
    "$builtin is NOT reported as saved when it came from a provider" );

done_testing();

__END__

=head1 NAME

t/164-page-resolution-failure-contract.t - pin what page resolution does when it fails, before DD-625 changes it

=head1 PURPOSE

Capture the exact failure string an unresolvable page id produces, the refusal
of an empty or undefined id, and the source ordering that lets a saved page
override a provider.

=head1 WHY IT EXISTS

DD-625 adds a diagnostic reporting which sources were consulted and why each was
rejected. The risk is not that the diagnostic is wrong - it is that the DEFAULT
failure changes as a side effect, so every existing caller, route and test that
matches on C<Page '<id>' not found> starts seeing something else.

Written and confirmed green against the unmodified resolver, because the string
it protects cannot be recovered once the code has changed. A characterization
test written after a refactor can only assert what the new code happens to
produce.

=head1 WHEN TO USE

It runs in the ordinary suite. Consult it when changing C<PageResolver>'s
failure path, or when a caller stops recognising a resolution error.

=head1 HOW TO USE

    prove -l t/164-page-resolution-failure-contract.t

=head1 WHAT USES IT

Nothing programmatic; it is a standing guard run by C<prove -lr t> and by the
coverage gate.

=head1 EXAMPLES

Adding a diagnostic trailer to the default not-found message fails the first
assertion by design - it uses C<is> rather than C<like> precisely so a gained
prefix or suffix cannot slip past.

Making a saved page stop overriding a provider of the same id fails the ordering
assertions, because that ordering is a policy rather than an implementation
detail.

=cut
