package Punk::Observe::Config;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();
use Punk::Observe::Dashboard ();
use Punk::Observe::Query ();
use Punk::Observe::Store ();
use Punk::Observe::View ();
use Punk::Observe::Target ();

our $VERSION = $Punk::Observe::VERSION;

sub ok      { return { ok => 1, id => $_[0] } }

sub refused { return { ok => 0, refused => 1, error => $_[0], field => $_[1] } }
sub failed  { my $e = $_[0]; $e =~ s/\s+\z//; return { ok => 0, error => $e } }

sub _guard {
    my ($code) = @_;
    my @r = eval { $code->() };
    return failed($@ || 'the configuration store did not say why') if $@;
    return wantarray ? @r : $r[0];
}

sub dashboards {
    my ($db, $tenant, $slug) = @_;
    my $dbh = $db->dbh;

    my $list = $dbh->selectall_arrayref(
        'SELECT slug, title FROM dashboards WHERE tenant = ? ORDER BY title',
        { Slice => {} }, $tenant);

    $slug = $list->[0]{slug} if (!defined $slug || !length $slug) && @$list;
    return { list => $list, panels => [], cols => 2, can_edit => 1,
             title => 'Dashboards' }
        unless defined $slug && length $slug;

    my $d = $dbh->selectrow_hashref(
        'SELECT id, slug, title, cols FROM dashboards
          WHERE tenant = ? AND slug = ?', undef, $tenant, $slug);
    return { list => $list, panels => [], cols => 2, can_edit => 1,
             title => $slug, missing => 1 }
        unless $d;

    my $panels = $dbh->selectall_arrayref(
        'SELECT id, position, title, query, viz, span
           FROM dashboard_panels WHERE dashboard_id = ? ORDER BY position, id',
        { Slice => {} }, $d->{id});

    my %known = map { $_ => 1 } Punk::Observe::Dashboard::viz_names();
    for my $p (@$panels) {
        $p->{viz_unknown} = 1
            if defined $p->{viz} && length $p->{viz} && !$known{ $p->{viz} };
    }

    return {
        id => $d->{id}, slug => $d->{slug}, title => $d->{title},
        cols => $d->{cols}, list => $list, panels => $panels, can_edit => 1,
    };
}

sub save_dashboard {
    my ($db, $tenant, $in) = @_;
    my $slug = defined $in->{slug} ? $in->{slug} : '';
    return refused('a dashboard needs a slug', 'slug') unless length $slug;
    return refused('a slug is letters, digits, dash and underscore', 'slug')
        if $slug =~ /[^A-Za-z0-9_-]/;
    return refused('a dashboard needs a title', 'title')
        unless defined $in->{title} && length $in->{title};

    my $cols = int($in->{cols} || 2);
    $cols = 1 if $cols < 1;
    $cols = 6 if $cols > 6;

    return _guard(sub {
        my $dbh = $db->dbh;
        my $now = time;
        my ($id) = $dbh->selectrow_array(
            'SELECT id FROM dashboards WHERE tenant = ? AND slug = ?',
            undef, $tenant, $slug);
        if ($id) {
            $dbh->do('UPDATE dashboards SET title = ?, cols = ?, updated_at = ?
                       WHERE id = ?', undef, $in->{title}, $cols, $now, $id);
        }
        else {
            $dbh->do('INSERT INTO dashboards
                        (tenant, slug, title, cols, created_at, updated_at)
                      VALUES (?, ?, ?, ?, ?, ?)',
                     undef, $tenant, $slug, $in->{title}, $cols, $now, $now);
            ($id) = $dbh->selectrow_array(
                'SELECT id FROM dashboards WHERE tenant = ? AND slug = ?',
                undef, $tenant, $slug);
        }
        return ok($id);
    });
}

sub delete_dashboard {
    my ($db, $tenant, $slug) = @_;
    return refused('a dashboard needs a slug')
        unless defined $slug && length $slug;
    return _guard(sub {
        my $n = $db->dbh->do('DELETE FROM dashboards WHERE tenant = ? AND slug = ?',
                             undef, $tenant, $slug);
        return $n && $n != 0 ? ok(undef) : refused('no such dashboard');
    });
}

sub save_panel {
    my ($db, $tenant, $slug, $in) = @_;

    my $chk = Punk::Observe::Dashboard::check_panel({
        title    => $in->{title},
        query    => $in->{query},
        viz      => (defined $in->{viz} && length $in->{viz})
                    ? $in->{viz} : 'line',
        position => $in->{position} || 0,
        span     => $in->{span} || 1,
    });
    unless ($chk->{ok}) {
        my $f = ($chk->{code} || 0) == 3 || ($chk->{code} || 0) == 4
              ? 'title' : 'query';
        return refused($chk->{error} || 'that panel is not valid', $f);
    }

    return _guard(sub {
        my $dbh = $db->dbh;
        my ($did) = $dbh->selectrow_array(
            'SELECT id FROM dashboards WHERE tenant = ? AND slug = ?',
            undef, $tenant, $slug);
        return refused('no such dashboard') unless $did;

        my $span = int($in->{span} || 1);
        $span = 1 if $span < 1;
        $span = 6 if $span > 6;
        my $pos = int($in->{position} || 0);
        $pos = 0 if $pos < 0;

        if (my $id = $in->{id}) {
            my $n = $dbh->do(
                'UPDATE dashboard_panels
                    SET position = ?, title = ?, query = ?, viz = ?, span = ?
                  WHERE id = ? AND dashboard_id = ?',
                undef, $pos, $in->{title}, $in->{query}, $chk->{viz}, $span,
                $id, $did);
            return refused('no such panel') unless $n && $n != 0;
            return ok($id);
        }
        $dbh->do('INSERT INTO dashboard_panels
                    (dashboard_id, position, title, query, viz, span)
                  VALUES (?, ?, ?, ?, ?, ?)',
                 undef, $did, $pos, $in->{title}, $in->{query}, $chk->{viz},
                 $span);
        return ok(undef);
    });
}

sub save_panels {
    my ($db, $tenant, $slug, $rows) = @_;

    my @checked;
    for my $in (@$rows) {
        my $chk = Punk::Observe::Dashboard::check_panel({
            title    => $in->{title},
            query    => $in->{query},
            viz      => (defined $in->{viz} && length $in->{viz})
                        ? $in->{viz} : 'line',
            position => $in->{position} || 0,
            span     => $in->{span} || 1,
        });
        unless ($chk->{ok}) {
            my $f = ($chk->{code} || 0) == 3 || ($chk->{code} || 0) == 4
                  ? 'title' : 'query';
            my $name = (defined $in->{title} && length $in->{title})
                     ? "'$in->{title}'" : "panel $in->{id}";
            return refused(($chk->{error} || 'that panel is not valid')
                           . " - in $name", $f);
        }
        push @checked, [ $in, $chk ];
    }

    return _guard(sub {
        my $dbh = $db->dbh;
        my ($did) = $dbh->selectrow_array(
            'SELECT id FROM dashboards WHERE tenant = ? AND slug = ?',
            undef, $tenant, $slug);
        return refused('no such dashboard') unless $did;
        return ok(undef) unless @checked;

        $dbh->begin_work;
        for my $c2 (@checked) {
            my ($in, $chk) = @$c2;
            my $span = int($in->{span} || 1);
            $span = 1 if $span < 1;
            $span = 6 if $span > 6;
            my $pos = int($in->{position} || 0);
            $pos = 0 if $pos < 0;
            my $n = eval { $dbh->do(
                'UPDATE dashboard_panels
                    SET position = ?, title = ?, query = ?, viz = ?, span = ?
                  WHERE id = ? AND dashboard_id = ?',
                undef, $pos, $in->{title}, $in->{query}, $chk->{viz}, $span,
                $in->{id}, $did) };
            unless ($n && $n != 0) {
                my $e = $@;
                eval { $dbh->rollback };
                return $e ? failed($e)
                          : refused("panel $in->{id} no longer exists");
            }
        }
        $dbh->commit;
        return ok(undef);
    });
}

sub delete_panel {
    my ($db, $tenant, $slug, $id) = @_;
    return refused('a panel needs an id') unless $id;
    return _guard(sub {
        my $n = $db->dbh->do(
            'DELETE FROM dashboard_panels
              WHERE id = ? AND dashboard_id IN
                    (SELECT id FROM dashboards WHERE tenant = ? AND slug = ?)',
            undef, $id, $tenant, $slug);
        return $n && $n != 0 ? ok(undef) : refused('no such panel');
    });
}

sub health_targets {
    my ($db, $tenant, $name) = @_;
    return _guard(sub {
        my $sql = 'SELECT * FROM health_targets WHERE tenant = ?';
        my @bind = ($tenant);
        if (defined $name && length $name) { $sql .= ' AND name = ?'; push @bind, $name }
        $sql .= ' ORDER BY name';
        return $db->dbh->selectall_arrayref($sql, { Slice => {} }, @bind);
    });
}

sub save_health_target {
    my ($db, $tenant, $in, $allow) = @_;
    my $name = defined $in->{name} ? $in->{name} : '';
    return refused('a target needs a name') unless length $name;
    return refused('a name is letters, digits, dash and underscore')
        if $name =~ /[^A-Za-z0-9_-]/;

    my $url = defined $in->{url} ? $in->{url} : '';
    return refused('a target needs a URL') unless length $url;

    my $t = Punk::Observe::Target::check($url, $allow);
    unless ($t->{ok}) {
        my $why = $t->{reason} || 'that URL is refused';
        $why .= $allow && @$allow
              ? '. It is not in the allowlist this installation was given.'
              : '. Set an allowlist if this host is meant to be polled.';
        return refused($why);
    }

    my $every = int($in->{every_ns} || 60_000_000_000);
    $every = 10_000_000_000 if $every < 10_000_000_000;
    my $tmo = int($in->{timeout_ms} || 5000);
    $tmo = 100   if $tmo < 100;
    $tmo = 60000 if $tmo > 60000;

    my $enabled = exists $in->{enabled} ? ($in->{enabled} ? 1 : 0) : 1;

    return _guard(sub {
        my $dbh = $db->dbh;
        my ($id) = $dbh->selectrow_array(
            'SELECT id FROM health_targets WHERE tenant = ? AND name = ?',
            undef, $tenant, $name);
        if ($id) {
            $dbh->do('UPDATE health_targets
                         SET url = ?, every_ns = ?, timeout_ms = ?, enabled = ?
                       WHERE id = ?',
                     undef, $url, $every, $tmo, $enabled, $id);
        }
        else {
            $dbh->do('INSERT INTO health_targets
                        (tenant, name, url, every_ns, timeout_ms, enabled, created_at)
                      VALUES (?, ?, ?, ?, ?, ?, ?)',
                     undef, $tenant, $name, $url, $every, $tmo, $enabled, time);
            ($id) = $dbh->selectrow_array(
                'SELECT id FROM health_targets WHERE tenant = ? AND name = ?',
                undef, $tenant, $name);
        }
        return ok($id);
    });
}

sub delete_health_target {
    my ($db, $tenant, $name) = @_;
    return refused('a target needs a name') unless defined $name && length $name;
    return _guard(sub {
        my $n = $db->dbh->do(
            'DELETE FROM health_targets WHERE tenant = ? AND name = ?',
            undef, $tenant, $name);
        return $n && $n != 0 ? ok(undef) : refused('no such target');
    });
}

my @VIEW_PARAMS = qw(q from to range errors min_ms service);

sub _view_qs {
    my ($in) = @_;
    my @pair;
    for my $k (@VIEW_PARAMS) {
        my $v = $in->{$k};
        next unless defined $v && length $v;
        push @pair, join '=', $k, _esc($v);
    }
    return join '&', @pair;
}

sub _esc {
    my ($v) = @_;
    $v =~ s/([^A-Za-z0-9_.~-])/sprintf('%%%02X', ord $1)/ge;
    return $v;
}

sub _unesc {
    my ($v) = @_;
    $v =~ tr/+/ /;
    $v =~ s/%([0-9A-Fa-f]{2})/chr hex $1/ge;
    return $v;
}

sub _view_parts {
    my ($qs) = @_;
    my %p;
    for my $pair (split /&/, $qs // '') {
        my ($k, $v) = split /=/, $pair, 2;
        next unless defined $k && length $k;
        $p{$k} = _unesc(defined $v ? $v : '');
    }
    return \%p;
}

sub saved_views {
    my ($db, $tenant, $page) = @_;
    return _guard(sub {
        my $rows = $db->dbh->selectall_arrayref(
            'SELECT id, page, name, params FROM saved_views
              WHERE tenant = ?' . (defined $page && length $page
                                   ? ' AND page = ?' : '') . ' ORDER BY name',
            { Slice => {} }, $tenant,
            (defined $page && length $page ? ($page) : ()));

        for my $r (@$rows) {
            my $p = _view_parts($r->{params});
            $r->{query} = $p->{q};
            $r->{frozen} = ($p->{from} && $p->{to}) ? 1 : 0;
            $r->{window} = $r->{frozen} ? 'a fixed window'
                         : ($p->{range} || 'the default window');
        }
        return $rows;
    });
}

sub save_view {
    my ($db, $tenant, $in) = @_;
    my $name = defined $in->{name} ? $in->{name} : '';
    return refused('a view needs a name', 'name') unless length $name;
    return refused('that name is too long', 'name') if length $name > 80;

    my $page = defined $in->{page} ? $in->{page} : '';
    return refused('a view needs a page', 'page') unless length $page;
    return refused('there is no such screen', 'page')
        if $page =~ /[^a-z]/;

    if (defined $in->{q} && length $in->{q}) {
        my $chk = Punk::Observe::Dashboard::check_panel({
            title => $name, query => $in->{q}, viz => 'table',
            position => 0, span => 1 });
        return refused($chk->{error} || 'that query is not valid', 'q')
            unless $chk->{ok};
    }

    my $qs = _view_qs($in);
    return refused('there is nothing to save on this view', 'q')
        unless length $qs;

    return _guard(sub {
        my $dbh = $db->dbh;
        my ($id) = $dbh->selectrow_array(
            'SELECT id FROM saved_views WHERE tenant = ? AND page = ? AND name = ?',
            undef, $tenant, $page, $name);
        if ($id) {
            $dbh->do('UPDATE saved_views SET params = ? WHERE id = ?',
                     undef, $qs, $id);
        }
        else {
            $dbh->do('INSERT INTO saved_views (tenant, page, name, params, created_at)
                      VALUES (?, ?, ?, ?, ?)',
                     undef, $tenant, $page, $name, $qs, time);
            ($id) = $dbh->selectrow_array(
                'SELECT id FROM saved_views WHERE tenant = ? AND page = ? AND name = ?',
                undef, $tenant, $page, $name);
        }
        return ok($id);
    });
}

sub delete_view {
    my ($db, $tenant, $id) = @_;
    return refused('a view needs an id') unless $id;
    return _guard(sub {
        my $n = $db->dbh->do('DELETE FROM saved_views WHERE id = ? AND tenant = ?',
                             undef, $id, $tenant);
        return $n && $n != 0 ? ok(undef) : refused('no such view');
    });
}

my %ALERT_OP = map { $_ => 1 } qw(> >= < <= == !=);

sub alert {
    my ($db, $tenant, $id) = @_;
    return undef unless $id;
    return $db->dbh->selectrow_hashref(
        'SELECT id, name, query, op, threshold, for_ns, every_ns, enabled
           FROM alert_rules WHERE tenant = ? AND id = ?',
        undef, $tenant, $id);
}

sub save_alert {
    my ($db, $tenant, $in) = @_;

    my $name = defined $in->{name} ? $in->{name} : '';
    $name =~ s/\A\s+|\s+\z//g;
    return refused('a rule needs a name', 'name') unless length $name;
    return refused('a rule name is at most 128 characters', 'name')
        if length($name) > 128;
    return refused('a rule name cannot contain control characters or "/"',
                   'name') if $name =~ m{[[:cntrl:]/]};

    my $q = defined $in->{query} ? $in->{query} : '';
    return refused('a rule needs a query', 'query') unless $q =~ /\S/;
    my $p = Punk::Observe::Query::parse($q);
    return refused("that query does not parse: $p->{error}", 'query')
        unless $p->{ok};
    return refused('an alert rule needs a bucketed query - '
                 . 'add `| bucket(30s) <aggregate>` or `| rate(30s)`', 'query')
        unless grep { $_->{kind} eq 'bucket' || $_->{kind} eq 'rate' }
               @{ $p->{stages} || [] };

    my $op = defined $in->{op} ? $in->{op} : '';
    return refused('the operator is one of > >= < <= == !=', 'op')
        unless $ALERT_OP{$op};

    my $threshold = defined $in->{threshold} ? $in->{threshold} : '';
    return refused('the threshold is a number', 'threshold')
        unless $threshold =~ /\A-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?\z/;

    my ($for_ns, $every_ns) = (0, 60_000_000_000);
    if (defined $in->{for} && $in->{for} =~ /\S/) {
        my ($ns) = Punk::Observe::View::min_duration($in->{for});
        return refused("'$in->{for}' is not a duration - try 30s, 5m",
                       'for') unless defined $ns;
        $for_ns = $ns;
    }
    if (defined $in->{every} && $in->{every} =~ /\S/) {
        my ($ns) = Punk::Observe::View::min_duration($in->{every});
        return refused("'$in->{every}' is not a duration - try 30s, 5m",
                       'every') unless defined $ns;
        $ns = 10_000_000_000 if $ns < 10_000_000_000;
        $every_ns = $ns;
    }

    my $enabled = exists $in->{enabled} ? ($in->{enabled} ? 1 : 0) : 1;

    return _guard(sub {
        my $dbh = $db->dbh;
        my $id = $in->{id};
        if ($id) {
            my $n = $dbh->do(
                'UPDATE alert_rules
                    SET name = ?, query = ?, op = ?, threshold = ?,
                        for_ns = ?, every_ns = ?, enabled = ?, next_eval_at = 0
                  WHERE id = ? AND tenant = ?',
                undef, $name, $q, $op, $threshold, $for_ns, $every_ns,
                $enabled, $id, $tenant);
            return refused('no such rule') unless $n && $n != 0;
            return ok($id);
        }
        $dbh->do(
            'INSERT INTO alert_rules
                (tenant, name, query, op, threshold, for_ns, every_ns,
                 enabled, next_eval_at, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)',
            undef, $tenant, $name, $q, $op, $threshold, $for_ns, $every_ns,
            $enabled, time);
        ($id) = $dbh->selectrow_array(
            'SELECT id FROM alert_rules WHERE tenant = ? AND name = ?',
            undef, $tenant, $name);
        return ok($id);
    });
}

sub delete_alert {
    my ($db, $tenant, $id) = @_;
    return refused('a rule needs an id') unless $id;
    return _guard(sub {
        my $n = $db->dbh->do(
            'DELETE FROM alert_rules WHERE id = ? AND tenant = ?',
            undef, $id, $tenant);
        return $n && $n != 0 ? ok(undef) : refused('no such rule');
    });
}

sub silence_match {
    my ($pattern, $is_prefix, $key) = @_;
    return 0 unless defined $pattern && defined $key;
    return $is_prefix
        ? (rindex($key, $pattern, 0) == 0 ? 1 : 0)
        : ($key eq $pattern ? 1 : 0);
}

sub save_silence {
    my ($db, $tenant, $in) = @_;

    my $pattern = defined $in->{pattern} ? $in->{pattern} : '';
    $pattern =~ s/\A\s+|\s+\z//g;
    return refused('a silence needs a pattern - `<rule>/` silences a whole '
                 . 'rule, `<rule>/<series>` one series', 'pattern')
        unless length $pattern;

    my $until = defined $in->{until} ? $in->{until} : '';
    return refused('a silence needs a duration - try 1h, 2d', 'until')
        unless $until =~ /\S/;
    my ($ns) = Punk::Observe::View::min_duration($until);
    return refused("'$until' is not a duration - try 1h, 2d", 'until')
        unless defined $ns && $ns > 0;

    my $is_prefix = $in->{is_prefix} ? 1
                  : ($pattern =~ m{/\z} ? 1 : 0);

    return _guard(sub {
        my $dbh = $db->dbh;
        my $now = Punk::Observe::now_ns();
        $dbh->do(
            'INSERT INTO silences
                (tenant, pattern, is_prefix, reason, created_by, until,
                 created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)',
            undef, $tenant, $pattern, $is_prefix,
            (defined $in->{reason} && length $in->{reason} ? $in->{reason} : undef),
            (defined $in->{by}     && length $in->{by}     ? $in->{by}     : undef),
            Punk::Observe::Store::nadd($now, $ns), time);
        my ($id) = $dbh->selectrow_array('SELECT MAX(id) FROM silences
                                           WHERE tenant = ?', undef, $tenant);
        return ok($id);
    });
}

sub delete_silence {
    my ($db, $tenant, $id) = @_;
    return refused('a silence needs an id') unless $id;
    return _guard(sub {
        my $n = $db->dbh->do(
            'UPDATE silences SET until = ? WHERE id = ? AND tenant = ?',
            undef, Punk::Observe::now_ns(), $id, $tenant);
        return $n && $n != 0 ? ok(undef) : refused('no such silence');
    });
}

sub alerts {
    my ($db, $tenant, $req) = @_;
    my $dbh = $db->dbh;

    my $rules = $dbh->selectall_arrayref(
        'SELECT r.id, r.name, r.query, s.series, s.state, s.last_value,
                s.since, s.fired_at, s.reason
           FROM alert_rules r
           LEFT JOIN alert_state s ON s.rule_id = r.id
          WHERE r.tenant = ?
          ORDER BY r.name, s.series', { Slice => {} }, $tenant);

    my $now = Punk::Observe::now_ns();

    my $sil = $dbh->selectall_arrayref(
        'SELECT id, pattern, is_prefix, reason, created_by, until
           FROM silences WHERE tenant = ? AND until > ? ORDER BY until',
        { Slice => {} }, $tenant, $now);

    for my $r (@$rules) {
        $r->{series} = '' unless defined $r->{series};
        $r->{state}  = 'ok' unless defined $r->{state};
        $r->{value}  = $r->{last_value};
        $r->{held} = $r->{fired_at} ? $now - $r->{fired_at} : 0;
        my $key = "$r->{name}/$r->{series}";
        $r->{silenced} = (grep { silence_match(@{$_}{qw(pattern is_prefix)},
                                               $key) } @$sil) ? 1 : 0;
    }

    my $from = defined $req->{from} && length $req->{from}
             ? $req->{from} : $now - 86_400 * 1_000_000_000;
    my $events = $dbh->selectall_arrayref(
        'SELECT r.name AS rule_name, e.series, e.to_state, e.at
           FROM alert_events e
           JOIN alert_rules r ON r.id = e.rule_id
          WHERE r.tenant = ? AND e.at >= ?
          ORDER BY e.at', { Slice => {} }, $tenant, $from);

    my %seen;
    my @ev = map {
        $seen{"$_->{rule_name} / $_->{series}"} = 1;
        { series => "$_->{rule_name} / $_->{series}",
          to => $_->{to_state}, at => $_->{at} }
    } @$events;
    for my $r (@$rules) {
        next unless length $r->{series};
        my $k = "$r->{name} / $r->{series}";
        next if $seen{$k};
        push @ev, { series => $k, to => $r->{state}, at => $from };
    }

    $_->{by} = $_->{created_by} for @$sil;

    return { rules => $rules, silences => $sil, events => \@ev,
             to => $now, can_edit => 1 };
}

1;

__END__

=head1 NAME

Punk::Observe::Config - reading and writing what the screens are configured with

=head1 SYNOPSIS

    my $d = Punk::Observe::Config::dashboards($db, 'default', 'checkout');

    my $r = Punk::Observe::Config::save_panel($db, 'default', 'checkout', {
        title => 'errors', query => 'log | where severity >= error | count',
        viz   => 'bar', span => 2,
    });
    $r->{ok} or warn $r->{error};

=head1 DESCRIPTION

The configuration layer over L<Punk::Observe::Backend>: dashboards, panels,
alert rules and silences. It answers in the same shapes the C<alerts> and
C<dashboards> seams do, so a screen cannot tell whether it was given the
built-in store or a host's own reader.

=head2 Three outcomes, never two

Every writer answers C<< { ok => 1, id => ... } >>, or C<< { ok => 0,
refused => 1, error => ... } >>, or C<< { ok => 0, error => ... } >>.

The middle one is a reason the person can act on - a slug with a slash in it,
a query that does not parse, a dashboard that is not there. The last is
something they cannot - the database is gone. An editor that collapses them
says "something went wrong" when the real answer was "that query does not
parse, at character 14".

=head2 A panel is validated before it is stored

C<save_panel> runs the query through
L<Punk::Observe::Dashboard/check_panel>, which parses it with B<the same
parser that will execute it>. A panel that cannot parse never reaches the
table, so the dashboard page never has to apologise for one it stored.

=head1 FUNCTIONS

=head2 dashboards

    my $d = Punk::Observe::Config::dashboards($db, $tenant, $slug);

One dashboard and the list of the others, in the shape the dashboard screen
reads. An absent or empty slug answers with the first dashboard, because an
index that shows nothing is a worse landing page than one that shows
something.

=head2 save_dashboard / delete_dashboard

    my $r = Punk::Observe::Config::save_dashboard($db, $tenant, \%spec);
    my $r = Punk::Observe::Config::delete_dashboard($db, $tenant, $slug);

Create or update by C<(tenant, slug)>. C<cols> is clamped to the 1..6 the
stylesheet has rules for. Deleting takes the panels with it, by
C<ON DELETE CASCADE> rather than by remembering to.

=head2 save_panel / delete_panel

    my $r = Punk::Observe::Config::save_panel($db, $tenant, $slug, \%spec);
    my $r = Punk::Observe::Config::delete_panel($db, $tenant, $slug, $id);

An C<id> in the spec updates that panel; without one a panel is added. C<span>
is clamped the same way C<cols> is.

=head2 save_panels

    my $r = Punk::Observe::Config::save_panels($db, $tenant, $slug, \@rows);

Every panel row in one call - the editor's single save button. Each row
carries an C<id> and the C<save_panel> fields. All rows are validated before
any is written, the refusal names the row it is about, and the writes run in
one transaction: the result is the whole edit or none of it.

=head2 saved_views

    my $views = Punk::Observe::Config::saved_views($db, $tenant);
    my $views = Punk::Observe::Config::saved_views($db, $tenant, $page);

The views saved for a screen, in name order. Each carries its C<params> - the
query string it stands for - and, for the list to show, the C<query> inside it
and whether its window is C<frozen>.

B<A saved view is a link with a label>, not a second source of view state. It
navigates to the URL it stands for, so it is still shareable, still
bookmarkable, and still means the same thing in somebody else's browser -
which is the property C<brush.js> gives its reasons for and which anything
here has to keep.

=head2 save_view / delete_view

    my $r = Punk::Observe::Config::save_view($db, $tenant, \%spec);
    my $r = Punk::Observe::Config::delete_view($db, $tenant, $id);

Create or update by C<(tenant, page, name)>.

The query is checked by L<Punk::Observe::Dashboard/check_panel> - the parser
that will run it - for the same reason a panel is: a stored query string is a
stored panel by another name, and a column renamed under a saved view fails
the same way.

B<The window is stored as it was given and never normalised.> A view saved
with C<range=1h> still means "the last hour" next week; one saved with
C<from>/C<to> still means those two instants. Flattening the first into the
second would make "the last 15 minutes" quietly stop meaning that fifteen
minutes later, which is the trap L<Punk::Observe::View/window> and the range
picker both already avoid.

The mount prefix is B<not> stored. It is configuration, so a view saved under
C</observe> opens under C</telemetry>.

=head2 alerts

    my $a = Punk::Observe::Config::alerts($db, $tenant, $req);

Rules, active silences and the transition events for the alert timeline, one
rule entry B<per series> - which is how the state
machine keys them and how the screen expects them. C<held> is nanoseconds,
because the screen formats it and a pre-formatted string is read as a number.
A rule in the C<error> state carries C<reason> - why it could not be
evaluated, written by the evaluator and cleared on recovery.

The events are B<recorded transitions>, never inferred from current state - a
timeline built from "it is firing now" would be a straight line claiming the
present has always been the case. A series with no transition inside the
window gets one entry stamped at the start of it, which is an inference and a
sound one: the events table is complete, so no transition means the state held
across the whole window.

=head2 alert / save_alert / delete_alert

    my $rule = Punk::Observe::Config::alert($db, $tenant, $id);
    my $r = Punk::Observe::Config::save_alert($db, $tenant, \%rule);
    my $r = Punk::Observe::Config::delete_alert($db, $tenant, $id);

C<alert> is one rule as stored - for the editor, which needs the operator,
the threshold and the durations that the per-series screen reader carries no
columns for.

A rule takes C<name>, C<query>, C<op>, C<threshold>, C<for>, C<every> and
C<enabled>; C<id> updates rather than creates.

The query is B<validated by the parser that will run it> - the rule panels
already obey - and must be bucketed, because the evaluator feeds the state
machine one tick per bucket and C<for> cannot be measured over a single
number. C<op> is the state machine's own closed vocabulary. C<for> and
C<every> are durations through the UI's own parser, so C<30s> here and on
any other screen cannot disagree; C<every> is clamped to ten seconds at the
bottom, and both store as nanoseconds.

Saving resets the rule's evaluation schedule, so a changed threshold is
judged on the next pass rather than whenever the old cadence next came
round. Deleting takes state, events and pending notifications with it, by
C<ON DELETE CASCADE> rather than by remembering to.

=head2 save_silence / delete_silence

    my $r = Punk::Observe::Config::save_silence($db, $tenant, \%s);
    my $r = Punk::Observe::Config::delete_silence($db, $tenant, $id);

A silence takes C<pattern>, C<until>, and optionally C<reason>, C<by> and
C<is_prefix>. The pattern matches the key C<< <rule name>/<series> >>; a
trailing slash implies the prefix flag, so C<error rate/> silences a whole
rule and C<error rate/cards> exactly one series of it. C<until> is a
duration B<from now> - C<1h>, C<2d> - because "silence this for an hour" is
the sentence somebody says during an incident.

Deleting B<expires rather than erases>: the C<until> moves to now, so
suppression stops immediately and the record of who silenced what, and why,
survives - a silence is part of the story of an incident, and deleting the
row deletes the explanation.

=head2 silence_match

    my $hit = Punk::Observe::Config::silence_match($pattern, $is_prefix, $key);

Whether one silence covers one C<< rule/series >> key. This is the B<only>
matcher - the reader uses it to badge rule rows and delivery uses it to
suppress - because two copies of "does this silence cover that series" would
eventually disagree about exactly one page.

=head2 health_targets

    my $t = Punk::Observe::Config::health_targets($db, $tenant);
    my $t = Punk::Observe::Config::health_targets($db, $tenant, $name);

The endpoints this installation polls, in name order, or the one named.

=head2 save_health_target / delete_health_target

    my $r = Punk::Observe::Config::save_health_target($db, $tenant, \%spec,
                                                      $allowlist);
    my $r = Punk::Observe::Config::delete_health_target($db, $tenant, $name);

Create or update by C<(tenant, name)>.

B<The URL is checked before it is stored>, through
L<Punk::Observe::Target/check> - the same SSRF policy the webhook targets use,
because both are a URL a person typed that the server will then fetch. A
refusal says which it was and whether an allowlist would let it through, since
an installation polling services on a private network is the case the default
policy correctly refuses and an allowlist correctly permits.

The timeout is clamped rather than refused: there is no spelling of "wait
forever" here, because a target with no timeout blocks the runner behind it.

=head2 ok / refused / failed

The three answers, exported by nobody and called by the writers above.

=head1 SEE ALSO

L<Punk::Observe::Backend>, L<Punk::Plugin::Observe>

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
