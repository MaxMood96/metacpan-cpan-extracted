package Punk::Plugin::Observe;

use 5.010;
use strict;
use warnings;
use Carp ();

use Punk::Observe ();
use Punk::Observe::Ingest ();
use Punk::Observe::Store ();
use Punk::Observe::View ();
use Punk::Observe::Live ();
use Punk::Observe::Plot ();
use Punk::Observe::Segment ();   # the shared counter arena
use Punk::Observe::Tenant ();
use File::Raw::JSON ();
use File::Basename ();
use File::Spec ();

our $VERSION = $Punk::Observe::VERSION;

our $INSECURE_ENV = 'PUNK_OBSERVE_INSECURE';

my %ASSET_TYPE = (
    'observe.css'   => 'text/css',
    'brush.js'      => 'application/javascript',
    'waterfall.js'  => 'application/javascript',
    'flamegraph.js' => 'application/javascript',
    'livetail.js'   => 'application/javascript',
    'nsmath.js'     => 'application/javascript',
    'plot.js'       => 'application/javascript',
    'plotly.min.js' => 'application/javascript',
    'moment.min.js'      => 'application/javascript',
    'daterangepicker.js' => 'application/javascript',
    'daterangepicker.css' => 'text/css',
    'daterange.js'       => 'application/javascript',
);

sub register {
    my ($class, $app, $opts) = @_;
    $opts = {} unless ref $opts eq 'HASH';

    Carp::croak(
        "Punk::Plugin::Observe: a guard is required - "
      . "plugin 'Observe' => { guard => 'Web::Auth#observe_admin' }. "
      . "An unguarded mount serves every log line this application has "
      . "written to anybody who finds the prefix. Set $INSECURE_ENV to mean "
      . "it.")
        unless $opts->{guard} or $ENV{$INSECURE_ENV};

    my $prefix = $opts->{prefix};
    $prefix = '/observe' unless defined $prefix && length $prefix;
    $prefix =~ s{/\z}{};

    my $st = {
        app     => $app,
        opts    => $opts,
        prefix  => $prefix,
        store   => $opts->{store},
        tenant  => _tenant($opts),
        ingest  => _ingest($opts),
        limits  => _limits($opts),
        stores  => {},
    };
    $st->{arena} = _arena($st);

    _register_ui($st);
    _register_ingest($st);
    return $st;
}

# ---------------------------------------------------------------------------

sub _tenant {
    my ($opts) = @_;
    my $t = $opts->{tenant};

    return { fixed => 'default', resolver => undef }
        unless defined $t;
    return { fixed => 'default', resolver => $t } if ref $t eq 'CODE';

    my $chk = Punk::Observe::Tenant::check($t);
    Carp::croak("Punk::Plugin::Observe: tenant '$t' is not usable - "
              . $chk->{reason})
        unless $chk->{ok};
    return { fixed => $t, resolver => undef };
}

sub _ingest {
    my ($opts) = @_;
    my $i = $opts->{ingest};
    return undef unless $i;
    $i = {} unless ref $i eq 'HASH';

    my $prefix = $i->{prefix};
    $prefix = '/v1' unless defined $prefix && length $prefix;
    $prefix =~ s{/\z}{};

    return {
        prefix => $prefix,
        keys   => $i->{keys},
        scope  => 'ingest',
    };
}

sub _limits {
    my ($opts) = @_;
    my $l = $opts->{limits};
    $l = {} unless ref $l eq 'HASH';
    return {
        rate_records => $l->{rate_records} || 0,
        rate_bytes   => $l->{rate_bytes}   || 0,
        series       => defined $l->{series} ? $l->{series} : 1_000_000,
        storage      => $l->{storage} || 0,
        attributes   => $l->{attributes},
    };
}

sub _arena {
    my ($st) = @_;
    my $h = eval { Punk::Observe::Segment::shm_new($st->{limits}{series} || 0) };
    return undef unless defined $h;
    my $ok = eval { Punk::Observe::Segment::shm_stats($h) };
    return { handle => $h, shared => ($ok && $ok->{shared}) ? 1 : 0 };
}

# ---------------------------------------------------------------------------

