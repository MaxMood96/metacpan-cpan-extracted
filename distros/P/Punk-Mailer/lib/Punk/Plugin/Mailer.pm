package Punk::Plugin::Mailer;

use 5.016;
use strict;
use warnings;
use Punk::Mailer ();    # one dist, one bootstrap: the plugin lives in its bundle

our $VERSION = '0.02';

1;

__END__

=head1 NAME

Punk::Plugin::Mailer - outbound mail for a Punk application

=head1 SYNOPSIS

    package MyApp;
    use Punk;

    host 'https://example.com';

    plugin 'Mailer' => {
        transport => 'smtp',
        from      => 'Example <ops@example.com>',
        mail_dir  => 'root/mail',
        smtp      => { host => 'mail.example.com', username => 'ops@example.com',
                       password => secret('smtp_password') },
    };

    post '/contact' => sub {
        my ($c) = @_;
        my $r = $c->mail(to => 'help@example.com', subject => 'Contact form',
                         text => $c->param('message'));
        return $c->text($r->accepted ? 'sent' : 'not sent: ' . $r->message);
    };

    post '/signup' => sub {
        my ($c) = @_;
        my $user = $c->model('User')->create({ email => $c->param('email') });
        my ($r, $link) = $c->mail_token($user, kind => 'verify',
            subject => 'Verify your address', template => 'verify');
        return $c->render('check-your-mail', { sent => $r->accepted });
    };

=head1 DESCRIPTION

Wires L<Punk::Mailer> into an application: one transport, defaults for
the sender, templates from a directory, a hand-off to L<Punk::Queue>
for sending outside the request, and the one-line way to mail a
L<Punk::Auth> token. Every option of every layer is checked when
C<plugin> runs, so a typo or a missing credential stops the boot.

=head1 CONFIGURATION

    plugin 'Mailer' => {
        transport => 'smtp',                  # required: smtp, resend, sendmail, capture, log
        from      => 'Example <ops@example.com>',
        reply_to  => 'help@example.com',
        message_id_domain => 'example.com',
        base      => 'https://example.com',   # for links; defaults to the host keyword
        mail_dir  => 'root/mail',             # templates; optional
        layout    => 'layout',                # layout.txt.tmpl / layout.html.tmpl; optional
        later     => { task => 'mail.send', queue => 'mail', attempts => 5 },
        later_inline_max => 1_048_576,
        smtp => {...}, resend => {...}, sendmail => {...}, capture => {...}, log => {...},
    };

C<transport> and the per-transport hashes are L<Punk::Mailer>'s own
options and are handed to it unchanged. In F<punk.yml> the same mapping
goes under C<plugins: Mailer:>.

=head2 base

The origin absolute links are built on. A request's C<Host> header is
never used for this - it is whatever the client sent - so links come
from configuration: C<base>, or the application's C<host> keyword,
which may be declared after the plugin and is read at C<to_app>.
Without either, C<mail_url> and C<mail_token> croak when called.

=head2 mail_dir and templates

A directory of L<Template::Stencil> templates, one message per name:
C<name.txt.tmpl> for the text part, C<name.html.tmpl> for the HTML
alternative, either or both. A message that names a C<template> gets
whichever exist; the HTML side is rendered with escaping on and the
text side with it off. With C<layout>, each part is wrapped by
C<layout.txt.tmpl> / C<layout.html.tmpl> with the rendered part as
C<body> (use C<raw body> in the HTML layout; it is already escaped).

The render data is the message's C<data> plus C<base>, C<subject>,
C<to>, and C<locale> - the negotiated language tag when
L<Punk::Plugin::I18n> is registered. Translated strings are the
handler's to put in C<data>, as they are for a page. The directory is
read once at registration; a C<template> that names nothing there is a
croak listing what does exist.

=head2 later

Sends through L<Punk::Queue> instead of in the request. C<later> takes
the task name (default C<mail.send>) and any job defaults the queue
understands (C<queue>, C<attempts>, C<priority>). It needs the Queue
plugin registered B<before> this one: the task is declared through the
C<task> keyword when C<plugin 'Mailer'> runs, and croaks if the keyword
is not there.

=head1 HELPERS

=head2 $c->mail(%message)

    my $result = $c->mail(to => ..., subject => ..., text => ...);
    my $result = $c->mail(to => ..., subject => ..., template => 'welcome',
                          data => { name => $user->{name} });

L<Punk::Mailer>'s message, with three keys of the plugin's own:
C<template> and C<data> render the body, and C<< later => 1 >> hands
the message to the queue. Sends now and returns a L<Punk::Mailer::Result>;
never dies for what happened on the wire, only for a malformed message.

=head2 $c->mail_later(%message)

The same message, queued. Returns the job id. The message is rendered
B<now> - the user, the language and the host live in the request and a
job has none of them - and an attachment that is a L<Punk::Upload> is
made durable first, because the upload's temp file is gone when the
request ends: with L<Punk::Plugin::Blob> registered it is stored by
contents and the job reads it by path; otherwise it is read into the
job's arguments, up to C<later_inline_max>, and over that it croaks
naming the Blob plugin. An attachment given as a C<path> you own is
left alone - keep the file until the job has run.

The job body is C<Punk::Mailer::Job::send>: an C<accepted> Result is
the job's result; C<deferred> and C<failed> die so the queue's retry
policy applies; C<rejected> notes C<final> on the job and dies, because
no retry will change a C<5xx> - size the queue's C<attempts> knowing a
permanent rejection wastes a few.

=head2 $c->mail_template($name, \%data)

    my $parts = $c->mail_template('welcome', { name => 'Ann' });
    # { text => ..., html => ... }, undef for a kind that has no file

=head2 $c->mail_url($path)

C<base> joined to a path starting with C</>. Croaks with no base.

=head2 $c->mail_token($user, %options)

    my ($result, $link) = $c->mail_token($user,
        kind     => 'verify',              # required: the token kind
        ttl      => 2 * 24 * 60 * 60,      # default two days
        path     => '/verify/%s',          # %s is the token
        subject  => 'Verify your address', # required
        template => 'verify',              # required; data gets link, token, user
        to       => $user->{email},        # default: the user's email field
        later    => 1,                     # optional
    );

Issues a single-use token through L<Punk::Auth>'s C<issue_token>
(croaks without the C<auth> keyword), builds the link on C<base>,
renders and sends. Returns the Result (or the job id) and the link -
the link so a development page can show it when no mail is
configured. Auth's rule applies: issuing a new token of a kind
invalidates the user's older ones, so a re-sent mail leaves exactly one
live link. Redeem it with C<< $c->take_token >>.

=head1 CLASS METHODS

=head2 engine_for

    my $mailer = Punk::Plugin::Mailer->engine_for('MyApp');

The L<Punk::Mailer> the class registered, for code that has the class
and no context - a job body in a site, a maintenance script.

=head2 state_for

    my $cfg = Punk::Plugin::Mailer::state_for('MyApp');

The plugin's configuration for a class, as a live hash - the
introspection seam, and what a test reaches for.

=head2 register

What C<plugin 'Mailer'> calls. Not for calling directly.

=head1 SEE ALSO

L<Punk::Mailer>, L<Punk::Mailer::Result>, L<Punk::Mailer::Transport>,
L<Punk::Queue>, L<Punk::Auth>.

=cut
