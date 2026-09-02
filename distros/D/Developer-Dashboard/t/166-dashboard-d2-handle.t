#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec ();
use Cwd qw(abs_path getcwd);
use Scalar::Util qw(refaddr);
use Capture::Tiny qw(capture);

use lib 'lib';

use Developer::Dashboard;
use Developer::Dashboard::Handle;
use Developer::Dashboard::CLI::Paths ();
use Developer::Dashboard::PathRegistry;

# Warnings are fatal in this repository: collect any that escape and assert
# the whole run stayed clean.
my @warnings;
$SIG{__WARN__} = sub { push @warnings, $_[0]; return; };

# Hermetic runtime rooted at a temp home. The config root resolves from the
# deepest .developer-dashboard layer above the cwd, so chdir into the temp
# home before building any registry or exercising d2().
my $home = abs_path( tempdir( CLEANUP => 1 ) );
local $ENV{HOME}                           = $home;
local $ENV{DEVELOPER_DASHBOARD_STATE_ROOT} = tempdir( CLEANUP => 1 );
my $starting_cwd = getcwd();
chdir $home or die "Unable to chdir to $home: $!";

# AC-1: a built-in alias (one PathRegistry answers with a method of the same
# name) resolves the same way through d2->paths as through resolve_dir
# directly.
{
    my $direct = Developer::Dashboard::PathRegistry->new( home => $home, cwd => $home );
    is( d2->paths->{home}, $direct->home, 'AC-1: d2->paths->{home} matches PathRegistry->home directly' );
}

# AC-2: a custom alias added the same way `dashboard path add` does (through
# the real CLI dispatch, so it is genuinely persisted, not a stub) is
# resolvable through d2->paths too.
{
    my ($stdout) = capture {
        Developer::Dashboard::CLI::Paths::run_paths_command(
            command => 'path',
            args    => [ 'add', 'reports', '/var/reports-example' ],
        );
    };

    # A fresh handle for a fresh cwd (still $home) must see the alias just
    # persisted - proves d2->paths reads real configured aliases, not a
    # frozen snapshot from before the alias existed.
    my $fresh = Developer::Dashboard::Handle->new( cwd => $home );
    is( $fresh->paths->{reports}, '/var/reports-example',
        'AC-2: a custom alias added via the real path-add command resolves through Handle->paths' );
}

# AC-3: d2() memoizes one handle per working directory - repeated calls from
# the same cwd return the identical object, not a rebuilt one.
{
    my $first  = d2();
    my $second = d2();
    is( refaddr($first), refaddr($second), 'AC-3: d2() returns the same handle object for the same cwd' );
}

# AC-4: accessing a missing alias is a normal hash miss - undef, never a die.
{
    my $missing = eval { d2->paths->{'this-alias-does-not-exist'} };
    is( $@, '', 'AC-4: looking up a missing alias does not die' );
    is( $missing, undef, 'AC-4: and it is undef, exactly like a normal hash miss' );
}

# AC-5/AC-8: a bareword single-word method (AUTOLOAD) shells to the real
# `dashboard <name>` and a nonzero exit dies with stderr attached, rather
# than silently returning as if it had succeeded.
{
    my $handle = Developer::Dashboard::Handle->new( cwd => $home );
    my $ok = eval { $handle->doesnotexistasarealdashboardsubcommand; 1 };
    ok( !$ok, 'AC-5/AC-8: an unknown subcommand fails rather than silently succeeding' );
    like( $@, qr/failed \(exit \d+\)/, 'and the die message names the exit code' );
}

# AC-6/AC-7: Handle->run() drives an arbitrary "dashboard"-named executable
# on PATH (stubbed here so the test does not depend on the real CLI's own
# subcommand set), decoding JSON-shaped stdout and passing through plain
# text, to isolate the run()/AUTOLOAD contract from the real CLI's behavior.
{
    my $bin_dir = tempdir( CLEANUP => 1 );
    my $stub    = File::Spec->catfile( $bin_dir, 'dashboard' );
    open my $fh, '>', $stub or die $!;
    print {$fh} <<'STUB';
#!/bin/sh
case "$1" in
  json-thing) echo '{"alpha":"beta"}' ;;
  text-thing) echo 'plain text output' ;;
  fail-thing) echo 'stub failure detail' 1>&2; exit 7 ;;
esac
STUB
    close $fh;
    chmod 0755, $stub;
    local $ENV{PATH} = "$bin_dir:$ENV{PATH}";

    my $handle = Developer::Dashboard::Handle->new( cwd => $home );

    my $decoded = $handle->run('json-thing');
    is_deeply( $decoded, { alpha => 'beta' }, 'AC-6/AC-7: JSON-shaped stdout decodes to a Perl structure' );

    my $text = $handle->run('text-thing');
    is( $text, 'plain text output', 'AC-7: non-JSON stdout passes through as trimmed text' );

    # Also exercised via the AUTOLOAD path, per AC-5's "single-word method"
    # contract - same stub, different call shape.
    my $via_autoload = $handle->text_thing;    # method name -> AUTOLOAD -> run('text_thing')
    ok( !defined($via_autoload) || $via_autoload eq '',
        'AUTOLOAD maps the METHOD name verbatim (underscore, not the hyphenated CLI form) - no matching stub case, so empty/undef, not a die' );

    my $failed = eval { $handle->run('fail-thing'); 1 };
    ok( !$failed, 'AC-8: a nonzero exit dies' );
    like( $@, qr/stub failure detail/, 'AC-8: and stderr is attached to the die message' );
}

