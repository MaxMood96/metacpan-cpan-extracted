use strict;
use warnings;
use Test::More;
BEGIN { do './t/sibling.pl' }

BEGIN {
    plan skip_all => 'Punk 0.29+ required for the plugin tests'
        unless eval { require Punk; Punk->VERSION('0.29'); 1 };
}

# where links come from: base, else the host keyword (even one declared
# after the plugin), never the request's Host header.

my %url;
{
    package T24a;          # base given: wins over host
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com', base => 'https://base.example' };
    host 'https://host.example';
    get '/u' => sub { my ($c) = @_; $url{a} = $c->mail_url('/p'); $c->text($url{a}) };
}
{
    package T24b;          # host declared AFTER the plugin: read at to_app
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com' };
    host 'https://late.example';
    get '/u' => sub { my ($c) = @_; $url{b} = $c->mail_url('/p'); $c->text($url{b}) };
}
{
    package T24c;          # neither
    use Punk;
    plugin 'Mailer' => { transport => 'capture', from => 'o@example.com' };
    get '/u' => sub {
        my ($c) = @_;
        my $u = eval { $c->mail_url('/p') };
        $url{c_err} = $@;
        $c->text(defined $u ? $u : 'croaked');
    };
}

require Punk::Test;

Punk::Test->new('T24a')->get_ok('/u', headers => { Host => 'evil.example' })->status_is(200);
is($url{a}, 'https://base.example/p', 'base wins over host, and the Host header is not consulted');

Punk::Test->new('T24b')->get_ok('/u', headers => { Host => 'evil.example' })->status_is(200);
is($url{b}, 'https://late.example/p', 'a host declared after the plugin is read at to_app');

Punk::Test->new('T24c')->get_ok('/u', headers => { Host => 'evil.example' })->content_is('croaked');
like($url{c_err}, qr/mail_url needs a base/, 'with neither, mail_url croaks naming both ways to fix it');

is(Punk::Plugin::Mailer::state_for('T24b')->{base}, 'https://late.example', 'the state holds the resolved base');

done_testing;
