use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.29+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
}

# the plugin against a real Punk application: registration, the option
# police, the helpers, and the engine reachable by class.

my %probe;
{
    package T20;
    use Punk;

    plugin 'Mailer' => {
        transport => 'capture',
        from      => 'Ops <ops@example.com>',
        base      => 'https://t20.example/',      # the trailing slash is dropped
    };

    get '/probe' => sub {
        my ($c) = @_;
        $probe{mail}       = sub { $c->mail(@_) };
        $probe{mail_later} = sub { $c->mail_later(@_) };
        $probe{mail_url}   = sub { $c->mail_url(@_) };
        $probe{template}   = sub { $c->mail_template(@_) };
        return $c->text('ok');
    };
}

require Punk::Test;
my $t = Punk::Test->new('T20');
$t->get_ok('/probe')->status_is(200);

# ---- registration and the state -----------------------------------------------
{
    my $st = Punk::Plugin::Mailer::state_for('T20');
    ok($st, 'state is kept under the app class');
    is($st->{base}, 'https://t20.example', 'base, without its trailing slash');
    is($st->{transport_name}, 'capture', 'the transport name');
    my $engine = Punk::Plugin::Mailer->engine_for('T20');
    isa_ok($engine, 'Punk::Mailer', 'engine_for');
    is($engine->from, 'Ops <ops@example.com>', '  with the default from');

    my $err = do { local $@; eval { Punk::Plugin::Mailer->register(T20::punk_app(), { transport => 'log' }) }; $@ };
    like($err, qr/already registered for T20/, 'double registration croaks');
}

# ---- the option police, at plugin time ------------------------------------------
{
    my $err = do { local $@; eval q{ package T20a; use Punk; plugin 'Mailer' => { transport => 'capture', colour => 'red' }; 1 }; $@ };
    like($err, qr/unknown option 'colour' for plugin 'Mailer'/, 'an unknown option croaks');

    $err = do { local $@; eval q{ package T20b; use Punk; plugin 'Mailer' => { from => 'a@b.c' }; 1 }; $@ };
    like($err, qr/needs a transport/, 'no transport croaks');

    $err = do { local $@; eval q{ package T20c; use Punk; plugin 'Mailer' => { transport => 'resend' }; 1 }; $@ };
    like($err, qr/needs 'api_key'/, 'a transport option is checked by the transport, at plugin time');

    $err = do { local $@; eval q{ package T20d; use Punk; plugin 'Mailer' => { transport => 'capture', base => 'example.com' }; 1 }; $@ };
    like($err, qr/base must be an absolute origin/, 'a base without a scheme croaks');

    $err = do { local $@; eval q{ package T20e; use Punk; plugin 'Mailer' => { transport => 'capture', mail_dir => '/no/such/dir' }; 1 }; $@ };
    like($err, qr/mail_dir '\/no\/such\/dir' is not a directory/, 'a missing mail_dir croaks');

    $err = do { local $@; eval q{ package T20f; use Punk; plugin 'Mailer' => { transport => 'capture', layout => 'x' }; 1 }; $@ };
    like($err, qr/layout needs a mail_dir/, 'a layout without templates croaks');

    $err = do { local $@; eval q{ package T20g; use Punk; plugin 'Mailer' => { transport => 'capture', later => { queue => 'mail' } }; 1 }; $@ };
    like($err, qr/later needs plugin 'Queue'/, 'later without the Queue plugin croaks, at plugin time');

    $err = do { local $@; eval q{ package T20h; use Punk; plugin 'Mailer' => 'capture'; 1 }; $@ };
    like($err, qr/takes a hashref/, 'options must be a hashref');
}

# ---- helper collision names both owners -----------------------------------------
{
    my $err = do { local $@; eval q{
        package T20i; use Punk;
        helper mail => sub { 'mine' };
        plugin 'Mailer' => { transport => 'capture', from => 'o@example.com' };
        T20i->to_app;
        1 }; $@ };
    like($err, qr/mail/, 'a helper named mail already installed croaks');
    like($err, qr/Punk::Plugin::Mailer/, '  naming this plugin as one owner');
}

# ---- the helpers -------------------------------------------------------------------
{
    my $r = $probe{mail}->(to => 'a@example.com', subject => 'hi', text => "body\n");
    isa_ok($r, 'Punk::Mailer::Result', 'mail returns');
    ok($r->accepted, '  accepted by capture');
    my $cap = Punk::Plugin::Mailer->engine_for('T20')->transport;
    is(scalar @{ $cap->messages }, 1, 'one captured message');
    my $m = MIMERead::parse($cap->messages->[0]{bytes});
    is($m->{headers}{from}, 'Ops <ops@example.com>', 'the default from reached the message');
    is($m->{body}, "body\r\n", 'the body');

    $r = $probe{mail}->({ to => 'a@example.com', subject => 'hashref', text => 't' });
    ok($r->accepted, 'a hashref works too');

    is($probe{mail_url}->('/verify/abc'), 'https://t20.example/verify/abc', 'mail_url joins base and path');
    ok(!eval { $probe{mail_url}->('verify'); 1 }, 'a path without a leading slash croaks');

    ok(!eval { $probe{mail}->(to => 'a@example.com', subject => 's', template => 'x'); 1 },
        'template without a mail_dir croaks');
    like($@, qr/has no mail_dir/, '  and says so');
    ok(!eval { $probe{mail_later}->(to => 'a@example.com', subject => 's', text => 't'); 1 },
        'mail_later without later configured croaks');
    like($@, qr/later was not configured/, '  and says so');
    ok(!eval { $probe{mail}->(to => 'a@example.com', subject => 's', text => 't', later => 1); 1 },
        'later => 1 without later configured croaks too');
    ok(!eval { $probe{mail}->(subject => 's', text => 't'); 1 }, 'a message with no recipient croaks');
    ok(!eval { $probe{mail}->(to => "a\@b.c\nBcc: x", subject => 's', text => 't'); 1 }, 'injection croaks');
    ok(!eval { $probe{template}->('x'); 1 }, 'mail_template without a mail_dir croaks');
}

done_testing;
