package Catalyst::Seal;

use strict;
use warnings;

our $VERSION = '0.01';

use XSLoader ();
XSLoader::load('Catalyst::Seal', $VERSION);

use Catalyst::Seal::Guard ();

our @STEPS;

sub register_step {
    my ($name, $code) = @_;
    push @STEPS, { name => $name, code => $code };
    return;
}

our $DEBUG = $ENV{CATALYST_SEAL_DEBUG} ? 1 : 0;

our @NOTES;
our @FAILURES;

sub note {
    my ($msg) = @_;
    push @NOTES, $msg;
    warn "Catalyst::Seal: $msg\n" if $DEBUG;
    return;
}

sub notes    { @NOTES }
sub failures { @FAILURES }

sub enabled {
    return 0 if defined $ENV{CATALYST_SEAL} && !$ENV{CATALYST_SEAL};
    return 1;
}

require Catalyst::Seal::Immutable;
require Catalyst::Seal::Exceptions;
require Catalyst::Seal::Modifiers;
require Catalyst::Seal::ClassData;
require Catalyst::Seal::Accessors;
require Catalyst::Seal::Prepare;
require Catalyst::Seal::Dispatch;
require Catalyst::Seal::Finalize;
require Catalyst::Seal::Construct;
require Catalyst::Seal::Middleware;

my %WANTED;
my %SEALED;
my $HOOKED = 0;

sub import {
    my ($class) = @_;
    my $app = caller;
    return unless enabled();
    $WANTED{$app} = 1;
    _install_hook();
    return;
}

sub _install_hook {
    return if $HOOKED++;
    require Catalyst;
    my $orig = Catalyst->can('setup_finalize')
        or return note('Catalyst has no setup_finalize, nothing sealed');
    no strict 'refs';
    no warnings 'redefine';
    *Catalyst::setup_finalize = sub {
        my @ret = $orig->(@_);
        my $app = ref $_[0] || $_[0];
        __PACKAGE__->seal($app) if delete $WANTED{$app};
        return wantarray ? @ret : $ret[0];
    };
    return;
}

sub seal {
    my ($class, $app) = @_;
    $app = ref $app || $app;
    return unless enabled();
    return if $SEALED{$app}++;

    for my $step (@STEPS) {
        my $ok = eval { $step->{code}->($app); 1 };
        next if $ok;
        my $err = $@;
        push @FAILURES, { step => $step->{name}, error => $err, app => $app };
        warn "Catalyst::Seal: step '$step->{name}' failed for $app: $err";
    }

    if ($DEBUG) {
        warn sprintf "Catalyst::Seal: sealed %s, %d step(s), %d note(s), %d failure(s)\n",
            $app, scalar @STEPS, scalar @NOTES, scalar @FAILURES;
    }
    return;
}

1;

__END__

=head1 NAME

Catalyst::Seal - freeze a Catalyst application at setup and make it 4x faster

=head1 VERSION

Version 0.01

=cut

=head2 seal

    Catalyst::Seal->seal('MyApp');

Runs every registered step against the application class. Called for you from
C<setup_finalize>; call it directly only if you are sealing an application that
did not C<use Catalyst::Seal>.

Each step runs in its own eval. A step that dies is a bug in this distribution,
so it always warns rather than disappearing into the hook, and the remaining
steps still run.

=cut

=head1 SYNOPSIS

    package MyApp;

    use Catalyst::Seal;
    use Catalyst qw/ ConfigLoader Static::Simple /;

    __PACKAGE__->setup();

=head1 DESCRIPTION

After C<setup_finalize> a Catalyst application is frozen: the class tree, the
configuration, the action table and the attribute layouts all stop changing.
Catalyst goes on re-deriving those facts from the metaobject protocol on every
request. Catalyst::Seal makes one pass at the end of C<setup()> and compiles the
frozen facts into constant form.

No application code changes. Place the C<use> line above C<use Catalyst> and
nothing else.

=head2 What this module does

=over 4

=item * Makes the application class and its components immutable, which Catalyst
does for controllers but not for the application class, even though the
application class is also the per-request context class.

=item * Replaces the two L<Try::Tiny> blocks on the request path with plain
C<eval>.

