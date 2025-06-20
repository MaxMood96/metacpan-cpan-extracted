package App::Sqitch::Engine::exasol;

use 5.010;
use Moo;
use utf8;
use Path::Class;
use DBI;
use Try::Tiny;
use App::Sqitch::X qw(hurl);
use Locale::TextDomain qw(App-Sqitch);
use App::Sqitch::Types qw(DBH Dir ArrayRef);
use App::Sqitch::Plan::Change;
use List::Util qw(first);
use namespace::autoclean;

extends 'App::Sqitch::Engine';

our $VERSION = 'v1.5.2'; # VERSION

sub _dt($) {
    require App::Sqitch::DateTime;
    return App::Sqitch::DateTime->new(split /:/ => shift);
}

sub key    { 'exasol' }
sub name   { 'Exasol' }
sub driver { 'DBD::ODBC 1.59' }
sub default_client { 'exaplus' }

BEGIN {
    # Disable SQLPATH so that we don't read scripts from unexpected places.
    $ENV{SQLPATH} = '';
}

sub destination {
    my $self = shift;

    # Just use the target name if it doesn't look like a URI or if the URI
    # includes the database name.
    return $self->target->name if $self->target->name !~ /:/
        || $self->target->uri->dbname;

    # Use the URI sans password.
    my $uri = $self->target->uri->clone;
    $uri->password(undef) if $uri->password;
    return $uri->as_string;
}

# No username or password defaults.
sub _def_user { }
sub _def_pass { }

has _exaplus => (
    is         => 'ro',
    isa        => ArrayRef,
    lazy       => 1,
    default    => sub {
        my $self = shift;
        my $uri  = $self->uri;
        my @ret  = ( $self->client );

        # Collect the cquery params and convert keys to uppercase.
        require URI::QueryParam;
        my $qry  = $uri->query_form_hash;
        for my $key (keys %{ $qry }) {
            my $ukey = uc $key;
            next if $key eq $ukey;

            # Move value to uppercase key.
            my $val = delete $qry->{$key};
            if (!exists $qry->{$ukey}) {
                # Store under uppercase key.
                $qry->{$ukey} = $val;
            } else {
                # Push the value(s) onto upercase key array value.
                $qry->{$ukey} = [$qry->{$ukey}] if ref $qry->{$ukey} ne 'ARRAY';
                push @{ $qry->{$ukey} } => ref $val eq 'ARRAY' ? @{ $val } : $val;
            }
        }

        # Use _port instead of port so it's empty if no port is in the URI.
        # https://github.com/sqitchers/sqitch/issues/675
        for my $spec (
            [ u => $self->username ],
            [ p => $self->password ],
            [ c => $uri->host && $uri->_port ? $uri->host . ':' . $uri->_port : undef ],
            [ profile => $uri->host ? undef : $uri->dbname ],
            [ jdbcparam => ($qry->{SSLCERTIFICATE} || '') eq 'SSL_VERIFY_NONE' ? 'validateservercertificate=0' : undef ],
            [ jdbcparam => $qry->{AUTHMETHOD}  ? "authmethod=$qry->{AUTHMETHOD}" : undef ],
        ) {
            push @ret, "-$spec->[0]" => $spec->[1] if $spec->[1];
        }

        push @ret => (
            '-q',                       # Quiet mode
            '-L',                       # Don't prompt if login fails, just exit
            '-pipe',                    # Enable piping of scripts to 'exaplus'
            '-x',                       # Stop in case of errors
            '-autoCompletion' => 'OFF',
            '-encoding' => 'UTF8',
            '-autocommit' => 'OFF',
        );
        return \@ret;
    },
);

sub exaplus { @{ shift->_exaplus } }

has tmpdir => (
    is       => 'ro',
    isa      => Dir,
    lazy     => 1,
    default  => sub {
        require File::Temp;
        dir File::Temp::tempdir( CLEANUP => 1 );
    },
);

has dbh => (
    is      => 'rw',
    isa     => DBH,
    lazy    => 1,
    default => sub {
        my $self = shift;
        $self->use_driver;

        DBI->connect($self->_dsn, $self->username, $self->password, {
            PrintError        => 0,
            RaiseError        => 0,
            AutoCommit        => 1,
            odbc_utf8_on      => 1,
            FetchHashKeyName  => 'NAME_lc',
            HandleError       => $self->error_handler,
            Callbacks         => {
                connected => sub {
                    my $dbh = shift;
                    $dbh->do("ALTER SESSION SET $_='YYYY-MM-DD HH24:MI:SS'") for qw(
                        nls_date_format
                        nls_timestamp_format
                    );
                    $dbh->do("ALTER SESSION SET TIME_ZONE='UTC'");
                    if (my $schema = $self->registry) {
                        $dbh->do("OPEN SCHEMA $schema")
                            or $self->_handle_no_registry($dbh);
                    }
                    return;
                },
            },
        });
    }
);

