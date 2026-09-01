# AuthzDemo - may this user act on this row?

A Punk application with three people, three documents, and one file of rules.
Everything it does is one line in a controller:

    $c->may('doc.edit', $doc) or return $c->deny;

    punk sqitch deploy      # create the tables, once
    plackup app.psgi
    # then open http://localhost:5000/

Signing in is a click. There is no password anywhere in this application,
because a login form would be the only thing on the page that is not about
authorisation.

## What to look at first

`lib/AuthzDemo/Authorisation.pm`. Six rules, and every one of them fits on a
screen. That file is the application's; everything else the plugin does is
machinery around it - collecting the rules, refusing to guess at a name
nobody defined, and turning a refusal into the right status.

The home page draws a matrix: every document against every action, each cell
one live call to `$c->may`. A blank cell shows the status a refusal would
carry, which is the whole point.

## The four things worth trying

1. As **alice**, edit *Bob's draft*. **404** - not 403. A 403 on somebody
   else's row id confirms the row is there, which is how a private document
   becomes enumerable by anyone willing to count.
2. As **alice** (a `member`), publish *her own* notes. **403** this time. She
   already knows the row exists; she is simply not on a high enough rung.
   Same refusal, different status, and the rule chose.
3. As **alice**, grant **bob** edit on her notes. Act as bob: he can edit
   them now. Revoke it, and he cannot - on the very next request, because
   nothing is cached and a revoked grant has to stop working at once.
4. As **carol** (an `admin`), delete anything you like. Then try to grant
   yourself edit on Alice's notes: **404**. An admin is not an owner, which
   is the difference between a role and a grant.

## The bug this demo had

`doc.publish` was written the obvious way round first:

    return $c->forbidden unless $c->rank_at_least('editor');   # WRONG
    return 1 if $doc->{owner_id} == $c->auth_id;
    return $c->not_yours;

Every assertion in `t/01-basic.t` passed. The matrix on the home page is what
gave it away: as **alice**, the *publish* column against **Bob's draft** read
`403` - and a 403 is an answer. The rank check refused before ownership was
ever consulted, so a member could enumerate other people's private documents
by watching which ones came back 403 instead of 404. That is precisely the
leak this plugin exists to make easy to avoid, reintroduced one line above
where it is handled.

The order is: **what may this person see, then what may they do.**

    return $c->not_yours unless $doc->{owner_id} == $c->auth_id;
    return $c->forbidden unless $c->rank_at_least('editor');
    return 1;

There is now an assertion for it, because it is the kind of bug that passes
every test you thought to write.

## The ladder is written once

    auth model => 'User', rank => [qw(member editor admin)],
         roles => sub { $_[1]->{role} };

The plugin reads `rank` and `roles` back out of the `auth` keyword through
`$app->auth_config`, so `rank_at_least('editor')` and `auth_guard(role =>
...)` cannot disagree about what a role is. Passing `rank` to the plugin as
well is how two lists drift apart.

**One ordering trap**, and this demo hits it: the plugin is registered in
`lib/AuthzDemo.pm` and not in `config/punk.yml`'s `plugins:` block. `config`
registers what it names as it reads the file, which is before the `auth` line
has run - so from there the plugin sees no ladder and refuses to boot:

    Punk::Plugin::Authorisation: no rank ladder - `auth rank => [...]`
    declares one, or pass rank => [...] to the plugin

That is the plugin working as intended: it fails at `to_app` rather than at
3am on a request nobody is watching. The fix is ordering, not repeating
yourself.

## The schema is Sqitch's

`punk sqitch deploy` deploys three projects in dependency order, and the
output is worth reading once:

    # project punk_auth       users, auth_tokens - the `auth` keyword's own
    # project punk_authz      grants             - the plugin's, registered
                                                   because it was given `grants`
    # project authzdemo       user_role, docs, demo_data

`punk_authz` ships inside Punk-Authorisation and appears only because
`config/punk.yml` asked for `grants`. An application that never grants
anything does not carry the table.

This application's own first change is an `ALTER TABLE users ADD COLUMN role`
that declares `[punk_auth:users]`, which is what a cross-project dependency
is for: the `auth` keyword owns the users table, and an application that
wants a ladder on it says so in its own project rather than forking the
upstream one.

The demo's three people and three documents are a Sqitch change too
(`demo_data`), not seeding code at boot: it is revertible, it runs once, and
the application has no branch in it that a real one would not have.

## Types at the edge

    $c->grant('doc.edit', $doc->{id}, to => 0 + $c->param('user_id'));

The `0 +` is load-bearing. A parameter is a string, `subject_id` in
`Punk::Model::Grant` is an integer field, and a model handed `"2"` where it
declared an integer refuses the row with *does not match the field schema*.
The plugin does not coerce it, and should not: `fields` exists so the grants
table can be your own, whose subject column might be a UUID.

## The tests

    prove -l t/

18 assertions against a real SQLite database, deployed by Sqitch into
`var/test/` so they do not disturb the one the server uses (`PUNK_ENV=test`,
`config/punk.test.yml`). They assert the four things above, which is to say:
that a refusal is a 404 exactly when a 403 would give the row away.
