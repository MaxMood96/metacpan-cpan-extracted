package Crypt::Passphrase::Linux;
$Crypt::Passphrase::Linux::VERSION = '0.004';
use strict;
use warnings;

use parent 'Crypt::Passphrase::Encoder';

use Carp 'croak';
use Crypt::Passwd::XS;
use Crypt::Passphrase::Util::Crypt64 'encode_crypt64';

my %identifier_for = (
	des        => '',
	md5        => '1',
	apache_md5 => 'apr1',
	sha256     => '5',
	sha512     => '6',
);

my %salt_size = (
	des        => 2,
	md5        => 6,
	apache_md5 => 6,
	sha256     => 12,
	sha512     => 12,
);

sub new {
	my ($class, %args) = @_;
	my $type_name = $args{type} // 'sha512';
	my $type = $identifier_for{$type_name} // croak "No such crypt type $type_name";
	my $salt_size = $salt_size{$type_name};
	my $rounds = $args{rounds} // 656_000;

	return bless {
		type      => $type,
		rounds    => $rounds + 0,
		salt_size => $salt_size,
	}, $class;
}

sub hash_password {
	my ($self, $password) = @_;
	my $salt = $self->random_bytes($self->{salt_size});
	my $encoded_salt = encode_crypt64($salt);
	substr $encoded_salt, 2, 1, '' if $self->{salt_size} == 2; # descrypt
	my $settings = $self->{type} ? sprintf '$%s$rounds=%d$%s', $self->{type}, $self->{rounds}, $encoded_salt : $encoded_salt;
	return Crypt::Passwd::XS::crypt($password, $settings);
}

sub accepts_hash {
	my ($self, $hash) = @_;
	return $hash =~ / \A [.\/A-Za-z0-9]{13} \z /x || $self->SUPER::accepts_hash($hash);
}

sub crypt_subtypes {
	return values %identifier_for;
}

my $regex = qr/ ^ \$ (1|5|6|apr1) \$ (?: rounds= ([0-9]+) \$ )? ([^\$]*) \$ [^\$]+ $ /x;

sub needs_rehash {
	my ($self, $hash) = @_;
	if (length $self->{type}) {
		my ($type, $rounds, $salt) = $hash =~ $regex or return 1;
		$rounds = 5000 if $rounds eq '';
		return $type ne $self->{type} || $rounds != $self->{rounds} || length $salt != $self->{salt_size} * 4 / 3;
	} else {
		return $hash !~ / \A [.\/A-Za-z0-9]{13} \z /x;
	}
}

sub verify_password {
	my ($class, $password, $hash) = @_;
	my $new_hash = Crypt::Passwd::XS::crypt($password, $hash);
	return $class->secure_compare($hash, $new_hash);
}

#ABSTRACT: An linux crypt encoder for Crypt::Passphrase

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Crypt::Passphrase::Linux - An linux crypt encoder for Crypt::Passphrase

=head1 VERSION

version 0.004

=head1 SYNOPSIS

 my $passphrase = Crypt::Passphrase->new(encoder => {
   module => 'Linux',
   type   => 'sha512',
   rounds => 656_000,
 });

=head1 DESCRIPTION

This class implements a Crypt::Passphrase encoder compatible with Linux' crypt. This is useful when needing to specifically support the sha256 and sha512 password types.

=head2 ARGUMENTS

=over 4

=item * type

This choses the crypt type. It supports the following crypt types: C<sha512> (default), C<sha256>, C<md5>, C<apache_md5> and C<des>.

=item * rounds

The number of rounds using by the crypt implementation. This defaults to C<656000>, but may change at any time in the future. It is ignored for C<des>.

=back

=head1 AUTHOR

Leon Timmermans <fawaka@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
