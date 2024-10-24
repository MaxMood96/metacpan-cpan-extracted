package Bitcoin::Crypto::BIP85;
$Bitcoin::Crypto::BIP85::VERSION = '3.001';
use v5.10;
use strict;
use warnings;
use Moo;
use Mooish::AttributeBuilder -standard;
use Types::Common -sigs, -types;
use List::Util qw(all);
use Crypt::Mac::HMAC qw(hmac);
use Crypt::Digest::SHAKE;

use Bitcoin::Crypto qw(btc_prv btc_extprv);
use Bitcoin::Crypto::Types -types;
use Bitcoin::Crypto::Util qw(mnemonic_from_entropy);
use Bitcoin::Crypto::Exception;

use namespace::clean;

has param 'key' => (
	isa => InstanceOf ['Bitcoin::Crypto::Key::ExtPrivate'],
);

sub _adjust_length
{
	my ($self, $bytes, $bytelength) = @_;

	if ($bytelength <= length $bytes) {
		return substr $bytes, 0, $bytelength;
	}
	else {
		my $shake = Crypt::Digest::SHAKE->new(256);
		$shake->add($bytes);
		return $shake->done($bytelength);
	}
}

signature_for derive_entropy => (
	method => Object,
	positional => [DerivationPath, Maybe [PositiveInt], {default => undef}],
);

sub derive_entropy
{
	my ($self, $path_info, $bytelength) = @_;

	Bitcoin::Crypto::Exception::KeyDerive->raise(
		'seed derivation path must be fully hardened'
	) unless all { !!$_->[1] } @{$path_info->get_path_hardened};

	my $key = $self->key->derive_key($path_info);

	my $seed = hmac('SHA512', 'bip-entropy-from-k', $key->raw_key('private'));
	$seed = $self->_adjust_length($seed, $bytelength)
		if $bytelength;

	return $seed;
}

signature_for derive_mnemonic => (
	method => Object,
	named => [
		words => Enum [12, 18, 24],
		{default => 24},
		language => Str,
		{default => 'en'},
		index => PositiveOrZeroInt,
		{default => 0},
	],
	bless => !!0,
);

sub derive_mnemonic
{
	my ($self, $args) = @_;

	my %language_map = (
		'en' => 0,
		'ja' => 1,
		'ko' => 2,
		'es' => 3,
		'zh-simplified' => 4,
		'zh-traditional' => 5,
		'fr' => 6,
		'it' => 7,

		# NOTE: czech has no BIP39 wordlist module, but add it for sake of completeness
		'cz' => 8,
	);

	my $language_index = $language_map{$args->{language}};
	Bitcoin::Crypto::Exception::MnemonicGenerate->raise(
		"unknown mnemonic language code $args->{language}"
	) unless defined $language_index;

	my $spec_path = "m/83696968'/39'/$language_index'/$args->{words}'/$args->{index}'";
	my $length = $args->{words} / 3 * 4;

	my $entropy = $self->derive_entropy($spec_path, $length);
	return mnemonic_from_entropy($entropy, $args->{language});
}

signature_for derive_prv => (
	method => Object,
	named => [
		index => PositiveOrZeroInt,
		{default => 0},
	],
	bless => !!0,
);

sub derive_prv
{
	my ($self, $args) = @_;

	my $spec_path = "m/83696968'/2'/$args->{index}'";

	my $entropy = $self->derive_entropy($spec_path, 32);
	return btc_prv->from_serialized($entropy);
}

signature_for derive_extprv => (
	method => Object,
	named => [
		index => PositiveOrZeroInt,
		{default => 0},
	],
	bless => !!0,
);

sub derive_extprv
{
	my ($self, $args) = @_;

	my $spec_path = "m/83696968'/32'/$args->{index}'";

	my $entropy = $self->derive_entropy($spec_path);
	return btc_extprv->new(
		key_instance => substr($entropy, 32, 32),
		chain_code => substr($entropy, 0, 32),
	);
}

signature_for derive_bytes => (
	method => Object,
	named => [
		bytes => Int->where(q{$_ >= 16 && $_ <= 64}),
		{default => 64},
		index => PositiveOrZeroInt,
		{default => 0},
	],
	bless => !!0,
);

sub derive_bytes
{
	my ($self, $args) = @_;

	my $spec_path = "m/83696968'/128169'/$args->{bytes}'/$args->{index}'";

	return $self->derive_entropy($spec_path, $args->{bytes});
}

