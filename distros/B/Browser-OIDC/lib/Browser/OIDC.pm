package Browser::OIDC;

use 5.020;
use warnings;
use experimental qw/signatures postderef lexical_subs/;

use Browser::Open 'open_browser';
use Carp;
use Digest::SHA 'sha256';
use Crypt::SysRandom 'random_bytes';
use HTTP::Daemon;
use HTTP::Headers;
use HTTP::Tiny;
use JSON::MaybeXS;
use MIME::Base64 qw/encode_base64url decode_base64url/;

our $VERSION = '0.001';

my $tiny = HTTP::Tiny->new;

sub new($class, $target_base) {
	my $response = $tiny->get("$target_base/.well-known/openid-configuration");
	croak "Error: $response->{status}" if $response->{status} != 200;
	my $self = decode_json($response->{content});
	bless $self, $class;
}

my sub make_target($authorization_endpoint, $redirect_uri, %options) {
	my $full_target = URI->new($authorization_endpoint);
	$full_target->query_param_append(response_type => 'code');
	$full_target->query_param_append(redirect_uri => $redirect_uri);
	$full_target->query_param_append(client_id => $options{client_id} // '');
	$full_target->query_param_append(client_secret => $options{client_secret} // '');
	$full_target->query_param_append(code_challenge => $options{challenge}) if $options{challenge};
	$full_target->query_param_append(code_challenge_method => 'S256');
	$full_target->query_param_append(scope => join ' ', $options{scope}->@*) if $options{scope};
	$full_target->query_param_append(state => $options{state});
	return $full_target;
}

sub get_token($self, %options) {
	my $state = $options{state} = encode_base64url(random_bytes(16));
	my $verifier = encode_base64url(random_bytes(32));
	$options{challenge} = encode_base64url(sha256($verifier)) if delete $options{pkce};

	my $daemon = HTTP::Daemon->new(LocalAddr => 'localhost');
	my $port = $daemon->sockport;
	my $redirect_uri = "http://localhost:$port/auth/callback";
	my $full_target = make_target($self->{authorization_endpoint}, $redirect_uri, %options);

	my $ok = open_browser($full_target->canonical);
	while (1) {
		my $sock = $daemon->accept;
		my $response = $sock->get_request;

		if ($response->uri->path eq '/auth/callback') {
			my $code = $response->uri->query_param('code');
			my $received_state = $response->uri->query_param('state');
			if ($received_state ne $state) {
				$sock->send_error(400);
				close $sock;
				die "Invalid state";
			}

			my $message = $options{message} // 'Authorization token received, you can close this now';
			my $headers = HTTP::Headers->new;
			$headers->header('content-type', $options{message_type}) if $options{message_type};
			$sock->send_response(HTTP::Response->new(200, 'OK', $headers, $message));
			close $sock;

			my %arguments = (
				grant_type    => 'authorization_code',
				redirect_uri  => $redirect_uri,
				code          => $code,
				code_verifier => $verifier,
				client_id     => $options{client_id} // '',
				client_secret => $options{client_secret} // '',
			);
			my $response2 = $tiny->post_form($self->{token_endpoint}, \%arguments);
			return decode_json($response2->{content}) if $response2->{status} == 200;
		} else {
			$sock->send_error(404);
			close $sock;
		}
	}
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Browser::OIDC - Get an OIDC token for a CLI application

=head1 SYNOPSIS

 my $oidc = Browser::OIDC->new($base_url);
 $oidc->get_token(
	 client_id => 'me',
	 pkce      => 1,
	 scope     => [ 'email' ],
 );

=head1 DESCRIPTION

This module will open a browser for you to log into some OIDC provider, and will temporarily run a webserver on localhost to receive the redirect with the results from your browser.

=head1 METHODS

=head2 new

 my $oidc = Browser::OIDC->new($base_url);

This creates a new 

=head2 get_token

 $oidc->get_token(%options);

This fetches an OIDC token from the endpoint. It takes the following options:

=over 4

=item client_id

The client identifier. Effectively mandatory.

=item client_secret

The client secret, if any.

=item pkce

If true this will enable Proof Key for Code Exchange (PKCE).

=item scope

This list will be the scopes of the request. The values are generally service specific.

=item message

The message that will be shown to the user in the browser on completion.

=item message_type

The content type of the message e.g. C<text/plain> or C<text/html>.

=back

=head1 TODO

Open ID Connect and OAuth2 are large standards, so far only a tiny fraction is implemented here. Feel free to request specific features if you need them. Patches are welcome.

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
