package Crypt::Cipher::Camellia;

### BEWARE - GENERATED FILE, DO NOT EDIT MANUALLY!

use strict;
use warnings;
our $VERSION = '0.087';

use base qw(Crypt::Cipher);

sub blocksize      { Crypt::Cipher::blocksize('Camellia')      }
sub keysize        { Crypt::Cipher::keysize('Camellia')        }
sub max_keysize    { Crypt::Cipher::max_keysize('Camellia')    }
sub min_keysize    { Crypt::Cipher::min_keysize('Camellia')    }
sub default_rounds { Crypt::Cipher::default_rounds('Camellia') }

1;

=pod

=head1 NAME

Crypt::Cipher::Camellia - Symmetric cipher Camellia, key size: 128/192/256 bits

=head1 SYNOPSIS

  ### example 1
  use Crypt::Mode::CBC;

  my $key = '...'; # length has to be valid key size for this cipher
  my $iv = '...';  # 16 bytes
  my $cbc = Crypt::Mode::CBC->new('Camellia');
  my $ciphertext = $cbc->encrypt("secret data", $key, $iv);

  ### example 2 (slower)
  use Crypt::CBC;
  use Crypt::Cipher::Camellia;

  my $key = '...'; # length has to be valid key size for this cipher
  my $iv = '...';  # 16 bytes
  my $cbc = Crypt::CBC->new( -cipher=>'Cipher::Camellia', -key=>$key, -iv=>$iv );
  my $ciphertext = $cbc->encrypt("secret data");

=head1 DESCRIPTION

This module implements the Camellia cipher. Provided interface is compliant with L<Crypt::CBC|Crypt::CBC> module.

B<BEWARE:> This module implements just elementary "one-block-(en|de)cryption" operation - if you want to
encrypt/decrypt generic data you have to use some of the cipher block modes - check for example
L<Crypt::Mode::CBC|Crypt::Mode::CBC>, L<Crypt::Mode::CTR|Crypt::Mode::CTR> or L<Crypt::CBC|Crypt::CBC> (which will be slower).

=head1 METHODS

=head2 new

 $c = Crypt::Cipher::Camellia->new($key);
 #or
 $c = Crypt::Cipher::Camellia->new($key, $rounds);

=head2 encrypt

 $ciphertext = $c->encrypt($plaintext);

=head2 decrypt

 $plaintext = $c->decrypt($ciphertext);

=head2 keysize

  $c->keysize;
  #or
  Crypt::Cipher::Camellia->keysize;
  #or
  Crypt::Cipher::Camellia::keysize;

=head2 blocksize

  $c->blocksize;
  #or
  Crypt::Cipher::Camellia->blocksize;
  #or
  Crypt::Cipher::Camellia::blocksize;

=head2 max_keysize

  $c->max_keysize;
  #or
  Crypt::Cipher::Camellia->max_keysize;
  #or
  Crypt::Cipher::Camellia::max_keysize;

=head2 min_keysize

  $c->min_keysize;
  #or
  Crypt::Cipher::Camellia->min_keysize;
  #or
  Crypt::Cipher::Camellia::min_keysize;

=head2 default_rounds

  $c->default_rounds;
  #or
  Crypt::Cipher::Camellia->default_rounds;
  #or
  Crypt::Cipher::Camellia::default_rounds;

=head1 SEE ALSO

=over

=item * L<CryptX|CryptX>, L<Crypt::Cipher>

=item * L<https://en.wikipedia.org/wiki/Camellia_(cipher)>

=back

=cut
