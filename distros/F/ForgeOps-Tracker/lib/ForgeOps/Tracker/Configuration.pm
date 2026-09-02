package ForgeOps::Tracker::Configuration;

use strict;
use warnings;
use Cwd qw(getcwd);

# Holds a single ForgeOps DSN plus everything else the client needs to build and deliver events.
# Mirrors gems/forge_ops_tracker/lib/forge_ops_tracker/configuration.rb -- a single Sentry-style
# DSN string carries both the ingestion URL and the project's api_key:
# "https://<api_key>@host/api/v1/events". Hand-parsed with a regex rather than pulling in the URI
# module -- this SDK otherwise has zero non-core dependencies (HTTP::Tiny, threads, and
# Thread::Queue are all core as of the Perl versions this targets), and a DSN's shape is simple
# and fixed enough that a regex covers it completely without needing a general-purpose URI parser.
sub new {
    my ($class) = @_;
    return bless {
        dsn                  => $ENV{FORGE_OPS_DSN},
        environment          => $ENV{FORGE_OPS_ENVIRONMENT} || 'production',
        release              => $ENV{FORGE_OPS_RELEASE},
        server_name          => _safe_hostname(),
        app_root             => getcwd(),
        enabled_environments => { production => 1, staging => 1 },
        queue_size           => 1000,
        timeout              => 2, # seconds
        scrub_pii            => 1,
        logger               => undef, # coderef, or undef to log nowhere
    }, $class;
}

# https://<api_key>@host[:port]/path -- captures scheme, an optional userinfo (the api_key,
# percent-decoded), and everything from the host onward.
my $DSN_RE = qr{^(https?)://(?:([^:@/]*)@)?([^/]+)(/.*)?$};

sub _parsed_dsn {
    my ($self) = @_;
    return undef unless $self->{dsn};
    return undef unless $self->{dsn} =~ $DSN_RE;

    my ($scheme, $userinfo, $host, $path) = ($1, $2, $3, $4 // '');
    my $api_key = defined($userinfo) && length($userinfo) ? _uri_unescape($userinfo) : undef;
    return {
        scheme        => $scheme,
        api_key       => $api_key,
        ingestion_uri => "$scheme://$host$path",
    };
}

sub api_key {
    my ($self) = @_;
    my $parsed = $self->_parsed_dsn;
    return undef unless $parsed && defined $parsed->{api_key} && length $parsed->{api_key};
    return $parsed->{api_key};
}

# The ingestion URL with credentials stripped out (they travel as the Authorization header
# instead, never embedded in the request URI).
sub ingestion_uri {
    my ($self) = @_;
    my $parsed = $self->_parsed_dsn;
    return undef unless $parsed;
    return $parsed->{ingestion_uri};
}

sub is_enabled {
    my ($self) = @_;
    return 0 unless $self->{dsn};
    return 0 unless defined $self->api_key;
    return 0 unless $self->{enabled_environments}{ $self->{environment} };
    return 1;
}

sub log {
    my ($self, $message) = @_;
    $self->{logger}->($message) if $self->{logger};
}

sub _safe_hostname {
    require Sys::Hostname;
    my $name = eval { Sys::Hostname::hostname() };
    return $@ ? undef : $name;
}

sub _uri_unescape {
    my ($string) = @_;
    $string =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    return $string;
}

1;
