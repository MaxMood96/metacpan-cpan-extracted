use strict;
use warnings;
use Test::More;
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.29+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
    plan skip_all => 'Template::Stencil 0.10+ required'
        unless eval { require Template::Stencil; Template::Stencil->VERSION('0.10'); 1 };
}

# mail_token: issue through Punk::Auth, link on base, render, send, and
# the returned link redeems with take_token.

# ---- an in-memory backend for the user and token tables ---------------------------
{
    package T::Backend::Memory;
    my %ROWS;   # table => id => row
    my $NEXT = 1;
    sub _rows { \%ROWS }
    sub new    { my ($class, %a) = @_; bless { table => $a{table} }, $class }
    sub get    { my ($self, %k) = @_; my $t = $ROWS{ $self->{table} } ||= {};
                 return $k{id} ? $t->{ $k{id} } : (grep { my $r = $_; !grep { $r->{$_} ne $k{$_} } keys %k } values %$t)[0] }
    sub search { my ($self, $f) = @_; my $t = $ROWS{ $self->{table} } ||= {}; $f ||= {};
                 my @rows = grep { my $r = $_; !grep { ($r->{$_} // '') ne ($f->{$_} // '') } keys %$f } values %$t;
                 return { rows => \@rows, has_more_data => 0, next => undef } }
    sub all    { $_[0]->search({}, {}) }
    sub create { my ($self, $d) = @_; my $id = $d->{id} // $NEXT++;
                 $ROWS{ $self->{table} }{$id} = { %$d, id => $id }; return { %$d, id => $id } }
    sub update { my ($self, $d) = @_; my $row = $ROWS{ $self->{table} }{ $d->{id} } ||= {};
                 @{$row}{ keys %$d } = values %$d; return { %$row } }
    sub delete { my ($self, %k) = @_; delete $ROWS{ $self->{table} }{ $k{id} } ? 1 : 0 }
}
{
    package T::Model::User;
    use Punk::Model;
    table 'users';
    field id    => { type => 'integer', primary => 1 };
    field email => { type => 'string' };
}
{
    package T::Model::Token;
    use Punk::Model;
    table 'tokens';
    field id      => { type => 'integer', primary => 1 };
    field user_id => { type => 'integer' };
    field kind    => { type => 'string' };
    field digest  => { type => 'string' };
    field expires => { type => 'integer' };
}

my %probe;
{
    package T;
    use Punk;

    session secret => 'x' x 32;
    database backend => 'T::Backend::Memory';
    model 'User';
    model 'Token';
    auth model => 'User', token_model => 'Token';
    plugin 'Mailer' => {
        transport => 'capture', from => 'Ops <ops@example.com>',
        base => 'https://t.example', mail_dir => 't/mail',
    };

    # a named route for the `route =>` form: the link comes from the route
    # table rather than from a path with a %s in it
    get '/confirm/:token' => sub { $_[0]->text('c') }, { name => 'confirm' }
        if Punk->VERSION >= 0.31;

    get '/probe' => sub {
        my ($c) = @_;
        $probe{token} = sub { $c->mail_token(@_) };
        $probe{take}  = sub { $c->take_token(@_) };
        return $c->text('ok');
    };
}

require Punk::Test;
Punk::Test->new('T')->get_ok('/probe')->status_is(200);
my $cap = Punk::Plugin::Mailer->engine_for('T')->transport;

my $user = T::Backend::Memory->new(table => 'users')->create({ email => 'ann@example.com' });

# ---- the happy path --------------------------------------------------------------------
{
    my ($r, $link) = $probe{token}->($user, kind => 'verify', subject => 'Verify', template => 'token');
    isa_ok($r, 'Punk::Mailer::Result', 'the result');
    ok($r->accepted, '  accepted');
    like($link, qr{^https://t\.example/verify/[A-Za-z0-9_-]+\z}, 'the link on base with the default path');
    my ($token) = $link =~ m{/verify/(.+)\z};
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    is($m->{headers}{to}, 'ann@example.com', 'to the user\'s email by default');
    is($m->{headers}{subject}, 'Verify', 'the subject');
    like($m->{body}, qr/Click \Q$link\E - token \Q$token\E for ann\@example\.com/, 'link, token and user in the data');

    my $taken = $probe{take}->($token, 'verify');
    ok($taken, 'the token redeems through take_token');
    ok(!$probe{take}->($token, 'verify'), '  once');
}

# ---- route => names the route instead of spelling its path -------------------------
SKIP: {
    skip 'named routes need Punk 0.31+', 4 unless Punk->VERSION >= 0.31;

    my ($r, $link) = $probe{token}->($user, kind => 'confirm',
        route => 'confirm', subject => 'Confirm', template => 'token');
    isa_ok($r, 'Punk::Mailer::Result', 'the result of a route => token');
    like($link, qr{^https://t\.example/confirm/[A-Za-z0-9_-]+\z},
        'the link is built from the route table, on the base origin');
    unlike($link, qr/%s/, 'with no placeholder left to get wrong');

    my ($token) = $link =~ m{/confirm/(.+)\z};
    ok($probe{take}->($token, 'confirm'),
        'and the token in it redeems, so the link is one that works');
}

{
    my $err = '';
    eval { $probe{token}->($user, kind => 'verify', route => 'confirm',
            path => '/verify/%s', subject => 'x', template => 'token') };
    $err = $@;
    like($err, qr/takes `route` or `path`, not both/,
        'giving both is a mistake rather than a silent winner');
}

# ---- one live link per kind --------------------------------------------------------
{
    my (undef, $first)  = $probe{token}->($user, kind => 'reset', subject => 'R', template => 'token');
    my (undef, $second) = $probe{token}->($user, kind => 'reset', subject => 'R', template => 'token');
    my ($t1) = $first  =~ m{/verify/(.+)\z};
    my ($t2) = $second =~ m{/verify/(.+)\z};
    ok(!$probe{take}->($t1, 'reset'), 'the earlier link is dead once a new one is issued');
    ok($probe{take}->($t2, 'reset'), '  and the new one lives');
}

# ---- options -------------------------------------------------------------------------
{
    my (undef, $link) = $probe{token}->($user, kind => 'invite', subject => 'I', template => 'token',
                                        path => '/join/%s/now', to => 'other@example.com', ttl => 60);
    like($link, qr{^https://t\.example/join/[A-Za-z0-9_-]+/now\z}, 'a custom path');
    my $m = MIMERead::parse($cap->messages->[-1]{bytes});
    is($m->{headers}{to}, 'other@example.com', 'to overrides the email');

    my $scalar = $probe{token}->($user, kind => 'x', subject => 'S', template => 'token');
    isa_ok($scalar, 'Punk::Mailer::Result', 'in scalar context, the result alone');

    ok(!eval { $probe{token}->($user, subject => 'S', template => 'token'); 1 }, 'no kind croaks');
    ok(!eval { $probe{token}->($user, kind => 'k', template => 'token'); 1 }, 'no subject croaks');
    ok(!eval { $probe{token}->($user, kind => 'k', subject => 'S'); 1 }, 'no template croaks');
    ok(!eval { $probe{token}->($user, kind => 'k', subject => 'S', template => 'token', path => '/x'); 1 },
        'a path without %s croaks');
    ok(!eval { $probe{token}->({ id => 99 }, kind => 'k', subject => 'S', template => 'token'); 1 },
        'a user without an email croaks');
    ok(!eval { $probe{token}->($user, kind => 'k', subject => 'S', template => 'token', bogus => 1); 1 },
        'an unknown option croaks');
}

done_testing;