# Need to wait until dbh is defined.
with 'App::Sqitch::Role::DBIEngine';

# Timestamp formats

sub _char2ts {
    my $dt = $_[1];
    $dt->set_time_zone('UTC');
    $dt->ymd('-') . ' ' . $dt->hms(':');
}

sub _ts2char_format {
    return qq{'year:' || CAST(EXTRACT(YEAR   FROM %s) AS SMALLINT)
        || ':month:'  || CAST(EXTRACT(MONTH  FROM %1\$s) AS SMALLINT)
        || ':day:'    || CAST(EXTRACT(DAY    FROM %1\$s) AS SMALLINT)
        || ':hour:'   || CAST(EXTRACT(HOUR   FROM %1\$s) AS SMALLINT)
        || ':minute:' || CAST(EXTRACT(MINUTE FROM %1\$s) AS SMALLINT)
        || ':second:' || FLOOR(CAST(EXTRACT(SECOND FROM %1\$s) AS NUMERIC(9,4)))
        || ':time_zone:UTC'};
}

sub _ts_default { 'current_timestamp' }

sub _listagg_format {
    return q{GROUP_CONCAT(%1$s ORDER BY %1$s SEPARATOR ' ')};
}

sub _regex_op { 'REGEXP_LIKE' }

# LIMIT in Exasol doesn't behave properly with values > 18446744073709551611
sub _limit_default { '18446744073709551611' }

sub _simple_from { ' FROM dual' }

sub _multi_values {
    my ($self, $count, $expr) = @_;
    return join "\nUNION ALL ", ("SELECT $expr FROM dual") x $count;
}

sub _initialized {
    my $self = shift;
    return $self->dbh->selectcol_arrayref(q{
        SELECT EXISTS(
            SELECT TRUE FROM exa_all_tables
             WHERE table_schema = ? AND table_name = ?
        )
    }, undef, uc $self->registry, 'CHANGES')->[0];
}

# LIMIT / OFFSET in Exasol doesn't seem to play nice in the original query with
# JOIN and GROUP BY; wrap it in a subquery instead..
sub change_offset_from_id {
    my ( $self, $change_id, $offset ) = @_;

    # Just return the object if there is no offset.
    return $self->load_change($change_id) unless $offset;

    # Are we offset forwards or backwards?
    my ($dir, $op, $offset_expr) = $self->_offset_op($offset);
    my $tscol  = sprintf $self->_ts2char_format, 'c.planned_at';
    my $tagcol = sprintf $self->_listagg_format, 't.tag';

    my $change = $self->dbh->selectrow_hashref(qq{
        SELECT id, name, project, note, "timestamp", planner_name, planner_email,
               tags, script_hash
          FROM (
            SELECT c.change_id AS id, c.change AS name, c.project, c.note,
                   $tscol AS "timestamp", c.planner_name, c.planner_email,
                   $tagcol AS tags, c.committed_at, c.script_hash
              FROM changes   c
              LEFT JOIN tags t ON c.change_id = t.change_id
             WHERE c.project = ?
               AND c.committed_at $op (
                   SELECT committed_at FROM changes WHERE change_id = ?
             )
             GROUP BY c.change_id, c.change, c.project, c.note, c.planned_at,
                   c.planner_name, c.planner_email, c.committed_at, c.script_hash
          ) changes
        ORDER BY changes.committed_at $dir
         LIMIT 1 $offset_expr
    }, undef, $self->plan->project, $change_id) || return undef;
    $change->{timestamp} = _dt $change->{timestamp};
    unless (ref $change->{tags}) {
        $change->{tags} = $change->{tags} ? [ split / / => $change->{tags} ] : [];
    }
    return $change;
}

sub changes_requiring_change {
    my ( $self, $change ) = @_;
    # Why CTE: https://forums.oracle.com/forums/thread.jspa?threadID=1005221
    # NOTE: Query from DBIEngine doesn't work in Exasol:
    #   Error: [00444] more than one column in select list of correlated subselect
    # The CTE-based query below seems to be fine, however.
    return @{ $self->dbh->selectall_arrayref(q{
        WITH tag AS (
            SELECT tag, committed_at, project,
                   ROW_NUMBER() OVER (partition by project ORDER BY committed_at) AS rnk
              FROM tags
        )
        SELECT c.change_id, c.project, c.change, t.tag AS asof_tag
          FROM dependencies d
          JOIN changes  c ON c.change_id = d.change_id
          LEFT JOIN tag t ON t.project   = c.project AND t.committed_at >= c.committed_at
         WHERE d.dependency_id = ?
           AND (t.rnk IS NULL OR t.rnk = 1)
    }, { Slice => {} }, $change->id) };
}

