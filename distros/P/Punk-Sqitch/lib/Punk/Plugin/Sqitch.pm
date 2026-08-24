package Punk::Plugin::Sqitch;

use 5.010;
use strict;
use warnings;
use parent 'Punk::Plugin';

our $VERSION = '0.01';

use Carp ();
use Punk ();
use Punk::Sqitch ();
use File::Spec ();

my %STATE;
my %PROJECTS;
              
our $SKIP_CHECK = 0;

sub project {
    my ($class, $app, $name, $dir, %opts) = @_;
    my $owner = caller;
    Carp::croak("Punk::Plugin::Sqitch: project needs a name and a directory")
        unless defined $name && defined $dir;
    Carp::croak("Punk::Plugin::Sqitch: '$name' is not a Sqitch project name "
              . '([A-Za-z][\w-]*)') unless $name =~ /\A[A-Za-z][\w-]*\z/;
    for my $k (keys %opts) {
        Carp::croak("Punk::Plugin::Sqitch: project '$name': unknown option "
                  . "'$k' (known: engines)") unless $k eq 'engines';
    }
    my $engines = $opts{engines};
    if (defined $engines) {
        Carp::croak("Punk::Plugin::Sqitch: project '$name': engines takes an "
                  . 'arrayref') unless ref $engines eq 'ARRAY';
        for my $e (@$engines) {
            Carp::croak("Punk::Plugin::Sqitch: project '$name': '$e' is not an "
                      . 'engine name (sqlite, pg, mysql, oracle, firebird, vertica, '
                      . 'exasol, snowflake, cockroach, clickhouse, yugabyte, ...)')
                unless $e =~ /\A[a-z][\w-]*\z/;
        }
    }
    Carp::croak("Punk::Plugin::Sqitch: project '$name' ($owner): '$dir' is not "
              . 'a directory') unless -d $dir;
    my $conf = Punk::Sqitch->read_conf("$dir/sqitch.conf");
    my $plan_file = Punk::Sqitch->plan_file_for($dir, $conf);
    Carp::croak("Punk::Plugin::Sqitch: project '$name' ($owner): no plan at "
              . "$plan_file") unless -f $plan_file;
    my $plan = Punk::Sqitch->read_plan($plan_file);
    Carp::croak("Punk::Plugin::Sqitch: project registered as '$name' by $owner "
              . "but its plan says %project=$plan->{project}")
        unless $plan->{project} eq $name;

    my $key = _key($app);
    my $list = $PROJECTS{$key} ||= [];
    for my $p (@$list) {
        next unless $p->{name} eq $name;
        Carp::croak("Punk::Plugin::Sqitch: project '$name' is registered twice: "
                  . "by $p->{owner} and by $owner");
    }
    push @$list, { name => $name, dir => $dir, owner => $owner,
                   engines => $engines, plan_file => $plan_file,
                   plan => $plan, conf => $conf };
    return;
}

sub projects_for {
    my ($class, $app, %o) = @_;
    my $list = $PROJECTS{ _key($app) } || [];
    return [] unless @$list;
    my %by = map { $_->{name} => $_ } @$list;
    my $app_project = $o{app_project};
    my (%seen, %active, @out);
    my $visit;
    $visit = sub {
        my ($p, @path) = @_;
        return if $seen{ $p->{name} };
        if ($active{ $p->{name} }) {
            Carp::croak('Punk::Plugin::Sqitch: the projects depend on each other in a '
                      . 'cycle: ' . join(' -> ', @path, $p->{name}));
        }
        $active{ $p->{name} } = 1;
        for my $r (@{ $p->{plan}{requires} }) {
            if (defined $app_project && $r eq $app_project) {
                Carp::croak("Punk::Plugin::Sqitch: project '$p->{name}' ($p->{owner}) "
                          . "requires the application's own project '$r', which "
                          . 'deploys after every plugin\'s');
            }
            my $dep = $by{$r}
                or Carp::croak("Punk::Plugin::Sqitch: project '$p->{name}' ($p->{owner}) "
                             . "requires project '$r', which no plugin registered");
            $visit->($dep, @path, $p->{name});
        }
        delete $active{ $p->{name} };
        $seen{ $p->{name} } = 1;
        push @out, $p;
    };
    $visit->($_) for @$list;
    return \@out;
}

