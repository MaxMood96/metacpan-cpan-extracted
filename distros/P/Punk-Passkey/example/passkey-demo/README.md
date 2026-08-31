# PasskeyDemo - a passkey, and nothing else

A Punk application whose only way in is a passkey. No password is ever
set, which is the point: a passkey is a whole authentication factor,
not something bolted onto one.

    punk sqitch deploy      # create the tables, once
    plackup app.psgi
    # then open http://localhost:5000/

You need a browser with WebAuthn (any current one) and something to
authenticate with: Touch ID, Windows Hello, a phone, or a hardware key.

## The origin has to be right

A passkey is bound to an origin, and WebAuthn needs a secure context -
https, or http on `localhost`, which browsers exempt. The default
matches `plackup` out of the box. On another port or host, say so:

    PASSKEY_DEMO_ORIGIN=http://localhost:8080 plackup -p 8080 app.psgi

Declaring an origin that is not the one in the address bar makes every
registration fail, correctly and confusingly. The origin comes from the
`host` keyword and never from the request - that is the check the whole
scheme rests on, and it is why an attacker cannot present your
credential at their site.

## The schema is Sqitch's

    punk sqitch deploy

That deploys three projects in dependency order, and the order is
Sqitch's to work out rather than something this README asks you to
remember:

    # project punk_auth      users, auth_tokens
    # project punk_passkey   passkeys        (its plan requires punk_auth:users)
    # project passkeydemo    nothing yet - this application has no schema of its own

`punk_passkey` is the project this distribution ships, registered by
`sqitch => 1` on the plugin; `punk_auth` comes from `auth ... sqitch => 1`.
Nothing here hand-writes a `CREATE TABLE`, and nothing runs SQL at boot:
the credential table this demo uses is the one every deployment gets,
so it cannot drift from it.

Useful verbs: `punk sqitch status` (what is deployed), `punk sqitch
pending` (what is not, exit 1 if any), `punk sqitch verify`, `punk
sqitch revert`. The registry lives in `sqitch.db`; the application's
data in `passkey-demo.db`. Delete both to start completely over.

`sqitch/` is this application's own (empty) project, created by `punk
sqitch init`. A real application adds its own changes there with `punk
sqitch add`.

## What to click, and what each step proves

1. **Create an account.** An email address, and that is all - there is
   no password to choose. `punk_auth`'s `password_hash` column stays
   NULL, which it explicitly allows: the account exists, and the
   passkey will be the way in.

2. **Add a passkey.** Your authenticator prompts; the browser signs the
   challenge the server minted; the server stores the public key.
   Nothing secret was sent, and nothing worth stealing was stored.

3. **Sign out, then sign in.** Nothing is typed. On a browser with
   conditional UI the passkey is offered from the autofill menu; on one
   without, the button does the same thing. Both call the same endpoint,
   and the button cancels the autofill request before opening its own -
   a browser allows only one credential request at a time.

4. **Try to remove your only passkey.** The plugin refuses. In this
   application that credential is the last way in, and
   `has_other_factor` says so - see `lib/PasskeyDemo.pm`. Enrol a
   second one and the first becomes removable.

## Where to look

| file | what it shows |
|---|---|
| `lib/PasskeyDemo.pm` | the whole cost of adopting passkeys: `auth`, one `plugin 'Passkey'` block, and the `sign_in` chokepoint every factor arrives at |
| `root/templates/home.tmpl` | the login page, including conditional UI as a progressive enhancement |
| `root/templates/passkeys.tmpl` | the management page, rendered through this app's layout via the `render` option |
| `config/punk.yml` | views, static, the database - and why the plugin is registered in code instead |

Note what is **not** in `lib/PasskeyDemo.pm`: no `user_id` callback.
With the `auth` keyword present the plugin already knows who is signed
in, so an application that has accounts adds passkeys with a keyword
and a migration.

The application mounts no WebAuthn routes of its own. Registration and
login live at `/account/passkeys` and `/login/passkey`, mounted by the
plugin, along with `/punk-passkey.js` - a dependency-free browser
helper that references no external origin, so a Content-Security-Policy
does not have to be widened to let sign-in work.

## About the database

A credential's public key is stored as the COSE bytes the authenticator
sent: arbitrary binary, NUL bytes included. The column is a `BLOB`, and
DBD::SQLite hands those back as bytes unless `sqlite_unicode` is turned
on - **do not turn it on**. A handle that decoded them as UTF-8 on the
way back would return a different key than the one that went in, and
every login would fail with nothing obviously wrong anywhere.
`t/01-basic.t` asserts that round trip rather than assuming it.

One trap if you add options under `database:` in `config/punk.yml`: a
key whose value is a hash is read as a **named database**, not as
options of the default one. `attr:` nested there quietly becomes a
database called "attr" and never reaches DBI. Name the default
explicitly if you need attributes:

    database:
      default:
        dsn:  dbi:SQLite:dbname=passkey-demo.db
        attr: { ... }

## The test

    punk sqitch deploy      # if you have not already
    prove -l t/

It drives every route the demo mounts and checks the shapes and the
refusals, and it skips with a note if the schema is not deployed. It
uses addresses of its own per run and removes them afterwards, because
the database outlives it.

It does not complete a ceremony: only an authenticator can produce a
signature, and a test that faked one would be asserting that the fake
matched the fake. That the ceremonies are correct is the
distribution's own suite, which drives them against registrations and
assertions captured from real devices.

## Recovery, which a demo usually omits

This application has one way in on purpose, so it is also the worst
possible advice. A real deployment gives people a second passkey on
another device - enrolled while the first still works - and something
like `Punk::TOTP`'s recovery codes behind that. "Email a link" moves
the whole account's security to a mailbox.

## See also

`perldoc Punk::Plugin::Passkey` for the keyword and its options,
`perldoc Punk::Passkey` for what is verified and why,
`perldoc Punk::Plugin::Sqitch` for the schema tooling.