sub name_for_change_id {
    my ( $self, $change_id ) = @_;
    # Why CTE: https://forums.oracle.com/forums/thread.jspa?threadID=1005221
    # NOTE: Query from DBIEngine doesn't work in Exasol:
    #   Error: [0A000] Feature not supported: non-equality correlations in correlated subselect
    # The CTE-based query below seems to be fine, however.
    return $self->dbh->selectcol_arrayref(q{
        WITH tag AS (
            SELECT tag, committed_at, project,
                   ROW_NUMBER() OVER (partition by project ORDER BY committed_at) AS rnk
              FROM tags
        )
        SELECT change || COALESCE(t.tag, '@HEAD')
          FROM changes c
          LEFT JOIN tag t ON c.project = t.project AND t.committed_at >= c.committed_at
         WHERE change_id = ?
           AND (t.rnk IS NULL OR t.rnk = 1)
    }, undef, $change_id)->[0];
}

sub _cid {
    my ( $self, $ord, $offset, $project ) = @_;

    my $offset_expr = $offset ? " OFFSET $offset" : '';
    return try {
        $self->dbh->selectcol_arrayref(qq{
            SELECT change_id
              FROM changes
             WHERE project = ?
             ORDER BY committed_at $ord
             LIMIT 1$offset_expr
        }, undef, $project || $self->plan->project)->[0];
    } catch {
        return if $self->_no_table_error && !$self->initialized;
        die $_;
    };
}

sub is_deployed_tag {
    my ( $self, $tag ) = @_;
    return $self->dbh->selectcol_arrayref(
        'SELECT 1 FROM tags WHERE tag_id = ?',
        undef, $tag->id
    )->[0];
}

sub _registry_variable {
    my $self   = shift;
    my $schema = $self->registry;
    return "DEFINE registry=$schema;";
}

sub _initialize {
    my $self   = shift;
    my $schema = $self->registry;
    hurl engine => __ 'Sqitch already initialized' if $self->initialized;

    # Load up our database.
    (my $file = file(__FILE__)->dir->file('exasol.sql')) =~ s/"/""/g;
    $self->_run_with_verbosity($file);
    $self->dbh->do("OPEN SCHEMA $schema") if $schema;
    $self->_register_release;
}

sub _limit_offset {
    # LIMIT/OFFSET don't support parameters, alas. So just put them in the query.
    my ($self, $lim, $off)  = @_;
    # OFFSET cannot be used without LIMIT, sadly.
    return ['LIMIT ' . ($lim || $self->_limit_default), "OFFSET $off"], [] if $off;
    return ["LIMIT $lim"], [] if $lim;
    return [], [];
}

sub _regex_expr {
    my ( $self, $col, $regex ) = @_;
    $regex = '.*' . $regex if $regex !~ m{^\^};
    $regex .= '.*' if $regex !~ m{\$$};
    my $op = $self->_regex_op;
    return "$col $op ?", $regex;
}

# Override to lock the changes table. This ensures that only one instance of
# Sqitch runs at one time.
sub begin_work {
    my $self = shift;
    my $dbh = $self->dbh;

    # Start transaction and lock changes to allow only one change at a time.
    # https://www.exasol.com/portal/pages/viewpage.action?pageId=22518143
    $dbh->begin_work;
    $dbh->do('DELETE FROM changes WHERE FALSE');
    return $self;
}

# Release lock by comitting or rolling back.
sub finish_work {
    my $self = shift;
    $self->dbh->commit;
    return $self;
}

sub rollback_work {
    my $self = shift;
    $self->dbh->rollback;
    return $self;
}

sub _file_for_script {
    my ($self, $file) = @_;

    # Just use the file if no special character.
    if ($file !~ /[@?%\$]/) {
        $file =~ s/"/""/g;
        return $file;
    }

    # Alias or copy the file to a temporary directory that's removed on exit.
    (my $alias = $file->basename) =~ s/[@?%\$]/_/g;
    $alias = $self->tmpdir->file($alias);

    # Remove existing file.
    if (-e $alias) {
        $alias->remove or hurl exasol => __x(
            'Cannot remove {file}: {error}',
            file  => $alias,
            error => $!
        );
    }

    if (App::Sqitch::ISWIN) {
        # Copy it.
        $file->copy_to($alias) or hurl exasol => __x(
            'Cannot copy {file} to {alias}: {error}',
            file  => $file,
            alias => $alias,
            error => $!
        );
    } else {
        # Symlink it.
        $alias->remove;
        symlink $file->absolute, $alias or hurl exasol => __x(
            'Cannot symlink {file} to {alias}: {error}',
            file  => $file,
            alias => $alias,
            error => $!
        );
    }

    # Return the alias.
    $alias =~ s/"/""/g;
    return $alias;
}

