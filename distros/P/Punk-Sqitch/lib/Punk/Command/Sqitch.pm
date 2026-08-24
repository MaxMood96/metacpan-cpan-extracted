package Punk::Command::Sqitch;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.01';

use Punk::Command ();
use Punk::Sqitch ();
use Cwd ();
use File::Spec ();

my $USAGE = <<'U';
usage: punk sqitch [--env ENV] [--database NAME] [--dir DIR] [--project NAME] [--app-only]
                   <verb> [sqitch options]

  --env ENV        resolve config/punk.yml for ENV (default: PUNK_ENV, else production)
  --database NAME  the configured database to target (default: the default one)
  --dir DIR        where to look for the application (default: the current directory)
  --project NAME   run a target verb over one project only (a plugin's, or the app's)
  --app-only       the application's own project only, without loading its class

A target verb (deploy, revert, verify, status, log, check) runs over every
project: the plugins' - in dependency order, found by loading the application
class - then the application's own; revert goes the other way. Plan verbs
(add, tag, rework, plan, show, init, ...) work on the application's project.

verbs: any sqitch command - deploy, revert, verify, status, log, check, add,
tag, rework, plan, show, init, ... - see `punk sqitch help`; and one of punk's
own:

  pending [--quiet]   list the plan's changes not yet deployed; exit 1 if any
                      (sqitch's `check` is the other half: it reports a
                      deployed script edited since - drift - and exits 1 for
                      that, while exiting 0 with changes pending)

and two that are sqitch's with punk filling in what the application knows:

  init [NAME] [...]   the project name from the application class (MyApp ->
                      myapp) and --engine from the configured database unless
                      given; refuses an application that already has a plan
  add CHANGE --model NAME [...]
                      sqitch add, then deploy/revert/verify scripts drafted
                      from the model's fields for the project's engine
U

sub main {
    my (@argv) = @_;
    my %o;
    while (@argv && $argv[0] =~ /\A-/) {
        my $a = shift @argv;
        if    ($a =~ /\A--(env|database|dir|project)=(.*)\z/s) { $o{$1} = $2 }
        elsif ($a =~ /\A--(env|database|dir|project)\z/) {
            defined($o{$1} = shift @argv)
                or return _usage("--$1 needs a value");
        }
        elsif ($a eq '--app-only') { $o{app_only} = 1 }
        elsif ($a eq '-h' || $a eq '--help') { print $USAGE; return 0 }
        else { return _usage("unknown option '$a' before the verb - sqitch's "
                           . 'own options go after it') }
    }
    my $verb = shift @argv or return _usage('a sqitch verb is required');
    if ($verb eq 'help') {
        # sqitch's own help, for its own verbs; ours for no argument
        return Punk::Sqitch->run(verb => 'help', args => \@argv) if @argv;
        print $USAGE;
        return 0;
    }

    my $root = Punk::Sqitch->find_root($o{dir});
    unless ($root) {
        print STDERR 'punk sqitch: no application found (looked for app.psgi '
                   . 'upwards from ' . ($o{dir} || Cwd::getcwd()) . ")\n";
        return 2;
    }

    # punk's own verb: the deploy gate
    return _pending($root, \%o, @argv) if $verb eq 'pending';
    # sqitch's verbs with the application filling in the blanks
    return _init($root, \%o, @argv) if $verb eq 'init';
    return _add($root, \%o, @argv)  if $verb eq 'add';

    # a plan verb: the application's project, from its own directory
    unless (Punk::Sqitch->takes_target($verb)) {
        return _run_in(Punk::Sqitch->project_dir($root), $verb, \@argv, undef);
    }

    # a target verb: every project, in order
    my ($target, $projects);
    my $ok = eval {
        my $dbs = Punk::Sqitch->databases_for(root => $root, env => $o{env});
        my $db  = Punk::Sqitch->database_for($dbs, $o{database});
        $target   = Punk::Sqitch->target_for($db);
        $projects = Punk::Sqitch->projects(root => $root, app_only => $o{app_only});
        1;
    };
    return _err($@) unless $ok;
    if (defined $o{project}) {
        my @one = grep { $_->{name} eq $o{project} } @$projects;
        return _err("no project '$o{project}' (have: "
                  . join(', ', map { $_->{name} } @$projects) . ')') unless @one;
        $projects = \@one;
    }
    # revert unwinds in the opposite order: the application first, then the
    # plugins it depends on, newest registration first
    $projects = [ reverse @$projects ] if $verb eq 'revert';
    my $many = @$projects > 1;
    # every project runs from its own directory - the plugins', and the
    # application's own sqitch/ - so a relative SQLite target is made
    # absolute against the application root for all of them. A --target the
    # caller wrote gets the same treatment: a relative path in it means what
    # a relative path in punk.yml means, the application root.
    _abs_target_argv($root, \@argv);
    my $t = Punk::Sqitch->target_abs($target, $root);
    if ($verb eq 'deploy' && (my $made = Punk::Sqitch->ensure_target_dir($t, $root))) {
        print "Created $made for the database\n";
    }
    for my $p (@$projects) {
        print "# project $p->{name}" . ($p->{plugin} ? " ($p->{dir})" : '') . "\n"
            if $many;
        my $code = _run_in($p->{dir}, $verb, \@argv, $t);
        return $code if $code;
    }
    return 0;
}