sub _resolve_guard {
    my ($st) = @_;
    my $g = $st->{opts}{guard};
    return sub { return } unless $g;              # the documented escape
    return $g if ref $g eq 'CODE';
    my ($ctrl, $action) = split /#/, $g, 2;
    Carp::croak("Punk::Plugin::Observe: guard '$g' is not Controller#action")
        unless defined $ctrl && defined $action && length $action;
    return $g;
}

sub _register_ui {
    my ($st) = @_;
    my $app = $st->{app};
    my $guard = _resolve_guard($st);
    return unless $app && $app->can('under');
    my $scope = $app->under($st->{prefix} => $guard);
    $st->{scope} = $scope;

    _build_views($st);
    $scope->get('/'        => sub { _page($st, 'status',    $_[0]) });
    $scope->get('/status'  => sub { _page($st, 'status',    $_[0]) });
    $scope->get('/logs'    => sub { _page($st, 'logs',      $_[0]) });
    $scope->get('/metrics' => sub { _page($st, 'metrics',   $_[0]) });
    $scope->get('/map'     => sub { _page($st, 'map',       $_[0]) });
    $scope->get('/traces'  => sub { _page($st, 'trace',     $_[0]) });
    $scope->get('/explore' => sub { _page($st, 'explore',   $_[0]) });
    $scope->get('/alerts'  => sub { _page($st, 'alerts',    $_[0]) });
    $scope->get('/alerts/:id'     => sub { _page($st, 'alerts',    $_[0]) });
    $scope->get('/dashboards'     => sub { _page($st, 'dashboard', $_[0]) });
    $scope->get('/dashboards/:slug' => sub { _page($st, 'dashboard', $_[0]) });
    $scope->get('/dashboards/:slug/edit'
                                  => sub { _page($st, 'dashboard', $_[0]) });
    $scope->get('/logs/stream' => sub { _stream($st, $_[0]) });
    $scope->get('/logs/:id'      => sub { _page($st, 'record', $_[0]) });
    $scope->get('/traces/:trace' => sub { _page($st, 'trace',  $_[0]) });
    for my $asset (sort keys %ASSET_TYPE) {
        $scope->get("/assets/$asset" => sub { _asset($st, $_[0], $asset) });
    }
    $scope->get('/assets/favicon.svg' => sub { _favicon($st, $_[0]) });
    return $scope;
}


sub _root_dir {
    my $pm = $INC{'Punk/Plugin/Observe.pm'} or return undef;
    my $dir = File::Basename::dirname($pm);
    my @candidates = (File::Spec->catdir($dir, File::Spec->updir,
                                         'Observe', 'root'));
    my $up = $dir;
    for (1 .. 5) {
        $up = File::Spec->catdir($up, File::Spec->updir);
        push @candidates, File::Spec->catdir($up, 'root');
    }
    for my $c (@candidates) {
        return $c if -d File::Spec->catdir($c, 'templates');
    }
    return undef;
}

sub _build_views {
    my ($st) = @_;
    my $root = $st->{opts}{root} || _root_dir();
    $st->{root} = $root;
    return unless $root && eval { require Template::Stencil; 1 };
    $st->{stencil} = Template::Stencil->new({
        template_dir => File::Spec->catdir($root, 'templates'),
        wrapper      => 'layout.tmpl',
    });
    return $st->{stencil};
}

