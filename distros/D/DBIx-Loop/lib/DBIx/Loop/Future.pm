package DBIx::Loop::Future;

use 5.008003;
use strict;
use warnings;
use DBIx::Loop;

our $VERSION = '0.09';


1;

__END__

=head1 NAME

DBIx::Loop::Future - the canonical future for DBIx::Loop

=head1 DESCRIPTION

A minimal, one-shot future. The hot primitives (C<new>, C<done>, C<fail>,
C<on_ready>, C<is_ready>, C<is_done>, C<is_failed>, C<failure>, C<get>) are
implemented in C, and so are C<then> and C<else>: a continuation is an array
on the future's own callback queue rather than a compiled closure, so settling
a chain runs no Perl frame except your own callbacks.

This is the future DBIx::Loop returns on loops that have no native future
(AnyEvent, POE). On loops that do (IO::Async C<Future>, Mojo C<Mojo::Promise>,
Hyperman C<hmf>), the loop adapter's future factory returns that native type
instead. See L<DBIx::Loop>.

C<get> returns the result only once the future is ready; awaiting a pending
future is the event loop's job, not the future's.

=head1 ASYNC/AWAIT

This class implements the C<Future::AsyncAwait::Awaitable> API, so one of
these can be awaited directly:

    use Future::AsyncAwait;

    async sub row_count {
        my @rows = await $db->query('SELECT * FROM things');
        return scalar @rows;
    }

Whatever it awaited, an C<async sub> returns a CPAN L<Future> by default.
Naming this class at import makes it return one of these instead:

    use Future::AsyncAwait future_class => 'DBIx::Loop::Future';

Two limits follow from what this future is, and both are deliberate:

=over

=item -

B<It cannot be cancelled.> A DBIx::Loop::Future settles exactly once, into
done or failed, and has no C<cancel>. Cancelling the future an C<async sub>
returned, or abandoning one part way, is not available.

=item -

B<A toplevel C<await> does not block.> There is no blocking wait here to run,
so awaiting a pending future outside an C<async sub> reports that it is not
ready rather than waiting for it. Run your event loop.

=back

Which class you get depends on the loop, so whether C<await> works at all
does too. See L<DBIx::Loop/"Futures and the loop you are on">.

=head1 AUTHOR

LNATION <email@lnation.org>

=cut