1;

__END__
=head1 NAME

Bitcoin::Crypto::BIP85 - BIP85 (deterministic entropy) implementation

=head1 SYNOPSIS

	use Bitcoin::Crypto::BIP85;

	my $bip85 = Bitcoin::Crypto::BIP85->new(
		key => $extended_private_key,
	);

	# get raw bytestring seed
	my $seed = $bip85->derive_entropy("m/0'/0'");

	# get a mnemonic
	my $mnemonic = $bip85->derive_mnemonic(index => 0);

=head1 DESCRIPTION

This module implements
L<BIP85|https://github.com/bitcoin/bips/blob/master/bip-0085.mediawiki>,
enabling deterministic entropy generation from a master key.

It currently implements the following applications from the BIP85 spec:

=over

=item * C<BIP39>: L</derive_mnemonic>

This application requires extra CPAN wordlists for L<Bitcoin::BIP39> to handle
other languages than C<en>.

=item * C<HD-Seed WIF>: L</derive_prv>

This application returns a private key instead of a WIF, but can be serialized
using L<Bitcoin::Crypto::Key::Private/to_wif>.

=item * C<XPRV>: L</derive_extprv>

This application returns an extended private key instead of its serialized
version, but can be serialized using
L</Bitcoin::Crypto::Key::ExtPrivate/to_serialized>.

=item * C<HEX>: L</derive_bytes>

This application returns a bytestring instead of a hex string in order to be
coherent with other similar Bitcoin::Crypto methods. It can be represented as
hex using L<Bitcoin::Crypto::Util/to_format>.

=back

Missing BIP85 applications can be implemented using L</derive_entropy> with
proper derivation path and entropy length.

=head1 INTERFACE

=head2 Attributes

=head3 key

B<Required in the constructor.> The master key from which the generation will
be performed, an instance of L<Bitcoin::Crypto::Key::ExtPrivate>.

=head2 Methods

=head3 new

	$bip_object = $class->new(%data)

This is a standard Moo constructor, which can be used to create the object. It
takes arguments specified in L</Attributes>.

=head3 derive_entropy

	$bytestr = $object->derive_entropy($path, $length = undef)

Returns entropy derived from the master key using
C<$path>, which can be a standard string derivation path like
C<m/83696968'/0'/0'> or an instance of L<Bitcoin::Crypto::DerivationPath>. The
derivation path must be fully hardened, as specified in the BIP.

Optional C<$length> is the desired length of the entropy B<in bytes>. If not
provided, full C<64> bytes of entropy will be returned. If provided and less
than C<64>, the entropy will be truncated to the derired length. If greater
than C<64>, the C<DRNG> algorithm defined in BIP85 will be used to stretch the
entropy to this size.

=head3 derive_mnemonic

	$mnemonic = $object->derive_mnemonic(%args)

Derives mnemonic from the master key. C<%args> can be any combination of:

=over

=item * C<words>

The number of words to generate. Can be either C<12>, C<18> or C<24>. Default: C<24>.

=item * C<language>

The language to use. See L<Bitcoin::BIP39> for more info about this argument. Default: C<en>.

=item * C<index>

The generation index. Must be a non-negative integer. Default: C<0>

=back

=head3 derive_prv

	$prv = $object->derive_prv(%args)

Derives private key from the master key. The key can immediately be
serialized using C<< ->to_wif >> to match BIP85 spec for this
application. C<%args> can be any combination of:

=over

=item * C<index>

The generation index. Must be a non-negative integer. Default: C<0>

=back

=head3 derive_extprv

	$extprv = $object->derive_extprv(%args)

Derives an extended private key from the master key. The key can immediately be
serialized using C<< ->to_serialized >> to match BIP85 spec for this
application. C<%args> can be any combination of:

=over

=item * C<index>

The generation index. Must be a non-negative integer. Default: C<0>

=back

=head3 derive_bytes

	$bytestr = $object->derive_bytes(%args)

Derives a number of bytes from the master key. The key can immediately be
serialized as hex using L<Bitcoin::Crypto::Util/to_format> to match BIP85 spec
for this application. C<%args> can be any combination of:

=over

=item * C<bytes>

The number of bytes to generate. Must be between C<16> and C<64>, inclusive.

=item * C<index>

The generation index. Must be a non-negative integer. Default: C<0>

=back

