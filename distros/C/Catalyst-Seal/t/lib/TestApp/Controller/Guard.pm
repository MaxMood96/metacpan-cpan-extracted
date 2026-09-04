package TestApp::Controller::Guard;

use strict;
use warnings;
use base 'Catalyst::Controller';

__PACKAGE__->config(namespace => 'guard');

# Actions whose match() depends on request state other than the path.
# Catalyst::ActionRole::HTTPMethods is the one in core; ConsumesContent,
# Scheme and QueryMatching wrap match() the same way.
#
# CVE-2026-85491: a route memo keyed on the path alone is wrong for every one
# of these, because the same path matches or does not depending on the method.

sub post_only :Path('/guard/post') :Method('POST') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain');
    $c->res->body('post-only');
}

# A shallower action that accepts any method and takes the last segment as an
# argument, sitting under a deeper one that only accepts POST. A GET of the
# deep path descends past it and lands here; a POST must not.
sub shallow :Path('/guard/thing') :Args(1) {
    my ($self, $c, $arg) = @_;
    $c->res->content_type('text/plain');
    $c->res->body("shallow:$arg");
}

sub deep :Path('/guard/thing/edit') :Method('POST') :Args(0) {
    my ($self, $c) = @_;
    $c->res->content_type('text/plain');
    $c->res->body('deep');
}

1;