# one Sqitch command, from a directory, reporting a die as punk's own error
# a relative SQLite path in the caller's own --target, made absolute
# against the application root
sub _abs_target_argv {
    my ($root, $argv) = @_;
    for my $i (0 .. $#$argv) {
        my ($val, $set);
        if ($argv->[$i] =~ /\A(?:--target|-t)=(.*)\z/s) {
            $val = $1; $set = sub { $argv->[$i] = ($argv->[$i] =~ /\A(--target|-t)=/)[0] . "=$_[0]" };
        }
        elsif ($argv->[$i] =~ /\A(?:--target|-t)\z/ && $i < $#$argv) {
            $val = $argv->[$i + 1]; $set = sub { $argv->[$i + 1] = $_[0] };
        }
        next unless defined $val;
        my $t = Punk::Sqitch->target_abs({ engine => 'sqlite', uri => $val }, $root);
        $set->($t->{uri}) if $t->{uri} ne $val;
    }
    return;
}

sub _run_in {
    my ($dir, $verb, $argv, $target) = @_;
    my $code = eval { Punk::Sqitch->run(verb => $verb, args => [ @$argv ],
                                        target => $target, cwd => $dir) };
    return _err($@) if $@;
    return $code;
}

sub _err {
    my ($err) = @_;
    $err = "$err";
    $err =~ s/ at \S+ line \d+\.?\s*\z//;
    $err =~ s/\s+\z//;
    print STDERR "punk sqitch: $err\n";
    return 1;
}

sub _init {
    my ($root, $o, @argv) = @_;
    my $dir  = Punk::Sqitch->project_dir($root);
    my $conf = Punk::Sqitch->read_conf(File::Spec->catfile($dir, 'sqitch.conf'));
    my $plan_file = Punk::Sqitch->plan_file_for($dir, $conf);
    if (-f $plan_file) {
        my $plan = eval { Punk::Sqitch->read_plan($plan_file) };
        return _err("already a Sqitch project" . ($plan ? " (%project=$plan->{project})" : '')
                  . " - the plan is at $plan_file");
    }
    my ($name, @rest);
    my $has_engine = 0;
    while (@argv) {
        my $a = shift @argv;
        if ($a =~ /\A--engine(?:=|\z)/) { $has_engine = 1; push @rest, $a; push @rest, shift @argv if $a eq '--engine' && @argv; next }
        if ($a =~ /\A-/) { push @rest, $a; next }
        if (!defined $name) { $name = $a; next }
        push @rest, $a;
    }
    unless (defined $name) {
        my $class = Punk::Sqitch->app_class_for($root)
            or return _usage('init needs a project name: no application class could be '
                           . 'read from app.psgi to derive one from');
        $name = Punk::Sqitch->project_name_for($class);
    }
    unless ($has_engine) {
        my $engine = eval {
            my $dbs = Punk::Sqitch->databases_for(root => $root, env => $o->{env});
            my $db  = Punk::Sqitch->database_for($dbs, $o->{database});
            Punk::Sqitch->target_for($db)->{engine};
        };
        return _usage('init needs --engine: no database is configured to derive it '
                    . 'from (' . _clean($@) . ')') unless $engine;
        push @rest, '--engine', $engine;
    }
    unless (-d $dir) {
        require File::Path;
        File::Path::make_path($dir);
        print 'Created ' . File::Spec->abs2rel($dir, $root) . "/\n";
    }
    return _run_in($dir, 'init', [ $name, @rest ], undef);
}