sub run_file {
    my $self = shift;
    my $file = $self->_file_for_script(shift);
    $self->_capture(qq{\@"$file"});
}

sub _run_with_verbosity {
    my $self = shift;
    my $file = $self->_file_for_script(shift);
    # Suppress STDOUT unless we want extra verbosity.
    #my $meth = $self->can($self->sqitch->verbosity > 1 ? '_run' : '_capture');
    my $meth = '_capture';
    $self->$meth(qq{\@"$file"});
}

sub run_upgrade { shift->_run_with_verbosity(@_) }
sub run_verify  { shift->_run_with_verbosity(@_) }

sub run_handle {
    my ($self, $fh) = @_;
    my $conn = $self->_script;
    open my $tfh, '<:utf8_strict', \$conn;
    $self->sqitch->spool( [$tfh, $fh], $self->exaplus );
}

# Exasol treats empty string as NULL; adjust accordingly..

sub _log_tags_param {
    my $res = join ' ' => map { $_->format_name } $_[1]->tags;
    return $res || ' ';
}

sub _log_requires_param {
    my $res = join ',' => map { $_->as_string } $_[1]->requires;
    return $res || ' ';
}

sub _log_conflicts_param {
    my $res = join ',' => map { $_->as_string } $_[1]->conflicts;
    return $res || ' ';
}

sub _no_table_error  {
    return $DBI::errstr && $DBI::errstr =~ /object \w+ not found/m;
}

sub _no_column_error  {
    return $DBI::errstr && $DBI::errstr =~ /object \w+ not found/m;
}

sub _unique_error  {
    # Unique constraints not supported by Exasol
    return 0;
}

sub _script {
    my $self = shift;
    my $uri  = $self->uri;
    my %vars = $self->variables;

    return join "\n" => (
        'SET FEEDBACK OFF;',
        'SET HEADING OFF;',
        'WHENEVER OSERROR EXIT 9;',
        'WHENEVER SQLERROR EXIT 4;',
        (map {; (my $v = $vars{$_}) =~ s/'/''/g; qq{DEFINE $_='$v';} } sort keys %vars),
        $self->_registry_variable,
        # Just 'map { s/;?$/;/r } ...' doesn't work in earlier Perl versions;
        # see: https://www.perlmonks.org/index.pl?node_id=1048579
        map { (my $foo=$_) =~ s/;?$/;/; $foo } @_
    );
}

sub _run {
    my $self = shift;
    my $script = $self->_script(@_);
    open my $fh, '<:utf8_strict', \$script;
    return $self->sqitch->spool( $fh, $self->exaplus );
}

sub _capture {
    my $self = shift;
    my $conn = $self->_script(@_);
    my @out;
    my @errout;

    $self->sqitch->debug('CMD: ' . join(' ', $self->exaplus));
    $self->sqitch->debug("SQL:\n---\n", $conn, "\n---");

    require IPC::Run3;
    IPC::Run3::run3(
        [$self->exaplus], \$conn, \@out, \@out,
        { return_if_system_error => 1 },
    );

    # EXAplus doesn't always seem to give a useful exit value; we need to match
    # on output as well..
    if (my $err = $? || grep { /^Error:/m } @out) {
        # Ugh, send everything to STDERR.
        $self->sqitch->vent(@out);
        hurl io => __x(
            '{command} unexpectedly failed; exit value = {exitval}',
            command => $self->client,
            exitval => ($err >> 8),
        );
    }
    return wantarray ? @out : \@out;
}

1;

__END__

=head1 Name

App::Sqitch::Engine::exasol - Sqitch Exasol Engine

=head1 Synopsis

  my $exasol = App::Sqitch::Engine->load( engine => 'exasol' );

=head1 Description

App::Sqitch::Engine::exasol provides the Exasol storage engine for Sqitch. It
is tested with Exasol 6.0 and higher.

=head1 Interface

=head2 Instance Methods

=head3 C<initialized>

  $exasol->initialize unless $exasol->initialized;

Returns true if the database has been initialized for Sqitch, and false if it
has not.

=head3 C<initialize>

  $exasol->initialize;

Initializes a database for Sqitch by installing the Sqitch registry schema.

=head3 C<exaplus>

Returns a list containing the C<exaplus> client and options to be passed to it.
Used internally when executing scripts.

=head1 Author

David E. Wheeler <david@justatheory.com>

=head1 License

Copyright (c) 2012-2025 David E. Wheeler, 2012-2021 iovation Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
