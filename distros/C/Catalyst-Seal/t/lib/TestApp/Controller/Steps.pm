package TestApp::Controller::Steps;

use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config(namespace => 'steps');

# A controller with a real begin / auto / end chain, so the flattened dispatch
# has something to be wrong about. Every step appends to a trace and the
# actions put the trace in the body, so the parity test compares the *order*
# the chain ran in rather than only the status it ended on.
#
# Root has a begin and an auto of its own, which makes this namespace's chain
# two autos deep: get_actions walks the containers from the root down.

sub _trace {
    my ($c, $what) = @_;
    push @{ $c->stash->{trace} ||= [] }, $what;
    return;
}

sub begin :Private {
    my ($self, $c) = @_;
    _trace($c, 'steps-begin');
}

sub auto :Private {
    my ($self, $c) = @_;
    _trace($c, 'steps-auto');
    # A false auto halts the remaining steps. end must still run.
    return 0 if $c->req->path =~ m{halt\z};
    return 1;
}

sub end :Private {
    my ($self, $c) = @_;
    _trace($c, 'steps-end');
    $c->res->content_type('text/plain');
    $c->res->body(join ',', @{ $c->stash->{trace} || [] })
        unless length($c->res->body || '');
}

sub okay :Path('/steps/ok') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
}

sub halt :Path('/steps/halt') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action-should-not-run');
}

sub boom :Path('/steps/boom') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
    die "boom in a chained action\n";
}

sub detached :Path('/steps/detach') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
    $c->detach('/steps/target');
    _trace($c, 'after-detach-should-not-run');
}

sub target :Path('/steps/target') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'target');
}

sub forwarding :Path('/steps/forward') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
    $c->forward('/steps/target');
    _trace($c, 'after-forward');
}

sub visiting :Path('/steps/visit') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
    $c->visit('/steps/target');
    _trace($c, 'after-visit');
}

# Deliberately unwise: forwarding to a path the caller supplied. Applications
# do this, and it is what turns the dispatch memo's keys into caller-controlled
# input. The fixture exists so the cap can be tested against the real path
# rather than by poking the memo directly.
sub fwd :Path('/steps/fwd') :Args(0) {
    my ($self, $c) = @_;
    _trace($c, 'action');
    my $to = $c->req->query_parameters->{to};
    $c->forward($to) if defined $to;
}

sub depth :Path('/steps/depth') :Args(0) {
    my ($self, $c) = @_;
    # The stack is what forward, detach and the error message read. Removing
    # frames from the chain changes what an action sees here.
    _trace($c, 'depth=' . $c->depth);
    _trace($c, 'stack=' . join('|', map { $_->name } @{ $c->stack }));
}

1;
