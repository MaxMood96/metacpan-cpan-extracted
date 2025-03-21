package Bitcoin::Crypto::BIP44;
$Bitcoin::Crypto::BIP44::VERSION = '3.001';
use v5.10;
use strict;
use warnings;
use Moo;
use Mooish::AttributeBuilder -standard;
use Types::Common -sigs, -types;

use Scalar::Util qw(blessed);

use Bitcoin::Crypto::DerivationPath;
use Bitcoin::Crypto::Types -types;
use Bitcoin::Crypto::Network;
use Bitcoin::Crypto::Exception;

use namespace::clean;

sub _get_network_constant
{
	my ($network) = @_;

	my $coin_type = $network->bip44_coin;

	Bitcoin::Crypto::Exception::NetworkConfig->raise(
		'no bip44_coin constant found in network configuration'
	) unless defined $coin_type;

	return $coin_type;
}

use namespace::clean;

has param 'purpose' => (
	isa => BIP44Purpose,
	default => 44,
);

has param 'coin_type' => (
	isa => PositiveOrZeroInt,
	coerce => sub {
		my ($coin_type) = @_;

		if (blessed $coin_type) {
			$coin_type = $coin_type->network
				if $coin_type->DOES('Bitcoin::Crypto::Role::Network');

			$coin_type = _get_network_constant($coin_type)
				if $coin_type->isa('Bitcoin::Crypto::Network');
		}

		return $coin_type;
	},
	default => sub {
		_get_network_constant(Bitcoin::Crypto::Network->get);
	},
);

has param 'account' => (
	isa => PositiveOrZeroInt,
	default => 0,
);

has param 'change' => (
	isa => Enum [1, 0],
	default => 0,
);

has param 'index' => (
	isa => PositiveOrZeroInt,
	default => 0,
);

has param 'get_account' => (
	isa => Bool,
	default => !!0,
);

has param 'get_from_account' => (
	isa => Bool,
	default => !!0,
);

has param 'public' => (
	isa => Bool,
	default => !!0,
);

with qw(Bitcoin::Crypto::Role::WithDerivationPath);

use overload
	q{""} => sub { shift->as_string },
	fallback => 1;

signature_for as_string => (
	method => Object,
	positional => [],
);

sub as_string
{
	my ($self) = @_;

	# https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
	# m / purpose' / coin_type' / account' / change / address_index

	my $path = $self->public ? 'M' : 'm';

	$path = sprintf "%s/%u'/%u'/%u'",
		$path, $self->purpose, $self->coin_type, $self->account
		if !$self->public && !$self->get_from_account;

	return $path
		if $self->get_account;

	return sprintf "%s/%u/%u",
		$path, $self->change, $self->index;
}

signature_for get_derivation_path => (
	method => Object,
	positional => [],
);

sub get_derivation_path
{
	my ($self) = @_;

	return Bitcoin::Crypto::DerivationPath->from_string($self->as_string);
}

1;

__END__
=head1 NAME

Bitcoin::Crypto::BIP44 - BIP44 (multi-account hierarchy) implementation

=head1 SYNOPSIS

	use Bitcoin::Crypto::BIP44;

	my $path = Bitcoin::Crypto::BIP44->new(
		coin_type => Bitcoin::Crypto::Network->get('bitcoin_testnet'), # can also be a number or a key instance
		index => 43,
		# account => 0,
		# change => 0,
	);

	# stringifies automatically
	say "$path";

	# can be used in key derivation
	$ext_private_key->derive_key($path);

=head1 DESCRIPTION

This class is a helper for constructing BIP44-compilant key derivation paths.
BIP44 describes the mechanism the HD (Hierarchical Deterministic) wallets use
to decide derivation paths for coins. BIP49 and BIP84 are constructed the same
way, but used for compat and segwit addresses respectively.

Each coin has its own C<coin_type> constant, a list of which is maintained
here: L<https://github.com/satoshilabs/slips/blob/master/slip-0044.md>.
L<Bitcoin::Crypto::Network> instances hold these constants under the
C<bip44_coin> property.

BIP44 objects stringify automatically and can be directly used in
L<Bitcoin::Crypto::Key::ExtPrivate/derive_key> method. In return, any key
object can be used as C<coin_type> in L</new>, which will automatically fetch
coin_type number from the key's current network.

=head1 INTERFACE

=head2 Attributes

Refer to L<https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki> for
details of those attributes.

All of these attributes can be fetched using a method with the same name.

=head3 purpose

Purpose contains the BIP document number that you wish to use. Can be either
C<44>, C<49> or C<84>.

By default, number C<44> will be used.

=head3 coin_type

Needs to be a non-negative integer number. It should be less than C<2^31> (but
will not check for that).

Will also accept key objects and network objects, as it is possible to fetch
the constant for them. In this case, it might raise an exception if the network
does not contain the C<bip44_coin> constant.

This value should be in line with the table of BIP44 constants mentioned above.

By default, the value defined in the current default network will be used: see
L<Bitcoin::Crypto::Network>.

=head3 account

Needs to be a non-negative integer number. It should be less than C<2^31> (but
will not check for that).

By default, the value C<0> is used.

=head3 change

Needs to be a number C<1> (for addresses to be used as change outputs) or C<0>
(for addresses that are to be used only internally).

By default, the value C<0> is used.

=head3 index

Needs to be a non-negative integer number. It should be less than C<2^31> (but
will not check for that).

By default, the value C<0> is used.

=head3 public

Use C<public> if you want to derive a public extended key. This is a must when
deriving BIP44 from extended public keys.

Since it isn't possible to derive full BIP44 path with public derivation
scheme, this will assume L</get_from_account>.

=head3 get_account

If passed C<1>, the resulting derivation path will only go as far as to the
account part. L</index> and L</change> values will be ignored. Use this to get
extended key for the account.

By default, you will get the full derivation path.

=head3 get_from_account

If passed C<1>, the resulting derivation path will start after the account
part. L</purpose>, L</coin_type> and L</account> values will be ignored. Use
this to further derive key that was only derived up to the account part.

By default, you will get the full derivation path.

=head2 Methods

=head3 new

	$bip_object = $class->new(%data)

This is a standard Moo constructor, which can be used to create the object. It
takes arguments specified in L</Attributes>.

Returns class instance.

=head3 as_string

	$path = $object->as_string()

Stringifies the object as BIP44-compilant key derivation path. Can be used
indirectly by just stringifying the object.

=head3 get_derivation_path

	my $path_obj = $object->get_derivation_path()

Returns an object of class L<Bitcoin::Crypto::DerivationPath>.

=head1 EXCEPTIONS

This module throws an instance of L<Bitcoin::Crypto::Exception> if it
encounters an error. It can produce the following error types from the
L<Bitcoin::Crypto::Exception> namespace:

=over

=item * NetworkConfig - incomplete or corrupted network configuration

=back

=head1 SEE ALSO

L<Bitcoin::Crypto::Key::ExtPrivate>

L<https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki>