# Coverage: new() with no explicit cwd falls back to Cwd::cwd() - exercises
# the "defined-or fell through" leg that every other test in this file
# avoids by always passing cwd explicitly.
{
    my $handle = Developer::Dashboard::Handle->new;
    is( $handle->{cwd}, getcwd(), 'new() with no cwd falls back to Cwd::cwd()' );
}

# Coverage: run() validates its own subcommand argument - both the "missing
# entirely" and "present but empty" shapes of the guard.
{
    my $handle = Developer::Dashboard::Handle->new( cwd => $home );

    my $ok_undef = eval { $handle->run(undef); 1 };
    ok( !$ok_undef, 'run() with no subcommand dies' );
    like( $@, qr/Missing subcommand/, 'and names the reason' );

    my $ok_empty = eval { $handle->run(''); 1 };
    ok( !$ok_empty, 'run() with an empty-string subcommand dies the same way' );
    like( $@, qr/Missing subcommand/, 'and names the reason' );
}

# Coverage: calling ->paths (and so ->_registry) twice on the SAME handle
# exercises the memoization hit inside _registry's own cache, not just
# paths()'s cache above it.
{
    my $handle = Developer::Dashboard::Handle->new( cwd => $home );
    my $first  = $handle->_registry;
    my $second = $handle->_registry;
    is( refaddr($first), refaddr($second), '_registry() memoizes per handle, not just paths()' );
}

# Coverage: JSON-shaped stdout that decodes successfully but to a non-
# reference scalar (a bare JSON number) must still pass through as text,
# not be mistaken for the decoded-structure case.
{
    my $bin_dir = tempdir( CLEANUP => 1 );
    my $stub    = File::Spec->catfile( $bin_dir, 'dashboard' );
    open my $fh, '>', $stub or die $!;
    print {$fh} <<'STUB';
#!/bin/sh
case "$1" in
  number-thing) echo '42' ;;
esac
STUB
    close $fh;
    chmod 0755, $stub;
    local $ENV{PATH} = "$bin_dir:$ENV{PATH}";

    my $handle = Developer::Dashboard::Handle->new( cwd => $home );
    my $result = $handle->run('number-thing');
    is( $result, '42', 'a JSON number decodes successfully but is not a ref, so it passes through as text' );
}

# Coverage: with no home directory resolvable at all (HOME and every
# Windows-style fallback var absent), _registry's own PathRegistry
# construction has nothing to fall back to and dies - exercising the
# $ENV{HOME} empty leg inside _registry.
{
    local $ENV{HOME} = '';
    local $ENV{USERPROFILE};
    local $ENV{HOMEDRIVE};
    local $ENV{HOMEPATH};
    delete $ENV{USERPROFILE};
    delete $ENV{HOMEDRIVE};
    delete $ENV{HOMEPATH};

    my $handle = Developer::Dashboard::Handle->new( cwd => $home );
    my $ok = eval { $handle->paths; 1 };
    ok( !$ok, 'with no resolvable home directory anywhere, paths() dies rather than silently using a wrong root' );
}

chdir $starting_cwd or die "Unable to chdir back to $starting_cwd: $!";

is( scalar(@warnings), 0, 'no warnings escaped: ' . join( '; ', @warnings ) );

done_testing;

__END__

=head1 NAME

t/166-dashboard-d2-handle.t - spec for the exported d2() Perl-code proxy

=head1 PURPOSE

Assert that C<d2()>, exported by L<Developer::Dashboard>, gives Perl code a
one-line equivalent of the C<dashboard>/C<d2> command line, both for the
fast in-process path-alias case and for the general subcommand proxy.

=head1 WHY IT EXISTS

DD-726: the project owner asked directly (over the project's Telegram
bridge) for C<< d2->paths->{foo} >> instead of hand-building a
PathRegistry/FileRegistry/Config, then widened the request to "anything I
can run with d2 on bash" - so both the fast path-alias accessor and the
general subcommand proxy (C<run()>/C<AUTOLOAD>) need their own coverage.

=head1 WHEN TO USE

Whenever C<Developer::Dashboard::d2>, C<Developer::Dashboard::Handle::paths>,
or C<Developer::Dashboard::Handle::run>/C<AUTOLOAD> changes.

=head1 HOW TO USE

    PERL5LIB="$HOME/perl5/lib/perl5" prove -lv t/166-dashboard-d2-handle.t

=head1 WHAT USES IT

Nothing in the shipped CLI itself uses C<d2()> - it is a convenience
entrypoint for external Perl code embedding this distribution.

=head1 EXAMPLES

The assertion that matters reads as the property it protects:

    d2->paths->{name} matches what `dashboard path resolve name` prints

=cut
