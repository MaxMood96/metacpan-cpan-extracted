package 
	TOTPDemo;

use strict;
use warnings;

use Punk;
use Punk::TOTP ();
use Punk::Auth::Password ();
use TOTPDemo::Backend::Memory ();   # seeded below, before to_app loads it

our $VERSION = '0.01';

config 'config/punk.yml';

session secret => Punk::TOTP->secret(bytes => 32);
auth    model  => 'User', login_path => '/';

TOTPDemo::Backend::Memory->new(table => 'users')->create({
    id            => 1,
    email         => 'you@example.com',
    password_hash => Punk::Auth::Password::hash('punk'),
    totp_enabled  => 0,
});

helper page => sub {
    my ($c, $template, $vars, %opt) = @_;
    my $flash = $c->flash || {};
    return $c->render($template, {
        user   => $c->current_user,
        notice => $flash->{notice},
        kind   => $flash->{kind} // 'ok',
        %{ $vars || {} },
    }, %opt);
};

helper totp_page => sub {
    my ($c, $error) = @_;
    return $c->page('challenge', { error => $error ? 1 : 0 });
};

get  '/'         => 'Web::Account#home';
post '/login'    => 'Web::Auth#login';
post '/logout'   => 'Web::Auth#logout';
post '/enrol'    => 'Web::Account#enrol';
post '/recovery' => 'Web::Account#recovery';

my $vault = under '/vault' => totp_guard();
$vault->get('/contents' => 'Web::Vault#contents');

1;

__END__