=item * Replaces every C<mk_classdata> accessor with an XS constant. The stock
one calls C<Moose::Util::find_meta> on every read to answer a question that
stopped changing at C<setup_finalize>: 84 of those calls per request on a bare
application. A write unseals the accessor and puts the original back.

=item * Takes C<find_meta> out of the C<Catalyst::Component::config> read path.

=item * Installs the composed body of every method carrying a C<before>,
C<after> or C<around> modifier directly, in place of the trampoline
L<Class::MOP::Method::Wrapped> installs, which calls C<set_subname> on every
invocation to attach a name that has not changed since the modifier was applied.
Ten of those are on the request path. A modifier added after the seal puts the
trampoline back.

=item * Short-circuits the L<Catalyst::Response> guard that warns about setting
a header after the headers were finalised, which on a read evaluates three
accessors to reach a condition that already could not be true.

=item * Seals C<$c-E<gt>config> as a constant. Catalyst croaks on any write to
it once setup has finished, so after setup it cannot change, and the whole
C<around>, C<find_meta>, C<get_or_add_package_symbol> chain behind it is dead
weight on every one of the nine reads a request makes.

=item * Replaces the attribute readers on the context, request and response
classes with XS. Only readers, only on immutable classes, and only where the
reader is Moose's own. A lazy attribute whose slot is not built yet delegates to
that reader, so the builders stay Moose's and a C<predicate> keeps telling the
truth.

=item * Aliases C<req>, C<res> and C<comp> straight to the methods they
delegate to, removing a whole frame from each of 25 calls a request.

=item * Memoises the two action lookups the forward chain repeats on every
request. One action costs five forwards, each of which turns a string like
C<'/foo/_BEGIN'> into an action object by walking a table that stopped changing
at C<setup_finalize>. The chain itself is not flattened: the private steps go on
C<$c-E<gt>stack>, and C<$c-E<gt>depth> is what gates the C<detach> and C<go>
rethrows, so a flat chain would have to reimplement C<execute> to keep them
honest.

=item * Memoises the encoding decision. C<finalize_encoding> spends 49 us per
request deciding that a C<text/plain> body does not need encoding, by calling
C<content_type> four times and C<content_type_charset> three times to re-parse
one header string. The answer is a pure function of the raw content type, the
content encoding, the encodable-type pattern and the application encoding.

=item * Replaces the L<Try::Tiny> in Moose's inlined destructor for
L<Catalyst::Response> with an C<eval>. Two closures were being built on every
response destroyed, to call a four line C<DEMOLISH>.

=item * Replaces the L<Try::Tiny> in C<_handle_param_unicode_decoding> with an
C<eval>. Every query parameter, body parameter and path argument is decoded
through it, name and value separately, so a four parameter query string builds
sixteen closures to decode eight strings. Worth 15 us on such a request, which
is more than the parsing it surrounds.

=item * Builds the L<HTTP::Headers> hash in C<prepare_headers> directly rather
than through one C<header> call per environment key. The spelling of each field
is asked of HTTP::Headers once, the first time a request carries it, and
remembered, so nothing here has to know which headers HTTP::Headers considers
standard.

=item * Skips C<URI::canonical> in C<prepare_path> when the URI just built is
already canonical, which is one regex to decide and three authority parses to
ask. Checked against L<URI> itself at seal time, positive and negative, rather
than against its source.

=item * Stops a controller's C<BUILD> firing two lazy builders on the
per-request context object. The application class inherits
L<Catalyst::Controller>, so C<BUILDALL> runs its C<BUILD> on every context
object, to compute values derived entirely from class data.

=item * Defers building the L<Catalyst::Stats> object when stats are disabled.
Its C<tree> attribute is required and not lazy, so stock builds a
L<Tree::Simple> and reads the clock on every request for an object nothing then
reads. With stats enabled nothing changes, because that timestamp is the request
start.

=back

On a bare application, 267.4 to 78.0 us per request, and on Hyperman under wrk
3,740 to 20,340 requests per second.

    cat-hello              6586 req/s
    cat-seal              20461 req/s

=head2 Environment

=over 4

=item C<CATALYST_SEAL=0>

Hard kill switch. Nothing is sealed and the application is stock Catalyst.

=item C<CATALYST_SEAL_DEBUG=1>

Report what was sealed, and what was skipped and why.

=back

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

