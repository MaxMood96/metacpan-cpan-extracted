package ApiKeyDemo::Controller::Web::Root;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

# The front page and a sign-in with no password.
#
# No password on purpose: this demo is about API keys, and a password field
# would be the one part of it nobody needed to read. Punk::Auth does have the
# other half - see perldoc Punk::Auth::Password - and `$c->login` is the same
# call either way.

sub index {
    my ($c) = @_;

    return $c->redirect($c->url_for('keys')) if $c->auth_id;

    return $c->render('welcome', {
        title => 'ApiKeyDemo',
        csrf  => $c->csrf_field,
        error => $c->flash('error'),
        users => $c->model('User')->all->{rows},
    });
}

sub login {
    my ($c) = @_;
    my $email = $c->param('email') // '';

    my $user = $c->model('User')->search({ email => $email })->{rows}[0];

    # Created on first sight, so the demo has no seeding step. A real
    # application refuses an unknown address here.
    $user ||= $c->model('User')->create({
        email   => $email,
        role    => 'admin',        # the first thing you do is mint an admin key
        created => time,
    }) if $email =~ /\@/;

    unless ($user) {
        $c->flash(error => 'An address with an @ in it, please.');
        return $c->redirect($c->url_for('home'));
    }

    $c->login($user);
    return $c->redirect($c->url_for('keys'));
}

sub logout {
    my ($c) = @_;
    $c->logout;
    return $c->redirect($c->url_for('home'));
}

1;

__END__
