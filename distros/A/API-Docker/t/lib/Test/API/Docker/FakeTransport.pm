package Test::API::Docker::FakeTransport;
use Moo;
extends 'API::Docker';

# A client whose socket is an in-memory sink and whose response is canned, so
# the real _request runs in full -- request-line assembly, header sanitising,
# chunked reading, status handling, the >= 400 croak path -- with nothing on
# the other end. This is the tool for request-shape assertions;
# Test::API::Docker::Mock replaces _request wholesale and cannot see any of
# that (see t/lib/Test/API/Docker/Mock.pm and karr k38).
#
# Lifted out of five near-identical copies (t/role_http.t, t/plugins.t,
# t/registry_auth.t, t/system_auth.t, t/distribution.t -- karr k38, which
# found them "the same ~12 lines, with slightly different helper subs
# around it"). The helper subs (fake_client, request_line, query_param, ...)
# stayed behind in each file: they differ on real per-file needs (different
# default status/body, different bits of the wire read back), so a shared
# version would either drop something a file uses or grow options nothing
# else asked for. Only this class -- canned, _sink, _build__socket,
# _read_response, written -- was identical enough to share.
#
# `written` was not quite identical, though. Three of the five copies
# (role_http.t, plugins.t, registry_auth.t) returned ${ $_[0]->_sink }
# unguarded, which dies if _sink is still undef -- true until the first
# request opens the in-memory socket via _build__socket. The other two
# (system_auth.t, distribution.t) guard it, because both call ->written
# after a request that croaks *before* _build__socket ever runs (a header
# name or argument-shape check, or this class's own validation) to assert
# that nothing reached the wire; without the guard that assertion would die
# instead of failing cleanly. The guarded form is a strict superset -- once
# _sink is defined it behaves exactly like the unguarded one -- so it is the
# one kept here rather than being offered as an option; the other three
# files never needed the guard and are unaffected by carrying it anyway.

has canned => (is => 'rw', default => sub { [200, 'OK', {}, ''] });
has _sink  => (is => 'rw');

sub _build__socket {
  my ($self) = @_;
  my $sink = '';
  $self->_sink(\$sink);
  open my $fh, '>', \$sink or die "open: $!";
  return $fh;
}

sub _read_response { return $_[0]->canned }

sub written {
  my ($self) = @_;
  my $sink = $self->_sink;
  return defined $sink ? $$sink : '';
}

1;
