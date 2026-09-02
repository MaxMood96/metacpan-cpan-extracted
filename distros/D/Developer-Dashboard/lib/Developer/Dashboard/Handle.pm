package Developer::Dashboard::Handle;

use strict;
use warnings;

use Cwd ();
use Capture::Tiny qw(capture);
use Developer::Dashboard::PathRegistry;
use Developer::Dashboard::FileRegistry;
use Developer::Dashboard::Config;
use Developer::Dashboard::JSON qw(json_decode);

our $VERSION = '4.29';

our $AUTOLOAD;

# new(%args)
# Builds a lazy runtime handle scoped to a working directory, matching the
# same layer discovery the dashboard/d2 CLI uses to resolve path aliases.
# Input: cwd => directory string (optional, defaults to Cwd::cwd()).
# Output: Developer::Dashboard::Handle object.
sub new {
    my ( $class, %args ) = @_;
    return bless { cwd => $args{cwd} // Cwd::cwd() }, $class;    # uncoverable condition false Cwd::cwd() cannot return undef
}

# paths()
# Returns the resolved path-alias table for this handle's directory - the
# same aliases `dashboard paths` prints: built-in runtime roots plus any
# custom alias added with `dashboard path add`. In-process, no subprocess.
# Input: none.
# Output: hash reference of alias name => resolved directory path.
sub paths {
    my ($self) = @_;
    return $self->{_paths_cache} //= $self->_registry->all_path_aliases;
}

# run($subcommand, @args)
# Runs `dashboard <subcommand> @args` exactly as it would run on the command
# line, for anything not covered by an in-process method such as paths().
# Existing for subcommands that cannot be spelled as a bareword Perl method
# (dotted Tira commands such as tira.ticket.show) and as the mechanism
# AUTOLOAD delegates to for everything else.
# Input: subcommand name string, list of further CLI arguments.
# Output: decoded Perl structure when stdout parses as JSON, otherwise the
#         raw trimmed stdout string. Dies (with stderr attached) on a
#         nonzero exit - a failed command never silently returns as if it
#         had succeeded.
sub run {
    my ( $self, $subcommand, @args ) = @_;
    die 'Missing subcommand' if !defined $subcommand || $subcommand eq '';

    # DD-670: system() sets the global $? - localize it here so a subprocess
    # call this sub makes never leaks a changed $? into the caller's scope.
    local $?;

    my ( $stdout, $stderr, $exit ) = capture {
        local $ENV{PATH} = $ENV{PATH};
        system( 'dashboard', $subcommand, @args );
    };
    $exit >>= 8;
    die "dashboard $subcommand @args failed (exit $exit): $stderr"
      if $exit != 0;

    $stdout =~ s/\A\s+|\s+\z//g;
    return $stdout if $stdout eq '';

    my $decoded = eval { json_decode($stdout) };
    return $decoded if !$@ && ref($decoded);
    return $stdout;
}

# _registry()
# Builds (once per handle) the PathRegistry with configured named aliases
# registered, scoped to this handle's cwd - the same composition
# CLI::Paths::_build_paths + run_paths_command's alias-loading closure use.
# Input: none.
# Output: Developer::Dashboard::PathRegistry object.
sub _registry {
    my ($self) = @_;
    return $self->{_registry} //= do {
        my $home  = $ENV{HOME} || '';
        my @roots = grep { defined && -d } map { "$home/$_" } qw(projects src work);    # uncoverable branch false the interpolated map above always yields a defined string
        my $paths = Developer::Dashboard::PathRegistry->new(
            home            => $home,
            cwd             => $self->{cwd},
            workspace_roots => \@roots,
            project_roots   => \@roots,
        );
        my $files  = Developer::Dashboard::FileRegistry->new( paths => $paths );
        my $config = Developer::Dashboard::Config->new( files => $files, paths => $paths );
        $paths->register_named_paths( $config->path_aliases );
        $paths;
    };
}

# AUTOLOAD($self, @args)
# Any method name not defined above (e.g. d2->doctor) is treated as a
# single-word dashboard subcommand and delegated to run(). Dotted
# subcommands cannot be spelled this way (a dot is not a valid bareword
# method character) - use run() directly for those.
# Input: method-call arguments.
# Output: same as run().
sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    return if $name eq 'DESTROY';
    return $self->run( $name, @_ );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Developer::Dashboard::Handle - in-process proxy for the dashboard/d2 CLI

=head1 VERSION
4.29

=head1 PURPOSE

Gives Perl code a single-line way to reach the same runtime the
C<dashboard>/C<d2> command line resolves, instead of hand-building a
L<Developer::Dashboard::PathRegistry>, L<Developer::Dashboard::FileRegistry>,
and L<Developer::Dashboard::Config> to answer one question such as a
configured path alias.

=head1 WHY IT EXISTS

Filed after the project's owner asked directly (over the project's Telegram
bridge) for a shorter Perl equivalent of C<dashboard path resolve NAME>, then
widened the request to cover any dashboard subcommand: "Anything I can run
with d2 on bash [...] I am expecting the d2() subroutine can do the same."
C<paths()> answers the original, narrower ask in-process (no subprocess,
since path aliases are cheap to resolve directly against the registry);
C<run()> and C<AUTOLOAD> answer the widened one by shelling out to the real
CLI for everything else, which is the only way to reach the full command
surface without reimplementing it.

=head1 WHEN TO USE

From any Perl script or module in this project (or one with this
distribution installed) that needs a configured path alias, or the output of
any other C<dashboard> subcommand, without forking a subprocess by hand and
parsing its output itself.

=head1 HOW TO USE

    use Developer::Dashboard;

    my $foo = d2->paths->{foo};              # fast, in-process
    my $out = d2->doctor;                    # shells to `dashboard doctor`
    my $res = d2->run( 'tira.ticket.show', '--ref', 'DD-726' );
                                              # dotted subcommands: run() only

C<d2()> (exported by L<Developer::Dashboard>) memoizes one handle per working
directory, so repeated calls from the same directory reuse the same
registry rather than rebuilding it.

=head1 WHAT USES IT

Nothing in the shipped CLI itself - this is a convenience entrypoint for
external Perl code (scripts, other distributions) that embeds this one.
L<Developer::Dashboard::CLI::Paths> and the rest of the CLI continue to
build their own registries directly, unchanged by this module.

=head1 EXAMPLES

    use Developer::Dashboard;

    # A custom alias added with `dashboard path add reports /var/reports`:
    my $dir = d2->paths->{reports};   # '/var/reports'

    # Anything else the CLI can do, in-process:
    my $version_text = d2->version;

=cut
