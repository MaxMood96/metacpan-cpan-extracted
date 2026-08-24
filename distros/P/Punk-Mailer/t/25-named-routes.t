use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.31+ required (named routes)'
        unless eval { require Punk; Punk->VERSION('0.31'); 1 };
}

# mail_url and mail_token taking a route NAME rather than a path typed twice.
#
# The join is onto the ORIGIN of base, not the whole of it: a named route
# already carries the application's own prefix (the path on `host`, and
# SCRIPT_NAME when there is a request), so joining the whole base would
# spell that prefix twice - https://example.com/app/app/verify.

my %got;

{
    package M25;
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com' };
    host 'https://example.com';
    get '/verify/:token' => sub { $_[0]->text('v') }, { name => 'verify' };
    get '/account'       => sub { $_[0]->text('a') }, { name => 'account' };
    get '/u' => sub {
        my ($c) = @_;
        $got{name}   = $c->mail_url('verify', token => 'abc');
        $got{plain}  = $c->mail_url('account');
        $got{path}   = $c->mail_url('/still/a/path');
        $got{query}  = $c->mail_url('account', ref => 'mail');
        $got{missing} = eval { $c->mail_url('verify') } || $@;
        $got{unknown} = eval { $c->mail_url('nosuch') } || $@;
        $c->text('ok');
    };
}

my $app = M25->to_app;
sub hit {
    my ($a, %o) = @_;
    open my $in, '<', \'';
    return $a->({ REQUEST_METHOD => 'GET', PATH_INFO => $o{path} // '/u',
        QUERY_STRING => '', SERVER_NAME => 'localhost', SERVER_PORT => 80,
        HTTP_HOST => 'example.com', 'psgi.url_scheme' => 'https',
        'psgi.input' => $in, %{ $o{env} // {} } });
}
hit($app);

is $got{name},  'https://example.com/verify/abc',
    'a route name and its captures become an absolute link';
is $got{plain}, 'https://example.com/account',
    'a route with no captures needs none';
is $got{path},  'https://example.com/still/a/path',
    'a first argument starting with / is still a path, joined whole';
is $got{query}, 'https://example.com/account?ref=mail',
    'a leftover argument is a query pair, as in url_for';
like $got{missing}, qr/no value for :token/,
    'a missing capture croaks rather than mailing a broken link';
like $got{unknown}, qr/no route is named 'nosuch'/,
    'and so does a name no route carries';

# ---- the prefix is not spelled twice ---------------------------------------

{
    package M25P;
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com' };
    host 'https://example.com/app';        # a proxy strips /app
    get '/verify/:token' => sub { $_[0]->text('v') }, { name => 'verify' };
    get '/u' => sub {
        my ($c) = @_;
        $got{pfx} = $c->mail_url('verify', token => 'abc');
        $got{pfx_path} = $c->mail_url('/raw');
        $c->text('ok');
    };
}
hit(M25P->to_app);

is $got{pfx}, 'https://example.com/app/verify/abc',
    'the application prefix appears exactly once in a named link';
is $got{pfx_path}, 'https://example.com/app/raw',
    'a literal path still joins the whole base, unchanged';

# ---- an explicit base of its own -------------------------------------------

{
    package M25B;
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com',
                         base => 'https://links.example.com' };
    host 'https://app.example.com';
    get '/verify/:token' => sub { $_[0]->text('v') }, { name => 'verify' };
    get '/u' => sub {
        my ($c) = @_;
        $got{base} = $c->mail_url('verify', token => 'z');
        $c->text('ok');
    };
}
hit(M25B->to_app);

is $got{base}, 'https://links.example.com/verify/z',
    'an explicit base is honoured as the origin a link is mailed from';

# mail_token's `route =>` is exercised in t/23-mail-token.t, which already
# has the model, auth and token apparatus a token needs.

done_testing;
