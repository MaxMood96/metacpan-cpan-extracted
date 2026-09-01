package Punk::Plugin::Authorisation;

use 5.010;
use strict;
use warnings;
use parent 'Punk::Plugin';
use Punk::Authorisation ();

our $VERSION = '0.01';

1;

__END__

=head1 NAME

Punk::Plugin::Authorisation - may this user act on this row

=head1 SYNOPSIS

    # lib/Shop.pm
    auth model => 'User', rank => [qw(member admin owner)], roles => sub { ... };
    plugin 'Authorisation';                       # rules: Shop::Authorisation

    # lib/Shop/Authorisation.pm
    package Shop::Authorisation;
    use Punk::Plugin::Authorisation;              # installs `rule`

    rule 'key.issue'  => sub { $_[0]->auth_id };
    rule 'key.revoke' => sub {
        my ($c, $key) = @_;
        return 1 if $key && $key->{owner_id} == $c->auth_id;
        return $c->forbidden if $c->rank_at_least('admin');
        return $c->not_yours;
    };
    1;

    # in a controller
    my $key = $c->model('ApiKey')->get(id => $c->param('id'));
    $c->may('key.revoke', $key) or return $c->deny;

=head1 DESCRIPTION

C<auth_guard> answers B<may this user reach this route>. An API key's
scope answers B<may this credential call this operation>. Neither can
answer B<may this user act on this row>, and that is where the commonest
authorisation bug in a web application lives: the controller that loads a
row by an id from the request and forgets to ask whose it is.

This plugin is the asking. The rules are the application's and live in one
package it owns; what lives here is the machinery around them - collecting
them, refusing to guess at a name nobody defined, and turning a refusal
into the right status.

=head2 Every refusal is false

A rule returns true to allow. To refuse it returns a plain false value, or
one of two helpers that are B<also false> and say which refusal was meant:

    return $c->forbidden;    # it exists, and it is not yours to touch  -> 403
    return $c->not_yours;    # and do not confirm that it exists        -> 404

There is deliberately no truthy refusal. A convention where a rule returns
C<-1> for "not enough rank" reads well and is a hole: C<-1> is true in
Perl, so C<< $c->may(...) or return $c->deny >> would allow it.

=head1 OPTIONS

=over 4

=item C<policy>

The package holding the rules; C<< <AppClass>::Authorisation >> by default,
so an application named C<Shop> writes them in F<lib/Shop/Authorisation.pm>
and says nothing here. It is
loaded at registration, and a package that defines no rules croaks.

=item C<rank>

The ladder C<rank_at_least> compares against, lowest role first. Taken
from the C<auth> keyword through C<< $app->auth_config >> (Punk 0.32 and
later), so an application on a Punk that provides it says nothing here.

B<Without a ladder the plugin croaks at C<to_app>>, naming both ways to
give it one. It could instead let C<rank_at_least> croak per request, and
that would be a 500 for something knowable at boot. A policy that never
calls C<rank_at_least> says so with C<< rank => [] >>.

=item C<roles>

The hook that says which roles the signed-in user holds, C<< sub { my
($c, $user) = @_; ... } >>, returning a name, a list or an arrayref - the
same one C<auth> takes. From C<auth> as well, and needed here for the
same reason C<rank> is: a Punk without C<< $app->auth_config >> (before
0.32) cannot be asked for either, and a ladder with no hook answers "no"
to everything.

A guard that has already run leaves its roles in
C<< $c->stash->{auth}{roles} >> and those are preferred; the hook is for
every other request.

=item C<grants>

The model holding runtime grants; off unless given. See L</GRANTS>.

=item C<fields>

The grants model's column names: C<subject>, C<action>, C<object>,
C<granted_by>, C<created>.

=back

=head1 HELPERS

=head2 may($action, @subject)

The rule for C<$action>, as C<0> or C<1>, called as
C<< $code->($c, @subject) >> in scalar context. An action no rule defines
B<croaks>, naming the actions that exist: a typo must never decide. Nothing
is cached, because a rule reads rows this request may already have changed.

=head2 deny($why?)

The refusal. The status is the one the rule recorded through C<forbidden>
or C<not_yours>; without one it is B<404> when the check carried a subject
and B<403> when it did not, since a subject means a row whose existence is
nobody's business. A 404 with no message goes through C<< $c->not_found >>,
so an application's C<on_not_found> page answers it. Otherwise a browser
(by C<Accept>) gets a page and anything else the house
C<< {"errors":[...]} >> shape, as C<auth_guard>'s denial does. C<$why>
overrides the message, never the status.

=head2 forbidden / not_yours

False, and the reason C<deny> reads.

=head2 rank_at_least($name)

Whether the signed-in user holds a role at or above C<$name> on the
ladder. A name that is not on the ladder croaks. Roles come from the
C<auth> keyword's own C<roles> hook - the same answer C<auth_guard(role
=> ...)> acts on - or from C<< $c->stash->{auth}{roles} >> when a guard
has already loaded them.

=head1 GRANTS

    plugin 'Authorisation' => { grants => 'Grant' };

    rule 'doc.edit' => sub {
        my ($c, $doc) = @_;
        return 1 if $doc->{owner_id} == $c->auth_id;   # ownership first
        return 1 if $c->granted('doc.edit', $doc->{id});
        return $c->not_yours;
    };

    $c->grant('doc.edit', $doc->{id}, to => $user_id);
    $c->revoke_grant('doc.edit', $doc->{id}, from => $user_id);

Off unless asked for, and worth three sentences before it is:

=over 4

=item *

A grant table is a B<second source of truth> wherever a rule already
encodes ownership. Ownership belongs in the rule; grants are for what one
user hands another.

=item *

C<granted> is a query, per call. The rule above tests ownership first, so
the request that did not need a grant does not pay for one.

=item *

Nothing is cached, because a revoked grant has to stop working at once.

=back

With Punk-Sqitch installed the table ships as the Sqitch project
C<punk_authz>; the DDL is in L<Punk::Model::Grant> for an application that
manages its schema another way.

=head1 SEE ALSO

L<Punk::Auth>, L<Punk::Plugin::APIKey>, L<Punk::Authorisation>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
