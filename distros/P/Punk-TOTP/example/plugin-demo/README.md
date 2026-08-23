# TOTPDemo

A [Punk](https://metacpan.org/pod/Punk) application showing
[Punk::Plugin::TOTP](https://metacpan.org/pod/Punk::Plugin::TOTP) end to
end: a password sign-in that hands enrolled users to the second factor,
enrolment with a QR code, a page behind `totp_guard`, and recovery codes.
Everything is in memory - one user, password `punk`, reborn on every
restart.

## Run it

    plackup app.psgi

or, on the event-loop server Punk is built for:

    hyperman app.psgi

Then open <http://localhost:5000/>.

## Test it

    prove -l t/

## Layout

    lib/TOTPDemo.pm                        routes, session, auth, two helpers
    lib/TOTPDemo/Controller/Web/Auth.pm    the sign-in chokepoint
    lib/TOTPDemo/Controller/Web/Account.pm enrolment and recovery codes
    lib/TOTPDemo/Controller/Web/Vault.pm   the page behind totp_guard
    lib/TOTPDemo/Backend/Memory.pm         the in-memory model backend
    lib/TOTPDemo/Model/                    User and Token
    config/punk.yml                        views, static, database, models, plugin
    root/templates/                        Stencil templates, layout.tmpl wraps
    root/static/                           files served at /static

## Where the plugin is

`config/punk.yml` registers it with `render: totp_page`, a helper in
`lib/TOTPDemo.pm` that draws the challenge through the same layout as every
other page. `Web::Auth#login` calls `$c->totp_challenge` instead of
`$c->login` for an enrolled user; `Web::Account#enrol` calls
`$c->totp_verify` against the pending secret and flips `totp_enabled` only
when a code proves the phone; `/vault/contents` sits under `totp_guard()`.
