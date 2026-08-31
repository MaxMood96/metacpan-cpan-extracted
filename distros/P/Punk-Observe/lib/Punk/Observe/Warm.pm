package Punk::Observe::Warm;

use 5.010;
use strict;
use warnings;

use Carp ();
use Punk::Observe ();
use Punk::Observe::Cache ();
use Punk::Observe::Config ();
use Punk::Observe::Store ();
use Time::HiRes ();

our $VERSION = $Punk::Observe::VERSION;

use constant {
    DEPTH_NS   => 7 * 86_400 * 1_000_000_000,   # a week back
    REFRESH_NS =>     2 * 3600 * 1_000_000_000, # the newest two hours, always
    TTL        => 8 * 86_400,                   # outlives the depth
    BUDGET     => 400,                          # chunks computed per pass
    TIMEOUT    => 20,                           # seconds per pass
};

sub _plugin_state {
    my ($class) = @_;
    require Punk::Plugin::Observe;
    my $st = Punk::Plugin::Observe->state_for($class)
        or Carp::croak("Punk::Observe::Warm: no Observe plugin state for "
                     . "$class - is the worker running the same application "
                     . "class as the server?");
    return $st;
}

sub tenants {
    my ($db) = @_;
    my $rows = $db->dbh->selectcol_arrayref(
        'SELECT DISTINCT tenant FROM dashboards ORDER BY tenant');
    return $rows || [];
}

sub queries {
    my ($db, $tenant) = @_;
    my $top = Punk::Observe::Config::dashboards($db, $tenant);
    my (@q, %seen);
    for my $d (@{ $top->{list} || [] }) {
        my $full = Punk::Observe::Config::dashboards($db, $tenant, $d->{slug});
        for my $p (@{ $full->{panels} || [] }) {
            my $src = $p->{query};
            next unless defined $src && length $src;
            next if $seen{$src}++;
            push @q, $src;
        }
    }
    return \@q;
}

sub run {
    my (%opt) = @_;
    my $db    = $opt{db}    or return { tenants => 0, queries => 0 };
    my $for   = $opt{store} or return { tenants => 0, queries => 0 };

    my $now     = defined $opt{now} ? $opt{now} : Punk::Observe::now_ns();
    my $depth   = $opt{depth_ns}   || DEPTH_NS;
    my $refresh = defined $opt{refresh_ns} ? $opt{refresh_ns} : REFRESH_NS;
    my $ttl     = defined $opt{ttl} ? $opt{ttl} : TTL;
    my $budget  = defined $opt{budget} ? $opt{budget} : BUDGET;
    my $timeout = defined $opt{timeout} ? $opt{timeout} : TIMEOUT;
    my $from    = Punk::Observe::Store::nsub($now, $depth);

    my %tot = (tenants => 0, queries => 0, skipped => 0, chunks => 0,
               computed => 0, hits => 0, failed => 0, unstorable => 0,
               stopped => '');

    my $t0 = Time::HiRes::time();

    for my $tenant (@{ tenants($db) }) {
        my $store = $for->($tenant) or next;
        my $cache = $store->{cache} or next;
        $tot{tenants}++;

        for my $q (@{ queries($db, $tenant) }) {
            if (!defined Punk::Observe::Cache::bucket_ns($q)) {
                $tot{skipped}++;
                next;
            }
            $tot{queries}++;

            my $left = $budget - $tot{computed};
            my $secs = $timeout - (Time::HiRes::time() - $t0);
            if ($budget && $left <= 0)  { $tot{stopped} = 'budget';   return \%tot }
            if ($timeout && $secs <= 0) { $tot{stopped} = 'deadline'; return \%tot }

            my $r = Punk::Observe::Cache::warm(
                $store, $q,
                from       => $from,
                to         => $now,
                now        => $now,
                cache      => $cache,
                ttl        => $ttl,
                refresh_ns => $refresh,
                budget     => $left,
                deadline   => $secs,
            );

            $tot{$_} += $r->{$_} for qw(chunks computed hits failed unstorable);

            if ($r->{stopped} eq 'budget' || $r->{stopped} eq 'deadline') {
                $tot{stopped} = $r->{stopped};
                return \%tot;
            }
        }
    }
    return \%tot;
}

sub warm_job {
    my ($job, $class) = @_;
    my $st = _plugin_state($class);
    my $q  = $job->queue_object;

    my $owner = 0 + $$;
    return { skipped => 'lock' }
        unless $q->lock('observe.warm', 60, owner => $owner);

    my $opt = $st->{warm_opts} || {};
    my $out = eval {
        run(db => $st->{db},
            store => sub { Punk::Plugin::Observe::store_for($st, $_[0]) },
            %$opt);
    };
    my $err = $@;
    $q->unlock('observe.warm', $owner) if $q->can('unlock');
    die $err if $err;
    return $out;
}