sub register {
    my ($class, $app, $opts) = @_;
    $opts ||= {};
    Carp::croak('Punk::Plugin::Sqitch: options must be a hashref')
        unless ref $opts eq 'HASH';
    for my $k (keys %$opts) {
        Carp::croak("Punk::Plugin::Sqitch: unknown option '$k' (known: check, "
                  . 'database, dir, env)')
            unless $k =~ /\A(?:check|database|dir|env)\z/;
    }
    my $check = exists $opts->{check} ? $opts->{check} : 'croak';
    $check = 0 unless $check;
    Carp::croak("Punk::Plugin::Sqitch: check must be 'croak', 'warn' or 0, "
              . "not '$check'") unless $check eq '0' || $check =~ /\A(?:croak|warn)\z/;

    my $root = Punk::Sqitch->find_root($opts->{dir})
        or Carp::croak('Punk::Plugin::Sqitch: no application found (looked for '
                     . 'app.psgi upwards from ' . ($opts->{dir} || '.') . ')');
    # the plan is the thing being checked; its absence is a configuration
    # error at the plugin line, not a runtime condition
    my $dir  = Punk::Sqitch->project_dir($root);
    my $conf = Punk::Sqitch->read_conf(File::Spec->catfile($dir, 'sqitch.conf'));
    my $plan_file = Punk::Sqitch->plan_file_for($dir, $conf);
    Carp::croak("Punk::Plugin::Sqitch: no plan at $plan_file - run "
              . '`punk sqitch init` first') unless -f $plan_file;

    my $st = { check => $check, root => $root, dir => $dir, conf => $conf,
               plan_file => $plan_file, database => $opts->{database},
               env => $opts->{env}, result => undef };
    $STATE{ _key($app) } = $st;
    return unless $check;
    return if $SKIP_CHECK;

    if ($app->can('on_compile')) {
        $app->on_compile(sub { my ($a) = @_; _check($st, $a) }, __PACKAGE__);
    }
    else {
        _check($st, $app);
    }
    return;
}

sub _key {
    my ($app) = @_;
    return $app->caller_class if ref $app && $app->can('caller_class');
    return ref $app || $app;
}

sub _check {
    my ($st, $app) = @_;
    my $dbs = Punk::Sqitch->databases_for(
        root => $st->{root}, env => $st->{env},
        ($app && ref $app && $app->can('databases') ? (registrar => $app) : ()));
    my $db = Punk::Sqitch->database_for($dbs, $st->{database});
    my $app_project = Punk::Sqitch->app_project(root => $st->{root}, dir => $st->{dir},
                                                conf => $st->{conf},
                                                plan_file => $st->{plan_file});
    my $plugins  = __PACKAGE__->projects_for($app, app_project => $app_project->{name});
    my $projects = Punk::Sqitch->project_list($app_project, $plugins);
    # the registry follows the target, and the check may run from anywhere
    my $target   = Punk::Sqitch->target_abs(Punk::Sqitch->target_for($db), $st->{root});
    _check_engines($plugins, $target);
    my $results = Punk::Sqitch->pending_all(
        root => $st->{root}, database => $db, target => $target,
        conf => $st->{conf}, projects => $projects);
    $st->{result}  = $results->[-1];      # the application's own, as before
    $st->{results} = $results;
    my (@errors, @msgs);
    for my $r (@$results) {
        if ($r->{error}) { push @errors, "project '$r->{project}': $r->{error}"; next }
        if ($r->{drift}) { push @msgs, "project '$r->{project}': $r->{drift}"; next }
        my @p = @{ $r->{pending} };
        push @msgs, scalar(@p) . ' change' . (@p > 1 ? 's' : '')
                  . " pending for project '$r->{project}' (" . join(', ', @p) . ')'
            if @p;
    }
    if (@errors) {
        warn "Punk::Plugin::Sqitch: $_ - starting without the schema check\n"
            for @errors;
        return unless @msgs;
    }
    return unless @msgs;
    my $msg = 'the schema is behind the code: ' . join('; ', @msgs)
            . ' - run `punk sqitch deploy`';
    Carp::croak("Punk::Plugin::Sqitch: $msg") if $st->{check} eq 'croak';
    warn "Punk::Plugin::Sqitch: $msg\n";
    return;
}

