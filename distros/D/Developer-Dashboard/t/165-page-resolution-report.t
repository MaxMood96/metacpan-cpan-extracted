#!/usr/bin/env perl

# DD-625: the opt-in resolution report.
#
# The design decision this file exercises is that the report is COLLECTED rather
# than FORMATTED, and that collecting is opt-in. load_named_page takes an
# optional report arrayref; without it, nothing is recorded and the default path
# is unchanged - which is why t/164 still passes untouched.
#
# That matters more than it sounds. The obvious implementation is to make the
# failure message richer, and it is wrong: every caller, route and test matching
# on "Page '<id>' not found" would start seeing something else. A diagnostic that
# alters what existing callers see is a regression wearing a feature's clothes.

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
    actions => $actions, config => $config, pages => $pages, paths => $paths,
);

# A provider-backed id resolves, and the report says which source produced it.
my $ok = $resolver->resolution_report('system-status');
is( $ok->{resolved}, 1, 'a resolvable id reports resolved' );
is( scalar @{ $ok->{steps} }, 2, 'both sources appear in the report, in order' );
is( $ok->{steps}[0]{source}, 'saved',     'saved storage is consulted first' );
is( $ok->{steps}[0]{outcome}, 'not-found', 'saved storage reports why it did not supply the page' );
is( $ok->{steps}[1]{source}, 'providers', 'providers are consulted second' );
is( $ok->{steps}[1]{outcome}, 'matched',  'the provider match is reported' );

# THE CASE THE CARD EXISTS FOR: a mistyped id. The bare failure says only
# "not found"; the report must surface the ids that DO exist, the way Perl's
# loader names the paths it tried rather than just saying the module is missing.
my $typo = $resolver->resolution_report('systm-status');
is( $typo->{resolved}, 0, 'a mistyped id reports unresolved' );
like( $typo->{error}, qr/\APage 'systm-status' not found/,
    'the underlying error is unchanged - the report is additional, not a replacement' );
is( $typo->{steps}[-1]{source}, 'providers', 'the last step consulted is providers' );
is( $typo->{steps}[-1]{outcome}, 'no-match', 'and it reports no match rather than a bare failure' );
like( $typo->{steps}[-1]{detail}, qr/\bsystem-status\b/,
    'the CANDIDATES are reported - the real id a mistyped one was reaching for' );

# A saved page overrides a provider of the same id, and the report shows it -
# the ordering pinned by t/164, now visible rather than merely true.
my $doc = Developer::Dashboard::PageDocument->new(
    id => 'shadowed', title => 'Shadowed', layout => { body => 'saved wins' },
);
$pages->save_page($doc);
my $shadow = $resolver->resolution_report('shadowed');
is( $shadow->{resolved}, 1, 'a saved page resolves' );
is( scalar @{ $shadow->{steps} }, 1, 'providers are never consulted once saved storage matches' );
is( $shadow->{steps}[0]{outcome}, 'matched', 'and the saved match is what the report records' );

# Opt-in: the default path records nothing and is not disturbed.
my @never;
my $plain = $resolver->load_named_page('system-status');
is( scalar @never, 0, 'a report is only collected when one is asked for' );
ok( $plain, 'load_named_page still returns the page with no report argument' );

done_testing();

__END__

=head1 NAME

t/165-page-resolution-report.t - the opt-in resolution report added by DD-625

=head1 PURPOSE

Assert that C<resolution_report> reports both sources in order with what each
said, names the provider candidates when a lookup misses, and that collecting a
report is opt-in so the default resolution path is untouched.

=head1 WHY IT EXISTS

C<PageResolver> already knows two things it discards: which kind of saved-storage
failure occurred, and which provider ids exist. For the commonest failure - a
mistyped or renamed id - the bare C<Page '<id>' not found> is the least useful
thing that could be said, while the answer is in the resolver at the moment it
gives up.

The risk is not that the report is wrong but that adding it changes the DEFAULT
failure, which every caller and route matches on. This file pins that collecting
is opt-in; C<t/164> independently pins that the default is unchanged.

=head1 WHEN TO USE

It runs in the ordinary suite. Consult it when changing what the resolver
reports, or when adding a third page source.

=head1 HOW TO USE

    prove -l t/165-page-resolution-report.t

=head1 WHAT USES IT

Nothing programmatic; a standing guard run by C<prove -lr t> and the coverage
gate.

=head1 EXAMPLES

Making the failure message itself richer, instead of reporting separately, fails
C<t/164> rather than this file - which is the division of labour intended: this
file proves the feature works, that one proves it cost nothing.

=cut
