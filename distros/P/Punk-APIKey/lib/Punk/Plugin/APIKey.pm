package Punk::Plugin::APIKey;

use 5.010;
use strict;
use warnings;
use parent 'Punk::Plugin';
use Punk::APIKey ();
use Punk::Auth::Password ();

our $VERSION = '0.01';

1;

__END__

=head1 NAME

Punk::Plugin::APIKey - long-lived API credentials for Punk

=head1 SYNOPSIS

    package MyApp;
    use Punk;
    use Punk::Plugin::APIKey;      # compile time: the keywords parse

    auth model => 'User', rank => [qw(member admin owner)];

    plugin 'APIKey' => {
        model  => 'ApiKey',
        owner  => 'owner_id',
        kinds  => { live => 'sk_live_', test => 'sk_test_' },
        scopes => [qw(read write admin)],

        # a key answers to its owner's standing, not only to its own row
        owner_model => 'User',
        owner_ttl   => 30,
        scope_rank  => { read => 'member', write => 'member',
                         admin => 'admin' },
    };

    # the plaintext exists here and nowhere else
    my ($key, $row) = $c->api_key_issue(owner => $c->auth_id, label => 'CI',
                                        scopes => ['read'], kind => 'test');
    $c->api_key_revoke($row->{id});
    $c->api_keys($owner);          # prefix, label, scopes, last_used
    $c->api_key;                   # the row behind this request

    my $api = under '/api/v1' => api_key_guard(scope => 'read');
    under '/api/admin'           => api_key_guard(scope => 'admin');

    api 'openapi.json' => {
        security => { apiKey => api_key_checker(scope => 'write') },
    };

=head1 DESCRIPTION

A key is minted once, stored as a digest, presented as
C<Authorization: Bearer>, and checked by a guard that answers an API's
refusals rather than a browser's. It is scoped, revocable, rate limited per
key, and answerable to its owner's current standing.

=head2 The key

    <kind prefix><43 characters base64url><6 characters base62>
    sk_live_ + 32 bytes of entropy      + a CRC32 checksum

The random part comes from L<Punk::Auth::Password>'s C<token>, so the entropy
is Punk's and not a second implementation of it. What is stored is the
SHA-256 of the whole key - the same function and wire form C<auth_tokens>
uses - plus a C<prefix> column of the kind prefix and the first eight random
characters: enough to recognise a key in a list, not enough to rebuild one.

SHA-256 and not PBKDF2, deliberately. A password needs a slow hash because a
person chose it and the search space is small; a key with 256 bits of entropy
has no search space, and the lookup is an equality test on a unique index.

The checksum is not a security property - anyone can compute it - and it
earns its place twice anyway: a truncated or mistyped key is refused
B<before the database is touched>, and a secret scanner can recognise the
format and revoke a leaked key before anyone uses it.

=head1 OPTIONS

=over 4

=item model / fields / owner

The model the table is read through, the column names when they are not the
defaults, and which column holds the owner. When the application has no model
by the configured name, the one shipped here is registered instead.

=item kinds / prefix

C<< kinds => { live => 'sk_live_', test => 'sk_test_' } >>, or a single
C<prefix> when there is only one kind. Giving both croaks. What a kind
I<means> is the application's business; that a key's prefix claims one kind
while its row records another is this plugin's, and it is refused - the row
was written by this application and the prefix arrived from outside.

One prefix being a prefix of another is refused at boot: match order would
then be the only thing telling two credentials apart, and match order is a
rule nobody can see.

=item scopes

The vocabulary. A guard or an issue naming a scope outside it croaks - at
boot for a guard, which is the point.

Scopes are a flat set, not L<Punk::Auth>'s rank ladder: C<write> does not
imply C<read> unless the application issues both, because an API scope is a
permission and not a rank.

=item header

C<< header => 'X-Api-Key' >> for an API that already promised that spelling.
The default reads C<Authorization: Bearer>.

=item grace

How long a key replaced through C<< replaces => $id >> keeps working.
Default an hour, so a rotation does not break the deployment that has not
picked up the new key yet.

=back

=head1 THE OWNER'S STANDING

A key is a credential for an account, and an account's standing changes after
the key is minted. Without C<owner_model> a key answers only for itself: a
suspended user's key keeps working, and an C<admin>-scoped key outlives the
demotion that took C<admin> away, with revoking every key by hand as the only
remedy - which means the remedy is forgotten.

With it, the guard reads the owner behind a per-owner cache (C<owner_ttl>
seconds, bounded, per worker):

=over 4

=item An owner who is not there is a B<401>

The same answer as an unknown key. Which of the two it is would tell a caller
something they have no business learning.

=item A suspended owner is a B<403>

Not 401. The caller has already proved they hold the key, so there is nothing
to enumerate, and "your account is suspended" is the useful answer rather than
a lie about the credential.

=item A demotion B<narrows> the key

C<scope_rank> maps each scope to the minimum rank on C<auth>'s ladder that may
exercise it. A scope the owner's current role no longer reaches is dropped
from the effective set for that request; the key keeps the rest. A former
admin's CI keeps deploying and stops administering, which is what demotion
means.

C<< $c->api_key->{scopes} >> is what the row says. C<< $c->stash->{auth}{scopes} >>
is the effective set after narrowing, and it is the one the guard tested.

