#!/usr/bin/env perl
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../../lib";

# A Punk application sending mail through the plugin. Run it with
#
#     punk dev            # or: plackup -s Hyperman app.psgi
#
# and POST a name to /welcome: with no transport configured in the
# environment the message is captured and shown back, which is how a
# development box sees its mail without sending any.

package Demo;
use Punk;

host 'https://demo.example';

plugin 'Mailer' => {
    transport => $ENV{RESEND_API_KEY} ? 'resend' : 'capture',
    from      => $ENV{DEMO_MAILER_FROM} || 'Demo <demo@demo.example>',
    mail_dir  => "$FindBin::Bin/root/mail",
    resend    => { api_key => $ENV{RESEND_API_KEY} || 'unused' },
};

get '/' => sub {
    $_[0]->html('<form method="post" action="/welcome">'
              . '<input name="name" placeholder="your name">'
              . '<input name="to" placeholder="you@example.com">'
              . '<button>Send</button></form>');
};

post '/welcome' => sub {
    my ($c) = @_;
    my $r = $c->mail(
        to       => $c->param('to'),
        subject  => 'Welcome to the demo',
        template => 'welcome',
        data     => { name => $c->param('name') },
    );
    my $out = "Result: " . $r->status . " (" . $r->message . ")\n";
    if ($c->mail_url('/') && $r->transport eq 'capture') {
        my ($last) = reverse @{ Punk::Plugin::Mailer->engine_for('Demo')->transport->messages };
        $out .= "\n" . $last->{bytes};
    }
    return $c->text($out);
};

package main;
Demo->to_app;
