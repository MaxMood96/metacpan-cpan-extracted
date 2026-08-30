package Punk::Observe::Backend;

use 5.010;
use strict;
use warnings;
use Carp ();
use DBI ();

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

my %POOL;

my %DIALECT = (
    SQLite => {
        serial  => 'INTEGER PRIMARY KEY AUTOINCREMENT',
        bigint  => 'INTEGER',
        text    => 'TEXT',
        json    => 'TEXT',
        bool    => 'INTEGER',
        dbl     => 'REAL',
        small   => 'INTEGER',
        now     => "CAST(strftime('%s','now') AS INTEGER)",
    },
    Pg => {
        serial  => 'BIGSERIAL PRIMARY KEY',
        bigint  => 'BIGINT',
        text    => 'TEXT',
        json    => 'JSONB',
        bool    => 'BOOLEAN',
        dbl     => 'DOUBLE PRECISION',
        small   => 'SMALLINT',
        now     => 'EXTRACT(EPOCH FROM now())::BIGINT',
    },
);

sub dialect_name { return lc((split /::/, ref($_[0]) || $_[0])[-1]) }

sub _project_dir {
    my ($self) = @_;
    my $engine = $self->dialect_name;
    return undef unless defined $engine && length $engine;

    my $pm = $INC{'Punk/Observe/Backend.pm'} or return undef;
    require File::Basename;
    require File::Spec;
    my $dir = File::Basename::dirname($pm);

    my @try = (File::Spec->catdir($dir, 'sqitch'));
    my $up = $dir;
    for (1 .. 5) {
        $up = File::Spec->catdir($up, File::Spec->updir);
        push @try, File::Spec->catdir($up, 'sqitch');
    }
    for my $c (@try) {
        my $p = File::Spec->catdir($c, $engine);
        return $p if -f File::Spec->catfile($p, 'sqitch.plan');
    }
    return undef;
}

