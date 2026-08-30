package Test::API::Docker::Mock;
use strict;
use warnings;
use JSON::MaybeXS qw( decode_json encode_json );
use Path::Tiny;
use Carp qw( croak shortmess );
use API::Docker::Error::HTTP;
use Test::More;

use Exporter 'import';
our @EXPORT = qw(
  test_docker
  load_fixture
  load_fixture_raw
  mock_response
  is_live
  can_write
  skip_unless_write
  check_live_access
  register_cleanup
  live_engine
);

my $FIXTURES_DIR = path(__FILE__)->parent->parent->parent->parent->parent->child('fixtures');

my @_cleanups;

sub load_fixture {
  my ($name) = @_;
  my $file = $FIXTURES_DIR->child("$name.json");
  croak "Fixture not found: $file" unless $file->exists;
  return decode_json($file->slurp_utf8);
}

# Some fixtures are not JSON: the framed log/exec streams are captured
# engine bytes, and the build/pull event streams are newline-delimited JSON
# whose line framing is the thing under test. Both must come back byte-exact.
sub load_fixture_raw {
  my ($name) = @_;
  my $file = $FIXTURES_DIR->child($name);
  croak "Fixture not found: $file" unless $file->exists;
  return $file->slurp_raw;
}

# The status line and the response headers reach a caller through the
# `response` out-parameter of _request, which the mock replaces wholesale --
# so without this a mocked route cannot say 304, and the very distinction
# API::Docker::API::Containers/start now makes would be untestable offline.
# A plain route keeps working and gets a status inferred from its value.
#
# The error phrases are here because API::Docker::Error::HTTP carries
# `reason` as well: a mocked 404 falling through to 'Unknown' would put a
# value on the exception that no engine ever sends.
my %REASON = (
  200 => 'OK',
  204 => 'No Content',
  304 => 'Not Modified',
  400 => 'Bad Request',
  401 => 'Unauthorized',
  403 => 'Forbidden',
  404 => 'Not Found',
  409 => 'Conflict',
  500 => 'Internal Server Error',
);

sub mock_response {
  my (%args) = @_;
  my $status = $args{status} // 200;
  # _read_response lowercases every header name it collects; a mock that kept
  # the wire capitalisation would let a test pass against a key the real
  # transport never produces.
  my %headers = map { lc($_) => $args{headers}{$_} } keys %{ $args{headers} || {} };
  return bless {
    status  => $status,
    reason  => $args{reason} // $REASON{$status} // 'Unknown',
    headers => \%headers,
    data    => $args{data},
    stream  => $args{stream},
  }, 'Test::API::Docker::Mock::Response';
}

# The units a route hands to an on_event/on_frame/on_chunk callback. A route
# that says nothing gets them inferred from its data, so an existing ndjson
# route -- whose value is already the ArrayRef of events -- streams without
# being rewritten; `stream => [...]` is for a route whose buffered value and
# whose stream units differ, and for one that has to deliver more units than
# its return value has elements.
sub _mock_stream_units {
  my ($response) = @_;

  return $response->{stream} if defined $response->{stream};
  return [] unless defined $response->{data};
  return $response->{data} if ref $response->{data} eq 'ARRAY';
  return [ $response->{data} ];
}

# The mock replaces _request wholesale, so the callback path exists here only
# because it is written here too. It is the transport's contract and not a
# second one: one unit per call, a $stop closure as the second argument, the
# return value ignored, and the summary HashRef back.
sub _mock_stream {
  my ($cb, $response) = @_;

  my $units     = _mock_stream_units($response);
  my $delivered = 0;
  my $stopped   = 0;
  my $stop      = sub { $stopped = 1; return };

  for my $unit (@$units) {
    $delivered++;
    $cb->($unit, $stop);
    last if $stopped;
  }

  return { delivered => $delivered, stopped => $stopped ? 1 : 0 };
}

