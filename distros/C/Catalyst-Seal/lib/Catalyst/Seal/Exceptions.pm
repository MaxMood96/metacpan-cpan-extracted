package Catalyst::Seal::Exceptions;

use strict;
use warnings;

use Carp ();
use Scalar::Util ();

use Catalyst::Seal ();
use Catalyst::Seal::Guard ();

our $VERSION = '0.01';

# Catalyst.pm:2405 as of 5.90132
sub _handle_request {
    my ( $class, @arguments ) = @_;

    # Always expect worst case!
    my $status = -1;

    my $ok = eval {
        if ($class->debug) {
            my $secs = time - $Catalyst::START || 1;
            my $av = sprintf '%.3f', $Catalyst::COUNT / $secs;
            my $time = localtime time;
            $class->log->info("*** Request $Catalyst::COUNT ($av/s) [$$] [$time] ***");
        }

        my $c = $class->prepare(@arguments);
        $c->dispatch;
        $status = $c->finalize;
        1;
    };

    unless ($ok) {
        my $error = $@;
        # rethrow if this can be handled by middleware
        if ( $class->_handle_http_exception($error) ) {
            $error->can('rethrow') ? $error->rethrow : Carp::croak $error;
        }
        chomp(my $message = $error);
        $class->log->error(qq/Caught exception in engine "$message"/);
    }

    $Catalyst::COUNT++;

    if (my $coderef = $class->log->can('_flush')) {
        $class->log->$coderef();
    }
    return $status;
}

# Catalyst.pm:2450 as of 5.90132
sub _prepare {
    my ( $class, @arguments ) = @_;

    $class->context_class( ref $class || $class ) unless $class->context_class;

    my $uploadtmp = $class->config->{uploadtmp};
    my $c = $class->context_class->new({ $uploadtmp ? (_uploadtmp => $uploadtmp) : ()});

    $c->response->_context($c);

    if ($c->use_stats
        || !$Catalyst::Seal::Construct::LAZY_STATS{ ref($c) || $c }) {
        $c->stats($class->stats_class->new)->enable($c->use_stats);
    }

    if ( $c->debug || $c->config->{enable_catalyst_header} ) {
        $c->res->headers->header( 'X-Catalyst' => $Catalyst::VERSION );
    }

    my $ok = eval {
        # Allow engine to direct the prepare flow (for POE)
        if ( my $prepare = $c->engine->can('prepare') ) {
            $c->engine->$prepare( $c, @arguments );
        }
        else {
            $c->prepare_request(@arguments);
            $c->prepare_connection;
            $c->prepare_query_parameters;
            $c->prepare_headers;
            $c->prepare_cookies;
            $c->prepare_path;

            $c->prepare_read;

            unless ( ref($c)->config->{parse_on_demand} ) {
                $c->prepare_body;
            }
        }
        $c->prepare_action;
        1;
    };

    unless ($ok) {
        my $error = $@;
        if ( $c->_handle_http_exception($error) ) {
            foreach my $err (@{$c->error}) {
                $c->log->error($err);
            }
            $c->clear_errors;
            $c->log->_flush if $c->log->can('_flush');
            $error->can('rethrow') ? $error->rethrow : Carp::croak $error;
        } else {
            $c->response->status(400);
            $c->response->content_type('text/plain');
            $c->response->body('Bad Request');
            $c->finalize;
            die $error;
        }
    }

    $c->log_request;
    $c->{stash} = $c->stash;
    Scalar::Util::weaken($c->{stash});

    return $c;
}

my $DONE = 0;

Catalyst::Seal::register_step('exceptions' => sub {
    return if $DONE++;
    Catalyst::Seal::Guard::replace('Catalyst::handle_request' => \&_handle_request);
    Catalyst::Seal::Guard::replace('Catalyst::prepare'        => \&_prepare);
    return;
});

1;

__END__

=head1 NAME

Catalyst::Seal::Exceptions - plain eval in place of Try::Tiny on the request path

=head1 DESCRIPTION

Catalyst wraps two things on every request in L<Try::Tiny>: the whole of
C<handle_request>, and the engine calls inside C<prepare>. Each C<try> builds
two closures, names them with C<set_subname>, and dispatches through
C<Try::Tiny::try>'s own prototype handling. C<Catalyst::execute> already uses a
plain C<eval> for the same job.

The replacements below are the stock subroutines with C<try>/C<catch> rewritten
as C<eval>, and nothing else changed. They are a copy of Catalyst 5.90132, so a
Catalyst that has rewritten either of them is a Catalyst these are stale for.

=head2 What has to survive

=over 4

=item * C<$@> is captured on the statement immediately after the eval, before
anything else can run and clobber it.

=item * The C<eval { ...; 1 }> idiom decides success, not the truth of C<$@>.
Catalyst throws exception objects, and C<Catalyst::Exception::Detach> and
friends can overload boolean. Testing C<$@> would drop them.

=item * C<$COUNT>, C<$START> and C<$VERSION> are package variables in
C<Catalyst>, so the replacements reach them by full name.

=item * Try::Tiny runs its body in a subroutine and this runs it in a block. No
body here contains C<return>, C<next> or C<wantarray>, so the two are
equivalent, and the context object still falls out of scope at the same point.

=back

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