sub _empty {
    my ($st, $c) = @_;
    return (
        prefix => $st->{prefix}, query => '', title => '', heading => '',
        theme => '', toolbar => '', width => 720, height => 220,
        root_name => '', span_count => 0, duration_ms => 0, orphans => 0,
        cycles => 0, spans => [], rows => [], series => [], nodes => [],
        edges => [], yticks => [], back_edges => 0, error => '', hint => '',
        refusal => '', truncated => 0, scanned => 0, tail => 0,
        query_esc => '', from => '0', to => '0',
        rules => [], silences => [], broken => 0, panels => [], cols => 2,
        slug => '',
        ingest_rate => 0, wal_depth => 0, segments => 0, compaction_lag => 0,
        series_cap => $st->{limits}{series} || 0,
        mapped_deleted => 0,
        accepted => '0', accepted_bytes => '0 B',
        rate_rejected => '0', counters_shared => 1,

        # The read path's own empty state. Every one of these is a key some
        # template reads, and a template that dies on a missing key turns a
        # page with no data into a 500.
        groups => [], names => [], examples => [], traces => [], flame => [],
        attrs => [], context => [], services => [], columns => [],
        record => {}, found => 0, empty => 0, degraded => 0, exact => 1,
        offset => 0, shape => 'rows', total => 0, errors => 0,
        has_severity => 0, has_duration => 0, has_value => 0, has_trace => 0,
        errors_only => 0, min_ms => '', trace => '', flame_height => 0,
        logs => 0, metrics => 0, traces_seen => 0, store_bytes => '0 B',
        here_home => 0, here_map => 0, here_traces => 0, here_logs => 0,
        here_metrics => 0, here_explore => 0, here_alerts => 0,
        here_status => 0,
        range => '1h', range_all => 0, range_custom => 0, ranges => [],
        wants_range => 0, range_qs => '', range_amp => '',
    );
}

sub store_for {
    my ($st, $tenant) = @_;
    return undef unless defined $st->{store} && length $st->{store};
    $tenant = 'default' unless defined $tenant && length $tenant;
    return $st->{stores}{$tenant} ||= Punk::Observe::Store->new(
        dir        => $st->{store},
        tenant     => $tenant,
        seal_bytes => $st->{opts}{seal_bytes},
        max_rows   => $st->{opts}{max_rows},
    );
}

sub _request_tenant {
    my ($st, $c) = @_;
    my $t = eval {
        Punk::Observe::Tenant::resolve($st->{tenant}{fixed},
                                       $st->{tenant}{resolver});
    };
    return ($t && $t->{ok}) ? $t->{tenant} : 'default';
}


sub _params {
    my ($st, $c) = @_;
    my %p;
    for my $k (qw(q from to range errors min_ms service id trace slug)) {
        my $v = eval { $c->param($k) };
        $p{$k} = $v if defined $v && length $v;
    }
    $p{alerts}     = $st->{opts}{alerts}     if $st->{opts}{alerts};
    $p{dashboards} = $st->{opts}{dashboards} if $st->{opts}{dashboards};
    return \%p;
}

sub _range_qs {
    my ($req, $lead) = @_;
    $lead = '?' unless defined $lead;
    if (defined $req->{from} && length $req->{from}
        && defined $req->{to} && length $req->{to}) {
        return $lead . 'from=' . _uri_esc($req->{from})
             . '&to=' . _uri_esc($req->{to});
    }
    return $lead . 'range=' . _uri_esc($req->{range})
        if defined $req->{range} && length $req->{range};
    return '';
}

sub _uri_esc {
    my ($v) = @_;
    $v = '' unless defined $v;
    $v =~ s/([^A-Za-z0-9_.~-])/sprintf('%%%02X', ord $1)/ge;
    return $v;
}