sub cron_task {
    my (%opt) = @_;
    my $db    = $opt{db};
    my $for   = $opt{store};
    my $owner = $opt{owner};
    $owner = $$ unless defined $owner && $owner =~ /\A[0-9]+\z/;
    my $lease = $opt{lease_seconds} || 30;

    return sub {
        my ($q) = @_;
        return 0 unless $q && $db && $for;
        return 0 unless $q->lock('leader', $lease, owner => $owner);

        my $out = eval { run(%opt, db => $db, store => $for) };
        my $err = $@;

        $q->renew_lock('leader', $owner, $lease);

        die $err if $err;
        return $out ? $out->{computed} : 0;
    };
}

1;

__END__

=head1 NAME

Punk::Observe::Warm - the settled chunks, computed where nobody is waiting

=head1 SYNOPSIS

    my $out = Punk::Observe::Warm::run(
        db    => $backend,
        store => sub { $stores{ $_[0] } },
    );

    printf "%d computed, %d already warm\n", $out->{computed}, $out->{hits};

=head1 DESCRIPTION

L<Punk::Observe::Cache> fills itself as a side effect of answering, which
means the first person to open a dashboard after a restart pays for the whole
window. This computes those entries in the background instead, so that the
request finds them already there.

It warms the queries saved on dashboards, per tenant, because those are the
queries that are re-run most and change least. Nothing else is warmed: an
explorer query is asked once, and the chunk it would leave behind is one
nobody comes back for.

=head2 One warm hour serves every range

A saved panel carries its own C<bucket(...)>, so its chunk width does not
change with the range picker and the entries for an hour are the same entries
whether the reader asked for the last hour or the last week. Warming a depth
once therefore serves every preset over it, and there is nothing to warm per
range.

=head2 What a pass costs, and what stops it

A pass is bounded twice, by a count of chunks computed and by a wall clock,
because the work is unbounded by nature - one chunk of a busy store is a real
scan, and a job that can run for ever can hold a queue worker for ever.

Neither bound can interrupt a scan already begun, so both are checked before
one starts, and before the entry being replaced is touched. A pass that stops
leaves the cache no colder than it found it and says which bound it hit; the
next pass walks the same way and continues from what the last one left.

The walk is B<newest first>. A pass that runs out should have spent what it
had on the hours somebody is about to ask for.

=head2 Freshness

Telemetry arrives late, so the newest settled chunks can still gain records
after they are first computed. Those are recomputed on every pass - two hours
of them by default - and everything older is filled only where it is missing.

The entries outlive the depth deliberately: an entry that expired while still
inside the window would be re-earned on a schedule rather than kept. The cost
is the one L<Punk::Observe::Cache> already names, widened: a record backfilled
into a chunk older than the refresh window, and one deleted by retention, are
not reflected until the entry expires.

=head1 FUNCTIONS

=head2 run

    my $out = Punk::Observe::Warm::run(%opt);

One pass. C<db> is the configuration backend and C<store> a code reference
returning the store for a tenant name. C<depth_ns>, C<refresh_ns>, C<ttl>,
C<budget> and C<timeout> override the defaults above, and C<now> is injectable
for a test.

Returns counts of C<tenants>, C<queries>, C<skipped>, C<chunks>, C<computed>,
C<hits>, C<failed> and C<unstorable>, plus C<stopped> naming the bound that
ended the pass or the empty string.

C<unstorable> is the one to watch. A value too large for the cache's own
budget is refused rather than stored, so those chunks are recomputed on every
pass and never kept - a cost that is otherwise invisible.

=head2 tenants

=head2 queries

    my $names = Punk::Observe::Warm::tenants($db);
    my $qs    = Punk::Observe::Warm::queries($db, $tenant);

The tenants that have dashboards, and one tenant's distinct panel queries.

=head2 warm_job

The L<Punk::Queue> task body, run under the C<observe.warm> lease.

=head2 cron_task

    my $code = Punk::Observe::Warm::cron_task(db => $db, store => $for);

The closure a host schedules when it declares its own cron rather than letting
the plugin register one. Takes the queue, runs one pass under the leader
lease, returns how many chunks were computed.

=head1 SEE ALSO

L<Punk::Observe::Cache>, L<Punk::Plugin::Observe>, L<Punk::Queue>

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