=item An unreadable owner table is a B<503>

B<This is the one place in this distribution that fails closed>, and the
reason is worth stating. A missing rate-limit arena means no limiting, which
is a degraded service. An unreadable owner table means the guard does not know
whether this credential is still good - and a credential nobody can vouch for
is not one to honour.

=back

=head1 GUARDS

    my $api = under '/api/v1' => api_key_guard(scope => 'read');
    api_key_guard(scope => [qw(read write)]);   # any of these
    api_key_guard;                              # any valid key

Denial is an API's denial. There is no redirect, ever, and no content
negotiation: a browser is not what is on the other end of a key.

Every reason a credential is not good - missing, malformed, a bad checksum, an
unknown kind, an unknown digest, revoked, expired, an owner who is gone - is
one B<401> with C<WWW-Authenticate: Bearer> and the same body. A client that
could tell "unknown" from "revoked" could enumerate keys, and the difference
is of no use to anyone who is not doing that.

A scope the key lacks is a B<403>.

=head2 The checker form answers 401 for a scope miss

    api 'openapi.json' => {
        security => { apiKey => api_key_checker(scope => 'write') },
    };

The two forms differ here, and not by choice. Punk's OpenAPI mount treats any
truthy return from a security checker as the authorisation and turns anything
false into a 401 - so a checker that returned a 403 would B<authorise the
request>. The checker therefore returns false for a scope miss, and the mount
says 401.

Where the document lists scopes for an operation, those are B<all> required;
the keyword's C<scope> is B<any> of. Both hold.

=head1 CONTEXT METHODS

=head2 api_key

    my $row = $c->api_key;      # the row behind this request, or undef

The key's row without its digest. Never the plaintext: nothing has it after
the response that minted it.

=head2 api_key_auth

    my $auth = $c->api_key_auth;
    # { owner => 7, key => 3, kind => 'live', scopes => [ 'read' ] }

What the guard decided, or C<undef>. C<scopes> is the B<effective> set,
after the owner's rank has narrowed whatever the key's row claims - so it is
the set that was actually tested rather than the set that was stored.

C<< $c->stash->{auth} >> holds the same hash and is the slot to read in an
ordinary handler. B<Behind an C<api> mount it does not.> A mount's security
check replaces that slot with its own hash of per-scheme results, so a
controller under one that read C<< $c->stash->{auth}{owner} >> would find
nothing there. This method reads a slot the mount does not own, and works
either way - which is why the generated API controller uses it.

=head1 THE PER-KEY LIMIT

A row's C<rate_per_min>, applied after the lookup through
C<< $c->rate_hit("apikey:$id", $n, 60) >> - keyed by the row id - and failing
open without Hyperman's arena, exactly as L<Punk/rate_limit> does.

Over the limit is a B<429> in C<application/problem+json> with C<Retry-After>
and the C<X-RateLimit-*> headers: the limiter's shape and not this plugin's,
because a client that already handles C<rate_limit>'s 429 must handle this one
identically.

=head1 TRAPS

B<Do not C<< rate_limit by => 'header:Authorization' >> with this plugin
loaded.> That puts the raw credential into Hyperman's shared arena as a
counter name. The same goes for an access log that prints request headers, and
for handing C<< $c->stash->{auth} >> to a template. This plugin keys its own
counters by row id, strips the digest from everything it returns, and never
logs the header.

B<The plaintext is returned once.> C<api_key_issue> returns it and nothing
stores it. An application that puts it in the session to show on the next page
has just stored it; the one legitimate display is the response to the request
that minted it.

B<C<last_used> is written at most once a minute.> "Is anyone still using this
key" does not need second precision, and it is not worth a write per request.
A failed write never refuses the request.

=head1 THE SCHEMA

Shipped as a Sqitch project named C<punk_apikey> through L<Punk::Sqitch>, for
sqlite, Pg and MySQL. For an application that manages its schema some other
way:

    CREATE TABLE api_keys (
        id           bigserial PRIMARY KEY,
        owner_id     bigint  NOT NULL,
        kind         text    NOT NULL DEFAULT 'live',
        label        text    NOT NULL,
        prefix       text    NOT NULL,
        digest       text    NOT NULL,
        scopes       text,
        rate_per_min integer,
        expires      bigint,
        revoked      bigint,
        last_used    bigint,
        created      bigint  NOT NULL
    );
    CREATE UNIQUE INDEX api_keys_digest ON api_keys (digest);
    CREATE INDEX api_keys_owner ON api_keys (owner_id);

C<owner_id> is a column and B<not> a foreign key. A key identifies an account,
so it keeps working when the person who made it leaves; and a plugin's Sqitch
project cannot depend on the application's own, which deploys last.

=head1 CLASS METHODS

C<< issue_for($app_class, %args) >>, C<< revoke_for($app_class, $id) >> and
C<< keys_for($app_class, $owner) >> are what the helpers call, for a CLI or a
job with no request to reach a context through.
C<< state_for($app_class) >> returns the live configuration: a seam for tests,
not an API.

=head1 SEE ALSO

L<Punk::APIKey>, L<Punk::Auth>, L<Punk::Sqitch>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
