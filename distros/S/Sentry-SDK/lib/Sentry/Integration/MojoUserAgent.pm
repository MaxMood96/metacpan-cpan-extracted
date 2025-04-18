package Sentry::Integration::MojoUserAgent;
use Mojo::Base 'Sentry::Integration::Base', -signatures;

use Mojo::Util qw(dumper);
use Sentry::Util 'around';

has breadcrumbs => 1;
has tracing     => 1;

sub setup_once ($self, $add_global_event_processor, $get_current_hub) {
  return if (!$self->breadcrumbs && !$self->tracing);

  around(
    'Mojo::UserAgent',
    start => sub ($orig, $ua, $tx, $cb = undef) {
      my $url = $tx->req->url;

      # Exclude Requests to the Sentry server
      return $orig->($ua, $tx, $cb)
        if $tx->req->headers->header('x-sentry-auth');

      my $hub = $get_current_hub->();

      my $span;

      if ($self->tracing && (my $parent_span = $hub->get_scope()->get_span)) {
        $span = $parent_span->start_child({
          op          => 'http',
          name        => 'My Transaction',
          description => $tx->req->method . ' ' . $tx->req->url->to_string,
          data        =>
            { url => $tx->req->url->to_string, method => $tx->req->method, },
        });

      }

      my $result = $orig->($ua, $tx, $cb);

      $hub->add_breadcrumb({
        type     => 'http',
        category => 'Mojo::UserAgent',
        data     => {
          url         => $tx->req->url->to_string,
          method      => $tx->req->method,
          status_code => $tx->res->code,
        },
      })
        if $self->breadcrumbs;

      if ($span) {
        if (my $http_status = $tx->res->code) {
          $span->set_http_status($http_status);
        }
        $span->finish();
      }

      return $result;
    }
  );
}

1;
