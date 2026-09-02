#!/usr/bin/env perl

# Written RED, before Developer::Dashboard::StreamDrain exists.
#
# This file pins the extraction itself - where the drain step lives and who can
# reach it - rather than what it does. What it does is already covered by the
# per-module coverage tests, and by t/162, which pins the five axes on which the
# callers legitimately differ.
#
# THREE THINGS HAVE TO BE TRUE AND NOTHING ELSE CHECKS THEM:
#
#   1. the drain step is DEFINED in exactly one place
#   2. both inline consumers can CALL it - which proves the export reaches each
#      package's method-resolution path rather than merely existing
#   3. PageRuntime is NOT a consumer. It already factored its read into
#      _stream_sysread with an EINTR-aware drain, so it is the reference for
#      this design rather than a caller of it. Migrating it is out of scope
#      (AC-2), and this file fails by design if somebody does.
#
# Point 3 is the guard, not the goal. DD-617's premise was originally that all
# three readers shared the inner step; t/162 disproved that on its first run.
# Without an assertion holding the corrected scope, the obvious "finish the job"
# instinct would quietly pull PageRuntime in - replacing an EINTR-aware drain
# with one that is not, which is a regression wearing the shape of consistency.

use strict;
use warnings;

use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";

my $SHARED   = 'Developer::Dashboard::StreamDrain';
my $HELPER   = '_drain_ready_handle';
my @CONSUMERS = qw(
    Developer::Dashboard::SkillDispatcher
    Developer::Dashboard::SkillManager
);

require_ok($SHARED)
    or BAIL_OUT("$SHARED does not exist yet - this file is the RED test for it");

require_ok($_) for @CONSUMERS;

# 1. Defined in exactly one place.
#
# `defined &Pkg::name` rather than ->can(): can() follows method resolution and
# answers true for an imported sub, which is precisely what must be told apart
# from a local definition here.
{
    no strict 'refs';
    ok( defined &{"${SHARED}::${HELPER}"}, "$HELPER is defined in $SHARED" );
}

# 2. Both inline consumers can reach it.
# NOTE ON THE SECOND ASSERTION, learned by getting it wrong here first: an
# imported sub IS defined in the importing package's symbol table. Exporter
# installs it there, which is exactly what makes $self->_drain_ready_handle
# resolve through the consumer - the property DD-615 deliberately preserved.
# So `!defined &{"Consumer::helper"}` is NOT a test for "imports rather than
# defines"; it fails against a correct extraction. Comparing the CODE REFS is,
# because a local copy would be a different one.
for my $pkg (@CONSUMERS) {
    ok( $pkg->can($HELPER), "$pkg can reach $HELPER" );
    no strict 'refs';
    is( \&{"${pkg}::${HELPER}"}, \&{"${SHARED}::${HELPER}"},
        "the $HELPER reached by $pkg IS the shared one, not a local copy" );
}

# 3. PageRuntime keeps its own, better-factored read. It is the reference, not a
#    consumer, and pulling it in would replace an EINTR-aware drain with one
#    that is not.
require_ok('Developer::Dashboard::PageRuntime');
{
    no strict 'refs';
    ok( defined &{'Developer::Dashboard::PageRuntime::_stream_sysread'},
        'PageRuntime still defines its own _stream_sysread' );
    ok( defined &{'Developer::Dashboard::PageRuntime::_drain_saved_ajax_ready_handle'},
        'PageRuntime still defines its own EINTR-aware drain' );
}
ok( !Developer::Dashboard::PageRuntime->can($HELPER),
    "PageRuntime does NOT import $HELPER - it is the reference, not a consumer (AC-2)" );

done_testing();

__END__

=head1 NAME

t/163-stream-drain-extraction.t - pin where the shared stream-drain step lives and who reaches it

=head1 PURPOSE

Assert that the inner drain step shared by C<SkillDispatcher> and
C<SkillManager> is defined in exactly one module, that both reach it by import
rather than by keeping a local copy, and that C<PageRuntime> is deliberately not
a consumer.

=head1 WHY IT EXISTS

The per-module coverage tests exercise what these readers DO. Nothing exercised
where the drain step LIVES, so an extraction could move it, or over-reach and
absorb a module that should keep its own, and every behaviour test would still
pass.

The over-reach is the real risk. C<PageRuntime> already factored its read into
C<_stream_sysread> and guards C<EINTR> explicitly, which the two inline readers
do not (see DD-678). Pulling it into the shared helper for consistency would
replace a correct drain with a defective one, and no existing test would notice.

=head1 WHEN TO USE

It runs in the ordinary suite. Consult it when changing which modules share the
drain step, or when a call site stops resolving it.

=head1 HOW TO USE

    prove -l t/163-stream-drain-extraction.t

=head1 WHAT USES IT

Nothing programmatic; it is a standing guard run by C<prove -lr t> and by the
coverage gate.

=head1 EXAMPLES

Adding a third consumer means adding it to C<@CONSUMERS>. Making C<PageRuntime>
import the shared helper makes this file fail by design, because that module's
own drain handles a case the shared one deliberately does not.

=cut