sub _page {
    my ($st, $name, $c) = @_;
    return $c->status(501)->text("Template::Stencil is not installed\n")
        unless $st->{stencil};

    my %vars = _empty($st, $c);
    my $req  = _params($st, $c);
    my $store = store_for($st, _request_tenant($st, $c));
    my $built = eval { Punk::Observe::View->page($store, $name, $req) };
    if ($@) {
        $vars{error} = 'That screen could not be built from the store.';
        $vars{hint}  = "$@";
    }
    elsif (ref $built eq 'HASH') {
        %vars = (%vars, %$built);
    }
    $vars{heading} = ucfirst $name unless length($vars{heading} || '');
    $vars{range_qs}  = _range_qs($req, '?');
    $vars{range_amp} = _range_qs($req, '&');

    if ($name eq 'status' && $store) {
        my $s = eval { $store->stats } || {};
        my $fig = Punk::Observe::Plot::gauge(
            value => $s->{bytes} || 0,
            max   => $st->{limits}{storage} || 0,
            title => 'bytes on disk');
        $vars{storage_gauge_plot} = Punk::Observe::Plot::encode($fig) if $fig;

        my $now = Punk::Observe::now_ns();
        $vars{ingest_plot} = Punk::Observe::Plot::ingest_figure(
            $store, Punk::Observe::Store::nsub($now, 3_600 * 1_000_000_000), $now);

        my $c = $st->{arena}
              ? eval { Punk::Observe::Segment::shm_stats($st->{arena}{handle}) }
              : undef;
        if ($c) {
            $vars{accepted}       = Punk::Observe::View::fmt_count($c->{records});
            $vars{accepted_bytes} = Punk::Observe::View::fmt_bytes($c->{bytes});
            $vars{rate_rejected}  = Punk::Observe::View::fmt_count($c->{rate_rejected});
            $vars{counters_shared} = $c->{shared} ? 1 : 0;
        }
    }


    $vars{wants_plot} = (grep { /_plot\z/ && defined $vars{$_} && length $vars{$_} }
                         keys %vars) ? 1 : 0;

    if (my $cb = $st->{opts}{stats}) {
        my $extra = eval { $cb->($c, $name, $store) };
        %vars = (%vars, %$extra) if ref $extra eq 'HASH';
    }

    my $tmpl = "$name.tmpl";
    my $html = eval { $st->{stencil}->render($tmpl, \%vars) };
    return $c->status(500)->text("render failed: $@") if $@;
    return $c->html($html);
}

sub _stream {
    my ($st, $c) = @_;
    my $store = store_for($st, _request_tenant($st, $c));

    $c->header('Content-Type'      => 'text/event-stream');
    $c->header('Cache-Control'     => 'no-cache');
    $c->header('X-Accel-Buffering' => 'no');   # or a proxy buffers the stream

    my $req = _params($st, $c);
    my $q = $req->{q};
    $q = 'log' unless defined $q && $q =~ /\S/;

    my $since = eval { $c->param('since') };
    $since = eval { $c->req->header('Last-Event-ID') } unless defined $since;
    $since = undef unless defined $since && $since =~ /\A\d+\z/ && $since > 0;

    my $body = sprintf("retry: %d\n\n", 2000);
    if ($store) {
        my $r = eval { $store->query($q, limit => 200) } || {};
        my @rows = reverse @{ $r->{rows} || [] };
        if (defined $since) {
            @rows = grep { Punk::Observe::Store::ncmp($_->{t}, $since) > 0 } @rows;
        }
        elsif (@rows > 50) {
            splice @rows, 0, @rows - 50;
        }
        for my $row (@rows) {
            $body .= Punk::Observe::Live::sse($row->{t}, 'log',
                                              _tail_json($row));
        }
    }
    $body .= Punk::Observe::Live::heartbeat();
    return $c->text($body);
}

sub _tail_json {
    my ($row) = @_;
    return '{' . join(',', map { _json_pair(@$_) }
        [ 'id',       Punk::Observe::View::record_id($row) ],
        [ 'time',     Punk::Observe::View::fmt_time($row->{t}) ],
        [ 'sev_name', Punk::Observe::View::severity_name($row->{severity}) ],
        [ 'service',  (defined $row->{service} ? $row->{service} : '') ],
        [ 'body',     (defined $row->{body}    ? $row->{body}    : '') ],
    ) . '}';
}

