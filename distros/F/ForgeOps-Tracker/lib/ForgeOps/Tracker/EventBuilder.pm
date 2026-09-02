package ForgeOps::Tracker::EventBuilder;

use strict;
use warnings;
use POSIX qw(strftime);
use ForgeOps::Tracker::PiiScrubber qw(scrub scrub_string);

my $MAX_FRAMES = 500;

sub new {
    my ($class, $configuration) = @_;
    return bless { configuration => $configuration }, $class;
}

# build($error, \%context) -- $error can be:
#   - a blessed exception object exposing ->message (or overloaded stringification) and,
#     optionally, ->trace returning a Devel::StackTrace-compatible object (frames() ->
#     filename/line/subroutine) -- e.g. Throwable::Error, Moo::Exception-based classes.
#   - a plain scalar, typically $@ after `die "..."` or `Carp::confess "..."` -- Perl appends
#     " at FILE line N." to any die message that doesn't already end in "\n", and Carp::confess
#     appends a full "\tPACKAGE::sub(...) called at FILE line N" chain on top of that; both are
#     parsed below into real backtrace frames rather than left as one opaque string, verified
#     directly against real confess()/die output before relying on the format, not assumed from
#     documentation alone.
sub build {
    my ($self, $error, $context) = @_;
    $context ||= {};
    my $config = $self->{configuration};

    my ($exception_class, $message, $backtrace) = $self->_analyze($error);

    my %payload = (
        exception_class => $exception_class,
        message         => $message,
        backtrace       => $backtrace,
        occurred_at     => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime),
        environment     => $config->{environment},
        release         => $config->{release},
        server_name     => $config->{server_name},
        context         => { %$context },
        tags            => {},
    );

    return $config->{scrub_pii} ? $self->_scrub_payload(\%payload) : \%payload;
}

sub _analyze {
    my ($self, $error) = @_;

    if (ref $error && eval { $error->can('message') }) {
        my $exception_class = ref $error;
        my $message = $error->message;
        my $backtrace = eval { $error->can('trace') } ? $self->_frames_from_stack_trace($error->trace) : [];
        return ($exception_class, $message, $backtrace);
    }

    # Plain scalar (the common case: $@). "RuntimeError" mirrors the other SDKs' own fallback
    # exception_class for an error with no more specific type available.
    my $text = "$error";
    my ($message, $backtrace) = $self->_parse_die_text($text);
    return ('RuntimeError', $message, $backtrace);
}

sub _frames_from_stack_trace {
    my ($self, $trace) = @_;
    my @frames;
    for my $frame ($trace->frames) {
        last if @frames >= $MAX_FRAMES;
        push @frames, $self->_frame($frame->filename, $frame->line, $frame->subroutine);
    }
    return \@frames;
}

sub _parse_die_text {
    my ($self, $text) = @_;
    my @lines = split /\n/, $text;
    return ('', []) unless @lines;

    my @frames;
    my $message = shift @lines;
    # "MESSAGE at FILE line N." -- what Perl itself appends to any die string not already ending
    # in "\n", and the first line Carp::confess/croak produce too.
    if ($message =~ s/\s+at\s+(\S+)\s+line\s+(\d+)\.\s*$//) {
        push @frames, $self->_frame($1, $2, undef);
    }

    # Remaining lines, present only from Carp::confess: "\tPACKAGE::sub(...) called at FILE line N"
    for my $line (@lines) {
        last if @frames >= $MAX_FRAMES;
        if ($line =~ /^\s*(\S+?)\(.*?\)\s+called\s+at\s+(\S+)\s+line\s+(\d+)/) {
            push @frames, $self->_frame($2, $3, $1);
        }
    }

    return ($message, \@frames);
}

sub _frame {
    my ($self, $file, $line, $method) = @_;
    return {
        file   => $file,
        line   => defined($line) ? $line + 0 : undef,
        method => $method,
        in_app => $self->_in_app($file),
    };
}

sub _in_app {
    my ($self, $file) = @_;
    my $root = $self->{configuration}{app_root};
    return 0 unless $file && $root;
    return 0 unless index($file, $root) == 0;
    # A vendored/system library installed alongside the app's own lib/ directory is never in_app,
    # the same exclusion every other SDK applies for its own package-manager directory.
    return $file !~ m{/(?:local|vendor)/lib/perl5/};
}

sub _scrub_payload {
    my ($self, $payload) = @_;
    my %scrubbed = %$payload;
    $scrubbed{message} = scrub_string($payload->{message});
    $scrubbed{backtrace} = [
        map {
            my %frame = %$_;
            $frame{file}   = scrub_string($frame{file})   if defined $frame{file};
            $frame{method} = scrub_string($frame{method}) if defined $frame{method};
            \%frame;
        } @{ $payload->{backtrace} }
    ];
    $scrubbed{context} = scrub($payload->{context});
    $scrubbed{tags}     = scrub($payload->{tags});
    return \%scrubbed;
}

1;