sub _add {
    my ($root, $o, @argv) = @_;
    my ($model, @rest);
    while (@argv) {
        my $a = shift @argv;
        if ($a =~ /\A--model=(.*)\z/s) { $model = $1; next }
        if ($a eq '--model') {
            defined($model = shift @argv) or return _usage('--model needs a name');
            next;
        }
        push @rest, $a;
    }
    my $dir = Punk::Sqitch->project_dir($root);
    return _run_in($dir, 'add', \@rest, undef) unless defined $model;

    my $conf = Punk::Sqitch->read_conf(File::Spec->catfile($dir, 'sqitch.conf'));
    my $plan_file = Punk::Sqitch->plan_file_for($dir, $conf);
    return _err("no plan at $plan_file - run `punk sqitch init` first") unless -f $plan_file;

    # the model first, so a typo costs no change in the plan
    my ($meta, $from) = eval { _model_meta($root, $model) };
    return _err($@) if $@;
    my $engine = Punk::Sqitch->conf_get($conf, 'engine') || eval {
        my $dbs = Punk::Sqitch->databases_for(root => $root, env => $o->{env});
        Punk::Sqitch->target_for(Punk::Sqitch->database_for($dbs, $o->{database}))->{engine};
    };
    return _err('no engine: sqitch.conf names none and no database is configured')
        unless $engine;

    my $before = Punk::Sqitch->read_plan($plan_file);
    my $code = _run_in($dir, 'add', \@rest, undef);
    return $code if $code;
    my $after = Punk::Sqitch->read_plan($plan_file);
    return _err('sqitch add added no change to the plan')
        unless @{ $after->{changes} } > @{ $before->{changes} };
    my $change = $after->{changes}[-1];

    my $sk = Punk::Sqitch->skeleton(meta => $meta, engine => $engine,
                                    project => $after->{project}, change => $change,
                                    model => $from);
    my $top = Punk::Sqitch->conf_get($conf, 'top_dir', $engine) // '.';
    my $ext = Punk::Sqitch->conf_get($conf, 'extension', $engine) // 'sql';
    for my $kind (qw(deploy revert verify)) {
        my $d = Punk::Sqitch->conf_get($conf, "${kind}_dir", $engine) // $kind;
        my $file = File::Spec->catfile($dir, $top, $d, "$change.$ext");
        open my $fh, '>', $file or return _err("cannot write $file: $!");
        print $fh $sk->{$kind};
        close $fh;
        print "Drafted $kind/$change.$ext from $from\n";
    }
    return 0;
}

sub _model_meta {
    my ($root, $model) = @_;
    my $class;
    if ($model =~ /\A\+(.+)\z/) { $class = $1; Punk::Sqitch->load_app($root) }
    else {
        my $app = Punk::Sqitch->load_app($root);
        $class = "${app}::Model::$model";
    }
    (my $file = "$class.pm") =~ s{::}{/}g;
    unless ($class->can('_punk_model_meta')) {
        my $ok = eval { require $file; 1 };
        die "cannot load model $class: " . _clean($@) . "\n" unless $ok;
    }
    die "$class is not a Punk::Model\n" unless $class->can('_punk_model_meta');
    my $meta = $class->_punk_model_meta;
    die "$class declares no table\n" unless ref $meta eq 'HASH' && $meta->{table};
    return ($meta, $class);
}