sub _check_engines {
    my ($projects, $target) = @_;
    for my $p (@$projects) {
        next unless $p->{engines};
        next if grep { $_ eq $target->{engine} } @{ $p->{engines} };
        Carp::croak("Punk::Plugin::Sqitch: project '$p->{name}' ($p->{owner}) "
                  . 'supports ' . join(', ', @{ $p->{engines} })
                  . "; the database is $target->{engine}");
    }
    return;
}

sub result_for {
    my ($class, $app) = @_;
    my $st = $STATE{ _key($app) };
    return $st ? $st->{result} : undef;
}

1;

__END__

=head1 NAME

Punk::Plugin::Sqitch - the schema check at boot

=head1 SYNOPSIS

    package MyApp;
    use Punk;

    database dsn => 'dbi:Pg:dbname=shop', user => 'shop',
             password => $ENV{SHOP_DB_PASSWORD};

    plugin 'Sqitch';                           # pending changes: croak at boot
    plugin 'Sqitch' => { check => 'warn' };    # say so, start anyway
    plugin 'Sqitch' => { check => 0 };         # off

=head1 DESCRIPTION

Is the schema behind the code? This plugin asks once, at boot, in the
parent before the workers fork, with the same computation
C<punk sqitch pending> runs: the application's F<sqitch.plan> against the
Sqitch registry in its database. An application started against a schema
that is missing its latest changes fails on its first query anyway, with
a message about a column; this fails at boot, naming the changes and the
command that applies them.

Three outcomes, because they are three conditions:

=over 4

=item * B<Changes pending> - the plan lists changes the registry does not
hold. A croak naming them (C<< check => 'croak' >>, the default) or a
warning (C<'warn'>), because the deploy shipped without its migration and
"fail at C<to_app>, not at 3am" is the rule.

=item * B<The database is away> - the registry cannot be reached. A warning,
and the application starts: the database being unreachable at boot is not
the schema being behind, and L<Punk::Model> connects lazily for the same
reason.

=item * B<Drift> - the registry holds more changes than the plan, or its
last deployed change is not the plan's entry at that position. Something
was deployed here that the plan does not describe, and no C<deploy> fixes
it. A croak or a warning, as for pending.

=back

A missing F<sqitch.plan> croaks at the C<plugin> line: the plugin was asked
for and there is nothing to check. C<< check => 0 >> turns the check off
for the deployment that migrates after the new code is up, on purpose.

=head2 When it runs

On a Punk with C<< $app->on_compile >> (0.31 and later) the check runs at
C<to_app>, after every keyword has recorded, so it sees the database the
C<database> keyword declared wherever the C<plugin> line sits. Before that
it runs at the C<plugin> line and reads F<config/punk.yml> for the
environment - C<PUNK_ENV>, else C<production>, or the C<env> option - which
is where a deployed application's database is configured.

The check covers every project: the application's own and each one a
plugin registered (see L</FOR PLUGIN AUTHORS>), and its message names
each project's pending changes, plugins first.

=head1 FOR PLUGIN AUTHORS

A plugin that needs tables ships them as a Sqitch project - a directory
holding F<sqitch.plan> with C<%project=NAME> and the C<deploy/>,
C<revert/> and C<verify/> scripts - and registers it:

    # in your plugin's register
    Punk::Plugin::Sqitch->project($app, punk_apikey => $dir,
                                  engines => [qw(sqlite pg)])
        if Punk::Plugin::Sqitch->can('project');

The C<can> guard is the contract: your plugin must work without
Punk-Sqitch installed, documenting its DDL in its POD for the application
to apply however it applies schema. With it installed, C<punk sqitch
deploy> deploys your project before the application's own, into the same
database and registry under your project's name; C<revert> unwinds in the
opposite order; C<status>, C<verify>, C<log>, C<check> and C<pending> cover
it; and the boot check names it.

