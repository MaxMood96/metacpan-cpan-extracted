package
	TOTPDemo::Controller::Web::Auth;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

sub login {
    my ($c) = @_;
    my $user = $c->model('User')->get(id => 1);

    unless ($c->check_password($user, $c->param('password') // '')) {
        $c->flash(kind => 'bad', notice => 'wrong password');
        return $c->redirect('/');
    }
    if ($user->{totp_enabled}) {
        $c->flash(kind => 'ok', notice => 'password accepted - now the factor');
        return $c->totp_challenge($user, to => '/');
    }
    $c->flash(kind => 'ok',
              notice => 'password accepted - no factor enrolled yet');
    $c->login($user);
    return $c->redirect('/');
}

sub logout {
    my ($c) = @_;
    $c->logout;
    return $c->redirect('/');
}

1;

__END__