sub _clean { my ($e) = @_; $e = "$e"; $e =~ s/ at \S+ line \d+\.?\s*\z//; $e =~ s/\s+\z//; $e }


sub _pending {
    my ($root, $o, @argv) = @_;
    my $quiet = 0;
    for my $a (@argv) {
        if ($a eq '--quiet' || $a eq '-q') { $quiet = 1 }
        else { return _usage("pending takes --quiet and nothing else, not '$a'") }
    }
    my $results = eval {
        my $dbs = Punk::Sqitch->databases_for(root => $root, env => $o->{env});
        my $db  = Punk::Sqitch->database_for($dbs, $o->{database});
        my $projects = Punk::Sqitch->projects(root => $root, app_only => $o->{app_only});
        $projects = [ grep { $_->{name} eq $o->{project} } @$projects ]
            if defined $o->{project};
        Punk::Sqitch->pending_all(root => $root, database => $db,
                                  projects => $projects);
    };
    return _err($@) unless $results;
    my $bad = 0;
    for my $r (@$results) {
        my $where = $r->{registry}{kind} eq 'file'
                  ? $r->{registry}{path}
                  : "$r->{registry}{kind} $r->{registry}{name}";
        if ($r->{error}) {
            print STDERR "punk sqitch: project '$r->{project}': $r->{error}\n" unless $quiet;
            $bad++;
            next;
        }
        if ($r->{drift}) {
            print STDERR "punk sqitch: project '$r->{project}': $r->{drift}\n" unless $quiet;
            $bad++;
            next;
        }
        my @p = @{ $r->{pending} };
        $bad++ if @p;
        next if $quiet;
        print "# Project:  $r->{project}\n";
        print "# Registry: $where\n";
        print "# Deployed: $r->{deployed}\n";
        if (@p) {
            print "Pending change" . (@p > 1 ? 's' : '') . ":\n";
            print "  * $_\n" for @p;
        }
        else {
            print "Nothing pending\n";
        }
        print "\n" if @$results > 1;
    }
    return $bad ? 1 : 0;
}

sub _usage {
    my ($why) = @_;
    print STDERR "punk sqitch: $why\n\n$USAGE";
    return 2;
}

Punk::Command->register(sqitch => {
    abstract => 'schema changes with Sqitch, against the configured database',
    display  => 'sqitch <verb>',
    usage    => '[--env ENV] [--database NAME] [--dir DIR] [--project NAME] [--app-only] '
              . '<verb> [sqitch options]',
    desc     => 'Runs a Sqitch command in-process with --target built from the '
              . "application's database\nconfiguration - punk.yml resolved for "
              . '--env, the password through $SQITCH_PASSWORD - so Sqitch '
              . "never keeps\na second copy of the connection.",
    raw      => 1,
    code     => sub {
        my (undef, @argv) = @_;
        return main(@argv);
    },
}, __PACKAGE__) if Punk::Command->can('register');


Punk::Command->register_doctor('Punk::Sqitch' => sub {
    my $ok = eval { require App::Sqitch; 1 };
    return (0, 'App::Sqitch not installed') unless $ok;
    my $detail = "$Punk::Sqitch::VERSION (App::Sqitch $App::Sqitch::VERSION)";
    my $root = Punk::Sqitch->find_root or return (1, "$detail; no application here");
    my $conf = Punk::Sqitch->read_conf(
        File::Spec->catfile(Punk::Sqitch->project_dir($root), 'sqitch.conf'));
    my $engine = Punk::Sqitch->conf_get($conf, 'engine') || eval {
        my $dbs = Punk::Sqitch->databases_for(root => $root);
        Punk::Sqitch->target_for(Punk::Sqitch->database_for($dbs))->{engine};
    };
    return (1, "$detail; no database configured, so no engine to check a client for")
        unless $engine;
    my $c = Punk::Sqitch->client_for($engine, $conf);
    return (0, "$detail; engine $engine: $c->{why} - the deploy host needs it")
        unless $c->{ok};
    return (1, "$detail; engine $engine, $c->{name}"
              . (defined $c->{version} ? " $c->{version}" : '') . ' on PATH');
}, __PACKAGE__) if Punk::Command->can('register_doctor');

1;

__END__

=head1 NAME

Punk::Command::Sqitch - `punk sqitch ...`, Sqitch against the configured database

=head1 SYNOPSIS

    punk sqitch deploy
    punk sqitch deploy --env production
    punk sqitch status --database analytics
    punk sqitch add users -n 'users table'
    punk sqitch check
    punk sqitch help deploy

=head1 DESCRIPTION

Loading this module registers C<sqitch> with L<Punk::Command>'s registry -
which is what F<bin/punk> does on an unknown command, so C<punk sqitch>
works wherever Punk::Sqitch is installed, with no configuration.

Three options belong to punk and come B<before> the verb:

=over 4

=item C<--env ENV>

The environment F<config/punk.yml> is resolved for: C<PUNK_ENV>, else
C<production>. The same resolution C<punk config check> performs, every
C<$env>, C<$file> and C<$exec> reference included.

=item C<--database NAME>

Which configured database to target; the default one when omitted. A
name that is not configured croaks listing the ones that are.

=item C<--dir DIR>

Where to start looking for the application (its F<app.psgi>, walking
up). The current directory by default.

=item C<--project NAME>

Run a target verb over one project only - a plugin's, or the
application's own.

=item C<--app-only>

The application's own project only, without loading its class to find
the plugins' projects - for an application class that will not load, or
a deploy that must not touch what the plugins ship.

=back

=head2 Projects

A target verb runs over every project: the plugins' (see
L<Punk::Plugin::Sqitch/FOR PLUGIN AUTHORS>) in dependency order, then the
application's own, each announced with a C<# project NAME> line when
there is more than one; C<revert> goes the other way, the application
first. The plugins' projects are found by loading the application class
with the boot check held off. Each plugin project runs from its own
directory against the same target, made absolute for SQLite so the
registry is the one file beside the database. The first project to fail
stops the run. A plan verb works on the application's project alone.

