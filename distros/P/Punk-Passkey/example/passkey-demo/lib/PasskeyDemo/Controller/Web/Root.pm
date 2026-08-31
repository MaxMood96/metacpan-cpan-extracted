package PasskeyDemo::Controller::Web::Root;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

sub index {
    my ($c) = @_;
    my $user = $c->current_user;

    return $c->render('home', {
        title => 'Passkey demo',
        user  => $user,
        keys  => $user
            ? $c->model(q{Passkey})->search({ user_id => $user->{id} })->{rows}
            : [],
    });
}

sub signup {
    my ($c) = @_;
    my $email = $c->param(q{email}) // q{};
    $email =~ s{\A\s+|\s+\z}{}g;
    $email = q{you@example.com} unless length $email;

    # A user row with NO password_hash. punk_auth allows that on
    # purpose - the account exists, and a passkey will be the way in.
    my $user = $c->model(q{User})->create({ email => $email });
    $c->login($user);
    return $c->redirect(q{/account/passkeys});
}

sub signout {
    my ($c) = @_;
    $c->session_expire;
    return $c->redirect('/');
}

1;

__END__