sub _json_pair {
    my ($k, $v) = @_;
    $v = '' unless defined $v;
    $v =~ s/([\\"])/\\$1/g;
    $v =~ s/([\x00-\x1f])/sprintf('\\u%04x', ord $1)/ge;
    return "\"$k\":\"$v\"";
}

sub _asset {
    my ($st, $c, $name) = @_;
    $name = 'observe.css' unless defined $name && $ASSET_TYPE{$name};
    my $path = File::Spec->catfile($st->{root} || '', 'static', $name);
    return $c->status(404)->text("no such asset\n") unless -f $path;

    my $enc;
    my $ae = eval { $c->req->header('Accept-Encoding') };
    if (defined $ae && $ae =~ /\bgzip\b/ && -f "$path.gz") {
        $path .= '.gz';
        $enc = 'gzip';
    }

    $c->header('Vary' => 'Accept-Encoding');
    $c->header('Content-Encoding' => $enc) if $enc;

    return $c->send_file($path,
        type          => $ASSET_TYPE{$name},
        cache_control => 'no-cache',
        missing       => 'not_found');
}

my $FAVICON = <<'SVG';
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
<rect width="32" height="32" rx="7" fill="#151821"/>
<path d="M4 21 L10 21 L13 11 L17 25 L20 17 L23 17"
      fill="none" stroke="#6ee7b7" stroke-width="2.5"
      stroke-linecap="round" stroke-linejoin="round"/>
<circle cx="26" cy="9" r="3.5" fill="#f87171"/>
</svg>
SVG

sub _favicon {
    my ($st, $c) = @_;
    $st->{favicon_etag} //= sprintf('"%08x"', length($FAVICON) ^ 0x5f5f5f5f);
    my $inm = eval { $c->req->header('If-None-Match') } || '';
    return $c->status(304)->text('') if $inm eq $st->{favicon_etag};
    $c->header('Content-Type'  => 'image/svg+xml');
    $c->header('ETag'          => $st->{favicon_etag});
    $c->header('Cache-Control' => 'public, max-age=86400');
    return $c->text($FAVICON);
}

sub _register_ingest {
    my ($st) = @_;
    my $i = $st->{ingest} or return;
    my $app = $st->{app};

    my $keys = _keyring($st);
    my $store = $st->{store};

    my $recv = Punk::Observe::Ingest->new(
        max_body => $i->{max_body},
        auth     => sub {
            my ($env) = @_;
            return undef unless _key_ok($keys, $env);
            my $t = Punk::Observe::Tenant::resolve(
                        $st->{tenant}{fixed}, $st->{tenant}{resolver});
            return $t->{ok} ? $t->{tenant} : undef;
        },
        on_batch => sub {
            my ($tenant, $signal, $body, $encoding, $out) = @_;
            return _persist($st, $tenant, $signal, $body, $encoding, $out);
        },
    );

    $st->{receiver} = $recv;
    my $inner = $recv->to_app;
    $st->{ingest_app} = sub {
        my ($env) = @_;
        local $env->{PATH_INFO} = '/v1' . ($env->{PATH_INFO} // '');
        return $inner->($env);
    };

    return unless $app && $app->can('mount');
    $app->mount($i->{prefix} => $st->{ingest_app});
    return $st->{ingest_app};
}

sub _keyring {
    my ($st) = @_;
    my $path = $st->{ingest}{keys};
    return undef unless defined $path && length $path;

    open my $fh, '<', $path
        or Carp::croak("Punk::Plugin::Observe: cannot read key file $path: $!");
    my @pairs;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^\s*(?:#|$)/;
        my ($name, $token) = split /\s+/, $line, 2;
        next unless defined $token && length $token;
        push @pairs, $name, $token;
    }
    close $fh;
    return \@pairs;
}

sub _key_ok {
    my ($keys, $env) = @_;
    return 1 unless $keys && @$keys;      # configured open, deliberately
    my $r = Punk::Observe::Key::check($keys, $env->{HTTP_AUTHORIZATION}, undef);
    return $r->{ok} ? 1 : 0;
}

sub _persist {
    my ($st, $tenant, $signal, $body, $encoding, $out) = @_;

    my $json = ($encoding || '') eq 'json';
    my $doc  = $body;
    if ($json) {
        $doc = eval { File::Raw::JSON::file_json_decode($body) };
        return 0 unless $doc;
    }

    my $want = $st->{opts}{on_records} ? 1 : 0;
    my $store = store_for($st, $tenant);
    my $path  = $store ? $store->wal_path : '';

    my $r = eval {
        Punk::Observe::Ingest::decode_append(
            $path, $doc, $signal, $json ? 'json' : 'protobuf',
            1, '200000000', $want,
            $st->{arena} ? $st->{arena}{handle} : 0,
            $st->{limits}{rate_records} || 0,
            $st->{limits}{rate_bytes}   || 0);
    };
    if (!$r) {
        warn "Punk::Plugin::Observe: ingest failed: $@" if $@;
        return 0;
    }

    return 0 unless $r->{ok};

    if ($want && $r->{records}) {
        eval { $st->{opts}{on_records}->($tenant, $signal, $r->{records}) };
    }

    if (!$r->{appended}) {
        warn "Punk::Plugin::Observe: WAL append failed: $r->{errno}\n"
            if $r->{errno};
        return 0;
    }

    $st->{written} += $r->{n};

    $out->{rejected} = ($out->{rejected} || 0) + $r->{rejected}
        if ref $out eq 'HASH' && $r->{rejected};

    $store->seal_if_full($r->{bytes} || 0) if $store;
    return 1;
}

1;

__END__

=head1 NAME

Punk::Plugin::Observe - mount Punk::Observe in a Punk application

=head1 SYNOPSIS

    plugin 'Observe' => {
        prefix => '/observe',
        guard  => 'Web::Auth#observe_admin',       # required
        store  => '/var/lib/punk-observe',
        ingest => { prefix => '/v1', keys => '/etc/punk-observe/keys' },
        limits => { series => 1_000_000, rate_records => 50_000 },
    };

=head1 DESCRIPTION

Mounts the observability UI under a B<guarded scope> and, optionally, the
OTLP ingest endpoint beside it.

=head2 The guard is not optional

Registration croaks without one.

An unguarded mount is every log line the application has ever written, served
to anybody who finds the prefix. A loud failure at boot beats a silent hole
that nobody notices, so the failure is at registration rather than at the
first request.

Setting C<PUNK_OBSERVE_INSECURE> is the deliberate escape, named for this
distribution so that meaning it is possible and doing it by accident is not.

The UI is registered as an C<under> scope rather than a C<mount>. Under a
scope the guard covers every path beneath it including ones added later; a
mount with a guard on each route is the same thing right up until somebody
adds a route and forgets, and the failure mode of forgetting is an
unauthenticated page.

=head2 Ingest is a separate scope, in both directions

The ingest prefix sits outside the UI scope on purpose.

It is authenticated by B<key> and not by the UI guard, because an exporter
has no session. It is CSRF-exempt, because an exporter has no form token.

Both directions are bugs. A UI route that became CSRF-exempt by sharing this
scope would be a security hole; an ingest route that required a form token
would return 403 to every exporter in the world with a message about forms.

An ingest key cannot read the UI. There is no option to widen it: a key that
could do both leaks a whole installation the first time it is baked into a
container image, which is where ingest keys go.

=head2 Options

=over 4

=item C<prefix>

Where the UI mounts. Defaults to C</observe>.

=item C<guard>

Required. A coderef, or C<'Controller#action'>.

=item C<store>

The store root. Every path this distribution builds is rooted here.

=item C<tenant>

A constant tenant id, or a coderef resolving one. B<Defaults to a constant>,
so the self-hosted shape is the whole shape and the hosted one is a callback
through the same code. Whatever a resolver returns is validated before a byte
of it reaches a path - a resolver is host code, and host code that returns
C<../other> is a bug to catch rather than a value to trust.

A tenant id is never taken from anything a client sends.

=item C<ingest>

C<< { prefix => '/v1', keys => $path } >>. Omit it and no ingest endpoint is
registered at all.

=item C<limits>

C<rate_records> and C<rate_bytes> per second, C<series> for cardinality,
C<storage> in bytes, and C<attributes> for the indexed-attribute allowlist.

The rate limit is B<off> unless configured: a default rate limit on a
self-hosted box is a surprise in the wrong direction. The cardinality limit
B<has> a default, because a store with no cardinality limit is a store
waiting for one bad deploy.

C<rate_records> and C<rate_bytes> truncate the batch B<before it reaches the
log> and answer with an OTLP partial success naming what was dropped. That
ordering is the contract: a partial success means "I did not keep these", so
an exporter resending what it was told was rejected must not find those
records already stored.

The counters behind all of this live in a small shared page mapped at
registration, which is B<before the fork>. One mapped afterwards would be
private per worker, and the symptom is not a crash - it is a rate limit N
times what was configured and a status page showing whichever shard of the
traffic answered the request. Where the platform cannot share one, the status
page says so rather than presenting a fraction as a total.

=item C<limits> and what the status page can show

Two record counts appear on the status page and they answer different
questions. B<accepted> is what arrived, counted at ingest; B<records> is what
the store still holds. Retention makes the second smaller over time and a
limit makes it smaller immediately, so a gap between them is not an error.

The store cannot report the first. Refused data never reaches it, so a
receiver throwing every batch away and a receiver being sent nothing have
identical stored totals.

=item C<alerts>

A reader for the alert rules, as a hashref or a coderef returning one. Rules
are configuration with an owner, a review and a history, so they live in the
application's database rather than in a telemetry store that retention deletes
from. F<sqitch/> ships the schema.

    alerts => sub {
        # ONE argument, and it is the request - not ($id, $req). The
        # dashboards seam below takes its slug first; this one does not, and
        # reading it that way binds the request hashref to $id.
        my ($req) = @_;             # $req->{id} on /observe/alerts/:id
        return {
            rules    => [ { id, name, series, state, value, held } ],
            silences => [ { pattern, until, by, reason } ],
            events   => [ { series, to, at } ],     # optional
            can_edit => 1,
            to       => $now_ns,                    # optional
        };
    };

C<state> is one of C<ok>, C<pending>, C<firing>, C<stale> or C<error>, per
series rather than per rule - one state for a whole rule is the bug that makes
an alert resolve because a B<different> service recovered.

B<C<held> and C<value> are numbers, and the screen formats them.> C<held> is
how long the series has been in its current state, in B<nanoseconds>, rendered
as a duration; C<value> is the number the rule last compared, rendered with
C<%.4g> and no unit. A pre-formatted string does not survive either: C<"2m30s">
is read as the number 2 and drawn as two nanoseconds. A latency is therefore
worth converting to milliseconds before it is handed over, since nanoseconds
under C<%.4g> come out as C<2.911e+09>.

C<events> is the state history, and the screen draws a timeline from it. Each
entry is a transition: the series, the state it moved C<to>, and the instant
C<at> which it did, as nanoseconds. That is a row of C<alert_events> in the
shipped schema. Supply it and the timeline appears; omit it and the screen is
the table alone.

B<The timeline is drawn only from recorded transitions.> One inferred from
current state would be a straight line claiming the present has always been
the case - which is exactly the question a reader opens it to answer, so
answering it wrongly is worse than not answering it.

C<to> is where the timeline's right edge sits, defaulting to now. The last
band runs to it, because a state nobody has left is still in force.

=item C<dashboards>

The same shape for dashboards: a hashref or a coderef taking a slug, returning
C<title>, C<cols>, C<panels> and a C<list> of the others. A panel is an OQL
string with a title, validated at save time by the parser that will run it.

=back

=head2 What each limit does at its cap

They fail three different ways, and treating them as one limit is the
mistake:

=over 4

=item Ingest rate

Returns an OTLP B<partial success naming the rejected count>, never a bare
429. A 429 makes the exporter re-send the whole batch, forever, at the moment
the server is already under pressure - the limit becomes an amplifier.

The limiter covers the ingest prefix and nothing else. Rate-limiting a health
endpoint takes the box out of a load balancer under exactly the load the
limiter exists for.

=item Cardinality

The B<new> series is dropped, counted, and surfaced. An existing series is
never evicted to admit a new one: that converts a cardinality problem into
data loss on the exact series somebody has open in a dashboard.

The counter lives in an arena mapped B<before> the fork, so the limit is per
pool. One mapped afterwards is private per worker, and the symptom is a limit
silently N times what was configured.

=item Storage bytes

The retention job B<shortens retention>. Writes are never refused. A store
over its byte budget should lose old data; it must not lose the incident
happening now.

=back

=head2 The allowlist matters more than any of the numbers

Logs and spans carry unbounded attributes, and only the configured set
becomes an index dimension. The rest stay in the record and are reachable by
a residual filter, so nothing is lost - it is just slower to find.

Without it, one service putting a request id in a resource attribute takes
the store down. The overflow counter B<names the attribute>, because the
person who hits this first is a self-hoster with no support contract and no
dashboard telling them which one did it.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Tenant>, L<Punk::Observe::Key>,
L<Punk::Observe::Limit>

=cut