C<revert> asks for confirmation unless given C<-y>, as Sqitch does; from a
script, pass it.

Everything after the verb is Sqitch's: its options, its arguments, its
help. For a verb that takes a target (C<deploy>, C<revert>, C<verify>,
C<status>, C<log>, C<check>, C<checkout>, C<rebase>, C<upgrade>,
C<bundle>) punk supplies C<--target> from the configuration unless the
arguments carry one, and the password through C<$SQITCH_PASSWORD>, never
in the URI. A plan-only verb (C<add>, C<tag>, C<rework>, C<plan>, C<show>,
C<init>, ...) needs no database and reads none.

The command runs in-process, with the project's own directory as its
working directory: F<sqitch/> under the application root for the
application's project (see L<Punk::Sqitch/"The sqitch directory">), and
its own directory for each plugin's. A relative SQLite path - in
F<punk.yml> or in a C<--target> of your own - is resolved against the
B<application root> whichever project is running, and C<deploy> creates
the directory it names if it is missing. Exit codes: Sqitch's own for
its errors (printed as C<punk sqitch: ...>), 2 for a usage error, 1
otherwise.

=head2 punk sqitch pending

    punk sqitch pending            # lists what is pending; exit 1 if anything is
    punk sqitch pending --quiet    # the exit code alone, for a CI step

The one verb that is punk's rather than Sqitch's: the plan against the
registry (L<Punk::Sqitch/pending>), exit 1 when a change is pending or the
registry has drifted from the plan, 0 otherwise. Sqitch's C<status> shows
the same changes but exits 0; its C<check> detects a deployed script
edited since deployment and exits 1 for that. A deploy gate wants both:

    punk config check && punk sqitch pending --quiet && punk sqitch check

=head2 punk sqitch init [NAME] [sqitch init options]

Sqitch's C<init> with the blanks the application can fill: the project
name from the application class when none is given (C<MyApp> is C<myapp>,
C<My::App> is C<my_app> - Sqitch's name grammar, lowercased), and
C<--engine> from the configured database's driver unless given. The
project is created under F<sqitch/> in the application root
(L<Punk::Sqitch/"The sqitch directory">). No target is written into
F<sqitch.conf>; it comes from F<punk.yml> on every run. An application
that already has a plan is refused naming it, because Sqitch's own
C<init> is a silent no-op on one and a silent no-op is how a second
project name goes unnoticed.

=head2 punk sqitch add CHANGE --model NAME [sqitch add options]

Sqitch's C<add>, then the deploy, revert and verify scripts drafted from
the L<Punk::Model> named - C<MyApp::Model::NAME>, or C<+Full::Class> -
for the project's engine: a C<CREATE TABLE> of the model's fields in
order with the primary key as the engine's autoincrement, C<NOT NULL>
for C<required>, a C<DROP TABLE>, and a C<SELECT> of every column from
no rows. The scripts say where they came from and that they are a
B<starting point>: indexes, defaults, foreign keys and the database's
real types are yours, and the model is not read again. The model is
loaded before the change is added, so a misspelt one costs nothing.
Without C<--model> this is Sqitch's C<add>.

=head2 punk doctor

A C<Punk::Sqitch> row joins C<punk doctor>'s plugin section: App::Sqitch's
version and, inside an application, the engine its database implies and
whether that engine's client binary - C<sqlite3> (3.3.9 or later),
C<psql>, C<mysql>, or the one F<sqitch.conf> names - is on C<PATH>. The
client is the one thing the Perl side cannot supply, and a deployment
image that forgot it learns so here rather than from its first deploy.

=head1 SEE ALSO

L<Punk::Sqitch>, L<Punk::Command>, L<sqitch>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