# Mirrors the >= 400 branch of API::Docker::Role::HTTP::_request byte for
# byte: same fallback order (message, then errorDetail.message, then the flat
# error key, then the raw body), the same croak text and the same
# API::Docker::Error::HTTP carrying it. A route hands back
# already-decoded Perl data rather than wire bytes, so a ref is JSON-encoded
# first to reach the string _request would have started from; a route that
# means to send a body the engine would not even recognise as JSON can pass a
# plain string as `data` instead, same as the real 500-with-plain-text case.
sub _mock_croak {
  my ($status, $reason, $data) = @_;

  my $body = ref $data ? encode_json($data) : $data;
  $body = '' unless defined $body;

  my $error_msg = $body;
  my $decoded;
  if ($body && $body =~ /^\s*[\{\[]/) {
    eval {
      $decoded = decode_json($body);
      my $detail = ref $decoded->{errorDetail} eq 'HASH'
        ? $decoded->{errorDetail}{message} : undef;
      $error_msg = $decoded->{message} // $detail // $decoded->{error} // $body;
    };
  }

  # The class too, not just the text: a mock that kept croaking strings would
  # leave the whole fixture suite blind to the exception _request now raises,
  # and every ->status assertion would have to be gated on is_live().
  my $error = API::Docker::Error::HTTP->new(
    message  => "Docker API error ($status): $error_msg",
    location => shortmess(''),
    status   => $status,
    reason   => $reason // '',
    body     => $body,
    data     => $decoded,
  );
  croak $error;
}

sub is_live {
  return !!$ENV{API_DOCKER_TEST_HOST};
}

sub can_write {
  return is_live() && !!$ENV{API_DOCKER_TEST_WRITE};
}

sub skip_unless_write {
  if (is_live() && !can_write()) {
    plan skip_all => 'Write tests skipped (set API_DOCKER_TEST_WRITE=1 to enable)';
  }
}

sub check_live_access {
  return unless is_live();

  my $host = $ENV{API_DOCKER_TEST_HOST};
  if ($host =~ m{^unix://(.+)$}) {
    unless (-S $1) {
      plan skip_all => "Docker socket $1 not available";
    }
  }

  eval {
    require API::Docker;
    my $docker = API::Docker->new(host => $host);
    my $result = $docker->system->ping;
    die "ping failed" unless $result eq 'OK';
  };
  if ($@) {
    plan skip_all => "Docker daemon not reachable at $host: $@";
  }
}

# Which daemon a live run is actually talking to. Docker and Podman diverge
# in ways the Engine API reference does not document -- the X-Docker-
# Container-Path-Stat isDir key and symlink resolution are the first two --
# and picking those apart needs one place any live subtest can ask, rather
# than each one re-deriving it from whatever field happens to be missing.
# GET /version's Components carries an entry named "Podman Engine" on Podman
# and never does on Docker, whose own engine entry is named plain "Engine"
# (measured: Docker 29.7.2/API 1.55, Podman 5.4.2/API 1.41) -- a name check,
# not a feature sniff, so a future divergence gets its own assertion instead
# of being inferred from whether a response happens to carry an extra key.
# Cached for the process: the engine on the other end of
# $ENV{API_DOCKER_TEST_HOST} does not change mid-run.
my $_live_engine;

sub live_engine {
  return $_live_engine if defined $_live_engine;
  return '' unless is_live();

  require API::Docker;
  my $docker = API::Docker->new(host => $ENV{API_DOCKER_TEST_HOST});
  my $version = eval { $docker->system->version } || {};
  my @components = @{ $version->{Components} || [] };
  my $is_podman = grep { ($_->{Name} // '') eq 'Podman Engine' } @components;

  return $_live_engine = $is_podman ? 'podman' : 'docker';
}

sub register_cleanup {
  my ($code) = @_;
  push @_cleanups, $code;
}

sub _run_cleanups {
  for my $cleanup (reverse @_cleanups) {
    eval { $cleanup->() };
    warn "Cleanup failed: $@" if $@;
  }
  @_cleanups = ();
}

sub test_docker {
  my (%routes) = @_;

  if (is_live()) {
    require API::Docker;
    return API::Docker->new(host => $ENV{API_DOCKER_TEST_HOST});
  }

  return _mock_docker(%routes);
}

sub _mock_docker {
  my (%routes) = @_;

  unless (grep { /version/ } keys %routes) {
    $routes{'GET /version'} = load_fixture('system_version');
  }

  require API::Docker;

  # Pinned rather than left to negotiate: setting api_version here means
  # negotiate_version's own guard ("return if defined $self->api_version",
  # API::Docker.pm) short-circuits for every mocked client, so this number
  # is never actually read off the injected 'GET /version' route -- it is
  # read back as-is by anything that asserts $docker->api_version (only
  # t/version.t does). Kept equal to t/fixtures/system_version.json's own
  # ApiVersion (karr k101: Docker Engine Community 29.7.2, API 1.55) so the
  # two do not silently drift apart the way they did when the fixture was
  # hand-rolled at '1.47' to match this literal instead of the other way
  # round.
  my $docker = API::Docker->new(
    host        => 'unix:///var/run/docker.sock',
    api_version => '1.55',
  );

  my $mock_request = sub {
    my ($self, $method, $path, %opts) = @_;

    my $clean_path = $path;
    $clean_path =~ s{^/v[\d.]+}{};

    my $key = "$method $clean_path";

    my $handler;
    my $matched = 0;
    if (exists $routes{$key}) {
      $handler = $routes{$key};
      $matched = 1;
    }
    else {
      for my $pattern (keys %routes) {
        my ($route_method, $route_path) = split /\s+/, $pattern, 2;
        next unless $method eq $route_method;
        # \Q...\E: $route_path is a literal path, not a regex a test author
        # wrote on purpose -- interpolated unescaped, a route key containing
        # a regex metacharacter (`.`, `?`, `+`, `(` ...) was read as a
        # pattern rather than as the literal string it looks like, and could
        # match a different path than the one it was registered for (or
        # croak on an unbalanced `(`). This tier still tolerates only
        # whitespace between method and path -- the exact-match branch above
        # is the fast path for everything else. See t/mock_harness.t.
        next unless $clean_path =~ m{^\Q$route_path\E$};
        $handler = $routes{$pattern};
        $matched = 1;
        last;
      }
    }

    croak "No mock route for: $key (available: " . join(', ', sort keys %routes) . ")"
      unless $matched;

    # A mocked request can never time out -- nothing here reads a socket, and
    # nothing here opens one -- so read_timeout and connect_timeout are both
    # accepted and ignored, exactly as a route ignores every other transport
    # option. What is not ignored is their shape: that is part of the contract
    # this stands in for, and a value the real transport would refuse has to
    # fail here rather than only once a test is run live. The role's own
    # checks are called rather than copied, so the two cannot drift.
    $self->_read_timeout_value($opts{read_timeout})
      if exists $opts{read_timeout};
    $self->_connect_timeout_value($opts{connect_timeout})
      if exists $opts{connect_timeout};

    my $result = ref $handler eq 'CODE'
      ? $handler->($method, $clean_path, %opts)
      : $handler;

    # A route that says nothing about the status gets the one the daemon
    # would have sent for that body: 200 with one, 204 without. A route built
    # with mock_response() carries its own status and headers.
    my $response = ref $result eq 'Test::API::Docker::Mock::Response'
      ? $result
      : mock_response(status => (defined $result ? 200 : 204), data => $result);

    if (my $out = $opts{response}) {
      %$out = (
        status  => $response->{status},
        reason  => $response->{reason},
        headers => $response->{headers},
      );
    }

    # Filled above, croaked below -- the same order _request keeps, so an
    # eval-ing caller can still read the status of a mocked failure. A >= 400
    # route never reaches a streaming callback either: the real transport
    # reads such a body whole before the croak (_read_streaming_response
    # returns it with no summary), so the callback is not invoked here.
    _mock_croak($response->{status}, $response->{reason}, $response->{data})
      if $response->{status} >= 400;

    my @streaming = grep { exists $opts{$_} } qw( on_event on_frame on_chunk );
    croak "Mock route $key got more than one of on_event, on_frame, on_chunk: "
      . join(' and ', @streaming) if @streaming > 1;
    return _mock_stream($opts{$streaming[0]}, $response) if @streaming;

    return $response->{data};
  };

  my $mock_pkg = "API::Docker::Mock::" . int(rand(1_000_000));
  {
    no strict 'refs';
    @{"${mock_pkg}::ISA"} = ('API::Docker');
    *{"${mock_pkg}::_request"} = $mock_request;
  }

  bless $docker, $mock_pkg;
  return $docker;
}

END { _run_cleanups() }

1;
