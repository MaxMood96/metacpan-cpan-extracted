package
	TOTPDemo::Controller::Web::Account;

use strict;
use warnings;
use parent 'Punk::Controller';

our $VERSION = '0.01';

sub home {
    my ($c) = @_;
    my $user = $c->current_user
        or return $c->page('login');

    if (!$user->{totp_enabled}) {
        my $secret = $c->session->{totp_enrolling} //= $c->totp_secret;
        return $c->page('enrol', { secret => $secret,
                                   qr     => $c->totp_qr($secret) });
    }
    return $c->page('home', { passed => $c->session->{totp_at} ? 1 : 0 });
}

sub enrol {
    my ($c) = @_;
    my $user   = $c->current_user              or return $c->redirect('/');
    my $secret = $c->session->{totp_enrolling} or return $c->redirect('/');
    my $code   = $c->param('code') // '';
    $code =~ s/\s+//g;

    if ($c->totp_verify({ %$user, totp_secret => $secret }, $code)) {
        $c->model('User')->update({ id => $user->{id},
            totp_secret => $secret, totp_enabled => 1 });
        delete $c->session->{totp_enrolling};
        $c->flash(kind => 'ok',
                  notice => "enrolled - <code>$code</code> proved the phone");
    }
    else {
        my $shown = $code =~ /\A[0-9]{0,8}\z/ ? $code : '(not digits)';
        $c->flash(kind => 'bad',
                  notice => "enrolment refused <code>$shown</code>");
    }
    return $c->redirect('/');
}

sub recovery {
    my ($c) = @_;
    my $user = $c->current_user or return $c->redirect('/');
    my $codes = $c->totp_recovery_codes($user, count => 5);
    return $c->page('home', {
        passed => $c->session->{totp_at} ? 1 : 0,
        codes  => $codes,
        notice => 'issued 5 recovery codes - any older set is revoked',
        kind   => 'ok',
    });
}

1;

__END__