sub _plan_changes {
    my ($self, $dir) = @_;
    require File::Spec;
    open my $fh, '<', File::Spec->catfile($dir, 'sqitch.plan') or return [];
    my @out;
    while (my $line = <$fh>) {
        next if $line =~ /\A\s*\z/ || $line =~ /\A\s*[#%]/;
        my ($name) = $line =~ /\A(\S+)/ or next;
        next if $name =~ /\A\@/;
        $name =~ s/\@.*\z//;
        push @out, $name;
    }
    close $fh;
    return \@out;
}

sub LATEST {
    my ($self) = @_;
    return undef unless ref $self;
    my $dir = $self->_project_dir or return undef;
    my $c = $self->_plan_changes($dir);
    return @$c ? $c->[-1] : undef;
}

sub new {
    my ($class, %opt) = @_;

    if ($class eq __PACKAGE__) {
        my $impl = $opt{backend};
        if (defined $impl && length $impl) {
            $impl =~ s/\A\+// or $impl = __PACKAGE__ . "::$impl";
        }
        else {
            $impl = __PACKAGE__ . '::' . _infer($opt{dsn}, $opt{dbh});
        }
        (my $file = $impl) =~ s{::}{/}g;
        eval { require "$file.pm"; 1 }
            or Carp::croak("Punk::Observe::Backend: cannot load $impl - $@");
        return $impl->new(%opt);
    }

    my $self = bless {
        dsn      => $opt{dsn},
        user     => $opt{user},
        password => $opt{password},
        attr     => $opt{attr} || {},
        dbh      => $opt{dbh},
        pid      => $$,
    }, $class;
    return $self;
}

sub _infer {
    my ($dsn, $dbh) = @_;
    if (!defined $dsn || !length $dsn) {
        return 'SQLite' unless $dbh;
        my $d = eval { $dbh->{Driver}{Name} } || '';
        return $d eq 'Pg' ? 'Pg' : 'SQLite';
    }
    return 'Pg' if $dsn =~ /\Adbi:Pg:/i;
    return 'SQLite' if $dsn =~ /\Adbi:SQLite:/i;
    Carp::croak(
        "Punk::Observe::Backend: no backend for '$dsn'. Shipped are SQLite "
      . "and Pg; pass backend => '+Your::Class' for anything else.");
}

sub dbh {
    my ($self) = @_;
    if ($self->{dbh}) {
        unless ($self->{_configured}++) {
            my $wait = eval { $self->{dbh}->selectrow_array('PRAGMA busy_timeout') };
            $self->_on_connect($self->{dbh});
            eval { $self->{dbh}->do("PRAGMA busy_timeout = $wait") }
                if defined $wait && $wait =~ /\A\d+\z/;
        }
        return $self->{dbh};
    }

    my $key = join "\0", $$, $self->{dsn} // '', $self->{user} // '';
    my $h = $POOL{$key};
    return $h if $h && $h->{Active} && eval { $h->ping };

    $h = DBI->connect($self->{dsn}, $self->{user}, $self->{password}, {
        RaiseError          => 1,
        PrintError          => 0,
        AutoCommit          => 1,
        AutoInactiveDestroy => 1,
        %{ $self->{attr} },
    });
    $self->_on_connect($h);
    return $POOL{$key} = $h;
}

sub _on_connect { }

sub disconnect {
    my ($self) = @_;
    return if $self->{dbh};
    my $key = join "\0", $$, $self->{dsn} // '', $self->{user} // '';
    my $h = delete $POOL{$key} or return;
    eval { $h->disconnect };
    return;
}

sub dialect { $DIALECT{ (split /::/, ref($_[0]) || $_[0])[-1] } }

sub schema_version {
    my ($self) = @_;
    return eval {
        my $rows = $self->dbh->selectall_arrayref(
            'SELECT change FROM punk_observe_schema') or return undef;
        my %have = map { $_->[0] => 1 } @$rows;
        return undef unless %have;

        my $dir = $self->_project_dir or return undef;
        my $last;
        for my $c (@{ $self->_plan_changes($dir) }) {
            $last = $c if $have{$c};
        }
        return $last;
    };
}

sub migrate {
    my ($self, $to) = @_;
    my $dbh = $self->dbh;

    my $dir = $self->_project_dir;
    Carp::croak(
        "Punk::Observe::Backend: no sqitch project for the "
      . ($self->dialect_name || 'unknown') . " engine. The change scripts "
      . "ship in sqitch/ and are installed beside the module; a checkout "
      . "runs from sqitch/ at the top of the distribution.")
        unless $dir;

    my $changes = $self->_plan_changes($dir);
    my %want = map { $_ => 1 } @$changes;
    my @order = @$changes;
    if (defined $to) {
        my @upto;
        for my $c (@order) { push @upto, $c; last if $c eq $to }
        @order = @upto;
    }

    $dbh->do("CREATE TABLE IF NOT EXISTS punk_observe_schema (
                  change TEXT NOT NULL, applied_at INTEGER NOT NULL DEFAULT 0)");

    return $self->_locked(sub {
        my $done = $dbh->selectall_arrayref(
            'SELECT change FROM punk_observe_schema') || [];
        my %have = map { $_->[0] => 1 } @$done;

        if (!%have) {
            my @seen = grep { !/\Apunk_observe_schema\z/ }
                       @{ $self->_tables || [] };
            Carp::croak(
                "Punk::Observe::Backend: this database has tables (@seen) and "
              . "no record of a deployed change, so it was not built by these "
              . "scripts. Point `db` at an empty database, or record the "
              . "changes it already has in punk_observe_schema.")
                if @seen;
        }

        my $applied;
        for my $change (@order) {
            next if $have{$change};
            $self->_deploy_change($dir, $change);
            $dbh->do('INSERT INTO punk_observe_schema (change, applied_at)
                      VALUES (?, ?)', undef, $change, time);
            $applied = $change;
        }
        return defined $applied ? $applied
             : (@order ? $order[-1] : undef);
    });
}

sub _deploy_change {
    my ($self, $dir, $change) = @_;
    require File::Spec;
    my $dbh = $self->dbh;

    my $sql = $self->_read_script(
        File::Spec->catfile($dir, 'deploy', "$change.sql"));
    Carp::croak("Punk::Observe::Backend: no deploy script for '$change'")
        unless defined $sql;

    $self->_run_script($sql);

    my $v = $self->_read_script(
        File::Spec->catfile($dir, 'verify', "$change.sql"));
    if (defined $v) {
        eval { $self->_run_script($v); 1 } or Carp::croak(
            "Punk::Observe::Backend: '$change' deployed but did not verify: $@");
    }
    return 1;
}

sub _read_script {
    my ($self, $path) = @_;
    open my $fh, '<', $path or return undef;
    local $/;
    my $sql = <$fh>;
    close $fh;
    return $sql;
}

sub _run_script {
    my ($self, $sql) = @_;
    my $dbh = $self->dbh;

    $sql =~ s/^[ \t]*--[^\n]*$//gm;
    for my $stmt (split /;\s*$/m, $sql) {
        next unless $stmt =~ /\S/;
        next if $stmt =~ /\A\s*(?:BEGIN|COMMIT|ROLLBACK)\b/i;
        $dbh->do($stmt);
    }
    return 1;
}

sub _locked { my ($self, $code) = @_; return $code->() }

sub _tables { return [] }

sub ddl {
    my ($self, $to) = @_;
    my $dir = $self->_project_dir or return [];
    my @out;
    for my $change (@{ $self->_plan_changes($dir) }) {
        require File::Spec;
        my $sql = $self->_read_script(
            File::Spec->catfile($dir, "deploy", "$change.sql"));
        push @out, $sql if defined $sql;
        last if defined $to && $change eq $to;
    }
    return \@out;
}

1;

__END__

=head1 NAME

Punk::Observe::Backend - where the configuration lives

=head1 SYNOPSIS

    my $db = Punk::Observe::Backend->new(dsn => 'dbi:SQLite:dbname=cfg.db');
    my $db = Punk::Observe::Backend->new(dsn => 'dbi:Pg:dbname=observe');
    my $db = Punk::Observe::Backend->new(dbh => $existing_handle);
    my $db = Punk::Observe::Backend->new(dsn => ..., backend => '+My::Backend');

    $db->migrate;                 # safe from every process at boot

=head1 DESCRIPTION

Dashboards, alert rules, check targets and saved views are B<configuration>:
a handful of small rows, written by a person, read once per page render. They
are not telemetry, and they do not go anywhere near the store - segments are
immutable and the write-ahead log is append-only, which is the whole storage
design.

So they live in a database, and B<this distribution ships one>. Before 0.02
it shipped DDL and no database code, and every host had to write a seam to
reach it; the result was that dashboards had a renderer, a validator, two
tables and no reader, because nobody wrote one.

=head2 It is Perl, and the rest of this distribution is not

Deliberately. Everything that touches telemetry here is C because it runs per
record or per row. This runs per page, over a handful of rows, and C would
buy nothing but a second place for a memory bug.

=head2 The pool carries the pid

Every worker is a fork. A handle made before the fork and used after it is
shared by two processes that both believe they own it, which corrupts the
protocol under load rather than failing in a test. Keying the pool on the pid
means a forked child misses the cache and connects for itself.

An explicit C<dbh> is never pooled and never reconnected: it belongs to the
caller.

=head1 THE SCHEMA

Version 1 is the nine tables F<sqitch/deploy/alerts.sql> describes. The DDL is
written once, with type tokens the dialect fills in, so a column cannot exist
in one backend and not the other. F<t/0910-backend.t> asserts the migration
and the sqitch change describe the same tables and columns, so drift is a
failing build.

Instants are nanoseconds in a C<BIGINT>, never a timestamp type. That is the
same rule the rest of the distribution follows and it is not a stylistic one:
a nanosecond instant does not survive a double, and the two backends disagree
about timestamp precision in ways that would make a dashboard mean something
different depending on where it was stored.

=head1 METHODS

=head2 new

    my $db = Punk::Observe::Backend->new(%opts);

On this class it is a factory: the backend is inferred from the C<dsn>'s
driver, and C<backend> overrides it - a leading C<+> means a literal class
name, anything else is relative to C<Punk::Observe::Backend::>. On a subclass
it is an ordinary constructor.

Options: C<dsn>, C<user>, C<password>, C<attr> (merged into the DBI connect
attributes), C<dbh> (an existing handle, used as-is), C<backend>.

=head2 dbh

The handle for this process, connecting if it has to.

=head2 disconnect

Drop this process's pooled handle. Call it after migrating at boot and before
forking a worker pool: keying the pool on the pid stops a child B<reusing> the
parent's handle and does nothing about it B<inheriting the descriptor>, which
SQLite does not allow. An explicit C<dbh> is left alone, because it belongs to
the caller.

=head2 migrate

    my $version = $db->migrate;
    my $version = $db->migrate($to);

Bring the schema up to date, or to a given version. Idempotent, forward-only,
and safe to call from every process at boot: it takes the backend's own lock
and B<re-reads the version under it>, because the version checked before
taking a lock is the one somebody else may have just changed.

=head2 schema_version

The name of the most recently deployed change, or C<undef> for a database
with nothing applied.

=head2 ddl

    my $statements = $db->ddl;

The migration as this backend would run it. For tests and for generating the
sqitch change; not part of the runtime path.

=head2 dialect

The type map for this backend.

=head2 dialect_name

Which engine this is, spelled as sqitch spells it. The dialect table is keyed
by the same names, so a subclass does not have to say it twice.

=head2 LATEST

The newest schema version this release knows how to build. C<migrate> with no
argument goes here.

=head1 WRITING A BACKEND

Subclass this, or do not - C<< backend => '+My::Class' >> takes any class
answering to C<new>, C<dbh>, C<migrate> and C<schema_version>. Subclassing
gets the migration runner and the pool; C<_lock> and C<_on_connect> are the
two things a dialect actually has to say for itself.

=head1 SEE ALSO

L<Punk::Observe::Backend::SQLite>, L<Punk::Observe::Backend::Pg>,
L<Punk::Plugin::Observe>.

=head1 AUTHOR

LNATION, C<< <email at lnation.org> >>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION.

This is free software, licensed under the Artistic License 2.0.

=cut
