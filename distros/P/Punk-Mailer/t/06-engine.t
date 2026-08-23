use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# the engine: transport resolution, option checking at new, the defaults a
# message may leave out, the croak/Result line, and the Result's contract.

my %msg = (to => 'a@example.com', subject => 'hi', text => "body\n");

# ---- construction -------------------------------------------------------------
{
    my $m = Punk::Mailer->new(transport => 'capture', from => 'Ops <ops@example.com>');
    isa_ok($m, 'Punk::Mailer');
    is($m->transport_name, 'capture', 'transport_name');
    isa_ok($m->transport, 'Punk::Mailer::Transport::Capture');
    is($m->transport->name, 'capture', 'the transport knows its name');
    is($m->from, 'Ops <ops@example.com>', 'from is kept');

    my $h = Punk::Mailer->new({ transport => 'log' });
    isa_ok($h->transport, 'Punk::Mailer::Transport::Log', 'a hashref works too');
}

# ---- everything is checked at new --------------------------------------------
{
    ok(!eval { Punk::Mailer->new(from => 'a@b.c'); 1 }, 'no transport croaks');
    like($@, qr/needs 'transport'/, '  naming it');
    ok(!eval { Punk::Mailer->new(transport => 'pigeon'); 1 }, 'an unknown transport croaks');
    like($@, qr/unknown transport 'pigeon'/, '  naming it');
    ok(!eval { Punk::Mailer->new(transport => 'capture', colour => 'red'); 1 },
        'an unknown engine option croaks');
    like($@, qr/unknown option 'colour' for Punk::Mailer->new/, '  naming it');
    ok(!eval { Punk::Mailer->new(transport => 'capture', capture => { dirr => 'x' }); 1 },
        'an unknown transport option croaks');
    like($@, qr/unknown option 'dirr' for the capture transport/, '  naming it and the transport');
    ok(!eval { Punk::Mailer->new(transport => 'capture', capture => 'x'); 1 },
        'transport options must be a hashref');
    ok(!eval { Punk::Mailer->new(transport => 'capture', from => 'not an address'); 1 },
        'a bad default from croaks');
    like($@, qr/not an address/, '  with the address rule');
    ok(!eval { Punk::Mailer->new(transport => 'capture', from => "a\@b.c\r\nX: y"); 1 },
        'an injected default from croaks');
    ok(!eval { Punk::Mailer->new(transport => 'resend'); 1 }, 'resend without api_key croaks');
    like($@, qr/needs 'api_key'/, '  naming the credential');
    ok(!eval { Punk::Mailer->new(transport => 'capture', capture => { result => 'maybe' }); 1 },
        'a scripted result must be one of the four');
    ok(!eval { Punk::Mailer->new(transport => 'No::Such::Transport::Class'); 1 },
        'a class that does not exist croaks');
    like($@, qr/No::Such::Transport::Class/, '  naming it');
    ok(!eval { Punk::Mailer->new(transport => 'capture', 'odd'); 1 }, 'odd pairs croak');
}

# ---- a custom transport class ----------------------------------------------------
{
    package My::Transport;
    sub new { my ($class, $opts) = @_; bless { opts => $opts, seen => [] }, $class }
    sub deliver {
        my ($self, $spec, $env) = @_;
        push @{ $self->{seen} }, [ $spec, $env ];
        return Punk::Mailer->new(transport => 'capture')->transport->deliver($spec, $env);
    }
    sub name { 'mine' }
    package main;

    my $m = Punk::Mailer->new(transport => 'My::Transport', options => { x => 1 },
                              from => 'ops@example.com');
    isa_ok($m->transport, 'My::Transport');
    is_deeply($m->transport->{opts}, { x => 1 }, 'options reach the class');
    my $r = $m->send(\%msg);
    isa_ok($r, 'Punk::Mailer::Result');
    my ($spec, $env) = @{ $m->transport->{seen}[0] };
    is($spec->{from}, 'ops@example.com', 'the default from was filled in before deliver');
    is_deeply($env, { from => 'ops@example.com', to => [ 'a@example.com' ] },
        'and the envelope was computed');
}

# ---- defaults, and the croak/Result line ---------------------------------------
{
    my $m = Punk::Mailer->new(transport => 'capture', from => 'Ops <ops@example.com>',
                              reply_to => 'help@example.com',
                              message_id_domain => 'mail.example.com');
    my $r = $m->send(\%msg);
    ok($r->accepted, 'sent through capture');
    my $bytes = $m->transport->messages->[0]{bytes};
    like($bytes, qr/^From: Ops <ops\@example\.com>\r$/m, 'the default from');
    like($bytes, qr/^Reply-To: help\@example\.com\r$/m, 'the default reply_to');
    like($bytes, qr/^Message-ID: <[^>]+\@mail\.example\.com>\r$/m, 'the default message_id_domain');
    is($r->id, ($bytes =~ /^Message-ID: (.*)\r$/m)[0], 'the Result id is the Message-ID');

    $r = $m->send({ %msg, from => 'Other <o@example.com>' });
    like($m->transport->messages->[1]{bytes}, qr/^From: Other <o\@example\.com>\r$/m,
        'a message from overrides the default');

    ok(!eval { $m->send({ subject => 's', text => 't' }); 1 }, 'no recipient croaks at send');
    like($@, qr/needs a recipient/, '  a bad message is a croak, not a Result');
    ok(!eval { $m->send({ %msg, to => "a\@b.c\nBcc: x" }); 1 }, 'injection croaks at send');
    ok(!eval { $m->send('not a hashref'); 1 }, 'send takes a hashref');
    is(scalar @{ $m->transport->messages }, 2, 'and nothing was captured for any of those');

    my $bare = Punk::Mailer->new(transport => 'capture');
    ok(!eval { $bare->send(\%msg); 1 }, 'no from anywhere croaks');
    like($@, qr/needs exactly one 'from'/, '  at send');
}

# ---- the Result ---------------------------------------------------------------
{
    my %want = (
        accepted => [ 250, 1, 0, 0, 0, 0 ],
        deferred => [ 451, 0, 1, 0, 0, 1 ],
        rejected => [ 550, 0, 0, 1, 0, 0 ],
        failed   => [ undef, 0, 0, 0, 1, 1 ],
    );
    for my $st (sort keys %want) {
        my ($code, $acc, $def, $rej, $fail, $retry) = @{ $want{$st} };
        my $m = Punk::Mailer->new(transport => 'capture', from => 'o@example.com',
                                  capture => { result => $st });
        my $r = $m->send(\%msg);
        is($r->status, $st, "scripted $st: status");
        is($r->code, $code, "  code");
        is(!!$r->accepted, !!$acc, "  accepted");
        is(!!$r->deferred, !!$def, "  deferred");
        is(!!$r->rejected, !!$rej, "  rejected");
        is(!!$r->failed,   !!$fail, "  failed");
        ok(!$r->unsent, "  not unsent");
        is(!!$r->retryable, !!$retry, "  retryable");
        is($r->transport, 'capture', "  transport");
        like($r->message, qr/scripted $st/, "  message");
        is_deeply($r->recipients, {}, "  no per-recipient verdicts");
        ok($r, 'a Result is always true as a reference, whatever its status');
    }
    my $u = Punk::Mailer->new(transport => 'log', from => 'o@example.com',
                              log => { to => sub { } })->send(\%msg);
    is($u->status, 'unsent', 'the log transport is unsent');
    ok($u->unsent && !$u->retryable, '  and not retryable');
    is($u->enhanced, undef, 'no enhanced code');
}

done_testing;