C<$dir> is wherever your distribution keeps the project - a share
directory through L<File::ShareDir>, or a path computed from your own
C<%INC> entry; the method takes a directory and does not care which.

=head2 Dependencies between projects

Your plan may require another plugin's change by project name -
C<< sqitch add keys --requires punk_auth:users >> - and Punk-Sqitch orders
the projects so that a project deploys after every project it requires,
registration order breaking ties. A cycle croaks naming it. A requirement
on a project no plugin registered croaks naming your plugin; a requirement
on the application's own project croaks, because the application deploys
last. The application's plan may require your changes the same way.

=head2 engines

C<< engines => [qw(sqlite pg)] >> says which engines your scripts are
written for; an application on another engine croaks at boot naming the
project and the list, rather than at deploy with a syntax error. Per
engine scripts are Sqitch's own arrangement: a project directory per
engine, or the engine-keyed script directories its documentation shows.

=head2 Two rules that are forever

B<The project name is the registry's key.> Renaming it orphans every
deployed change under the old name in every database your plugin was
ever deployed to. C<punk_E<lt>pluginE<gt>>, lowercase, and never changed.

B<A deployed script is never edited.> Once a change of yours is in
somebody's production registry, your next release may add changes, or
C<rework> one - Sqitch's way of changing a deployed change - and may not
edit the script in place: Sqitch's C<check> reports the divergence and a
fresh deploy runs different SQL from the one the registry records. This is
Sqitch's rule, stated here because a library author will not have met it.

=head2 The registry keeps its default name

A plugin's project runs from its own directory with no sight of the
application's F<sqitch.conf>, so a registry renamed there would leave the
plugins writing to one registry and the application to another. With
plugin projects registered the registry keeps Sqitch's default name, and
a renamed one croaks saying so.

=head1 OPTIONS

=over 4

=item C<check>

C<'croak'> (default), C<'warn'>, or C<0>.

=item C<database>

The configured database to check; the default one when omitted.

=item C<dir>

Where to look for the application (F<app.psgi>, walking up); the current
directory by default. The plan and F<sqitch.conf> are read relative to the
root found.

=item C<env>

The environment F<config/punk.yml> is resolved for, when the check reads
the file.

=back

=head1 WHAT IT READS

The application's project under F<sqitch/> (L<Punk::Sqitch/"The sqitch
directory">): F<sqitch.conf> for C<plan_file>, C<top_dir> and C<registry>
with Sqitch's own precedence (C<target.*>, C<engine.*>, C<core>); only
the project's own file, not F<~/.sqitch/sqitch.conf>. The registry itself: for SQLite the
file Sqitch keeps beside the target (the registry name in place of the
database's basename - F<app.db> and C<sqitch> give F<sqitch.db>), for
PostgreSQL the C<sqitch> schema, for MySQL the C<sqitch> database. One
C<SELECT>, through DBI, with no L<App::Sqitch> loaded: this runs in a web
worker's parent, where loading a Moo application to answer a yes/no
question would be the wrong cost.

=head1 METHODS

=head2 register($app, \%opts)

The plugin entry point; see L</OPTIONS>.

=head2 project($app, $name => $dir, %opts)

Register a plugin's Sqitch project for the application C<$app> is the
registrar of; see L</FOR PLUGIN AUTHORS>. Croaks at the plugin line on a
name Sqitch would refuse, a directory without a plan, a plan whose
C<%project> is not C<$name>, a second registration of the name (naming
both owners), or an unknown option.

=head2 projects_for($app_or_class, app_project => $name?)

The registered projects in deploy order; croaks on a cycle or an
unregistered requirement.

=head2 result_for($app_class)

The last check's result hash for the application's own project (see
L<Punk::Sqitch/pending>), for tests.

=head1 SEE ALSO

L<Punk::Sqitch>, L<Punk::Command::Sqitch>, L<Punk::Plugin>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
