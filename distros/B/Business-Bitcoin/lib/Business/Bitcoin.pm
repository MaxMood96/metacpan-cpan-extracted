# -*-cperl-*-
#
# Business::Bitcoin - Easy and secure way to accept Bitcoin payments online
# Copyright (c) Ashish Gulhati <biz-btc at hash.neo.tc>
#
# $Id: lib/Business/Bitcoin.pm v1.051 Tue Oct 16 22:26:58 PDT 2018 $

use strict;

package Business::Bitcoin;

use 5.010000;
use warnings;
use strict;

use DBI;
use Business::Bitcoin::Request;

use vars qw( $VERSION $AUTOLOAD );

our ( $VERSION ) = '$Revision: 1.051 $' =~ /\s+([\d\.]+)/;

sub new {
  my $class = shift;
  my %arg = @_;
  return undef unless $arg{XPUB};
  return undef if $arg{StartIndex} and $arg{StartIndex} =~ /\D/;
  unlink $arg{DB} if $arg{Clobber} and $arg{DB} ne ':memory:';
  my $db = DBI->connect("dbi:SQLite:dbname=$arg{DB}", undef, undef, {AutoCommit => 1});
  my @tables = $db->tables('%','%','requests','TABLE');
  unless ($tables[0]) {
    if ($arg{Create}) {
      return undef unless $db->do('CREATE TABLE requests (
		                                         reqid INTEGER PRIMARY KEY AUTOINCREMENT,
		                                         amount int NOT NULL,
                                                         address text,
                                                         reference text UNIQUE,
		                                         created int NOT NULL,
                                                         processed int,
                                                         status text
		                                        );');
      return undef unless $db->do('CREATE INDEX idx_requests_address ON requests(address);');
      return undef unless $db->do('CREATE INDEX idx_requests_reference ON requests(reference);');
      my $startindex = $arg{StartIndex} || 0;
      $startindex--;
      return unless $db->do("INSERT INTO SQLITE_SEQUENCE values ('requests',$startindex);");
    }
    else {
      return undef;
    }
  }
  bless { XPUB => $arg{XPUB}, DB => $db, PATH => $arg{Path} || 'penultimate' }, $class;
}

sub request {                      # Create a Bitcoin payment request
  my ($self, %arg) = @_;
  return undef if $arg{Amount} !~ /^\d+$/;

  # Workaround for SQLite not starting sequence from 0 when asked to in new()
  my $startindex = $self->db->selectcol_arrayref("SELECT seq from SQLITE_SEQUENCE WHERE name='requests';")->[0];
  my %forcezero; %forcezero = ( StartIndex => 0 ) if $startindex == -1;

  my $req = new Business::Bitcoin::Request (_BizBTC => $self, %arg, %forcezero);
}

sub findreq {                      # Retrieve a previously created request
  my ($self, %arg) = @_;
  my $req = _find Business::Bitcoin::Request (_BizBTC => $self, %arg);
}

sub AUTOLOAD {
  my $self = shift; (my $auto = $AUTOLOAD) =~ s/.*:://;
  return if $auto eq 'DESTROY';
  if ($auto =~ /^(xpub|path|db)$/x) {
    $self->{"\U$auto"} = shift if (defined $_[0]);
  }
  if ($auto =~ /^(xpub|path|db|version)$/x) {  
    return $self->{"\U$auto"};
  }
  else {
    die "Could not AUTOLOAD method $auto.";
  }
}

1; # End of Business::Bitcoin

__END__

=head1 NAME

Business::Bitcoin - Easy and secure way to accept Bitcoin payments online

=head1 VERSION

 $Revision: 1.051 $
 $Date: Tue Oct 16 22:26:58 PDT 2018 $

=head1 SYNOPSIS

An easy and secure way to accept Bitcoin payments online using an HD
wallet, generating new receiving addresses on demand and keeping the
wallet private key offline.

    use Business::Bitcoin;

    my $bizbtc = new Business::Bitcoin (DB => '/tmp/bizbtc.db',
                                        XPUB => 'xpub...',
                                        Create => 1);

    my $req = $bizbtc->request(Amount => 4200);

    print 'Please pay '           . $req->amount . ' Satoshi ' .
          'to Bitcoin address '   . $req->address . ".\n" .
          'Once the payment has ' . $req->confirmations , ' confirmations, ' .
          "press <enter> to continue.\n";
    readline(*STDIN);

    print ($req->verify ? "Verified\n" : "Verification failed\n");

    print "Enter a request address to verify a payment.\n";
    my $address = <STDIN>; chomp $address;

    my $req2 = $bizbtc->findreq(Address => $address);
    print ($req2->verify ? "Verified\n" : "Verification failed\n");

=head1 HOW TO USE

To start receiving Bitcoin payments online, create an HD wallet using
a BIP-32 HD wallet app such as Electrum, get the Extended Public Key
for the wallet (a string beginning with "xpub") and plug it into the
constructor's XPUB argument.

Now you can receive online payments as outlined above, while keeping
your private key secure offline or in a hardware wallet. You should
take all precautions to ensure that your XPUB key on the server is
also safe, as its compromise can weaken your security, though it can't
in itself lead to the loss of any Bitcoin.

To make this work right you need to find the correct key to plug into
the XPUB parameter, so that the addresses generated by
Business::Bitcoin match those your wallet uses to receive payments.

If you're using the Electrum wallet, you can just use its Master
Public Key (from the menubar select Wallet -> Master Public Keys). To
use this key you must also set the 'Path' parameter to 'electrum' when
creating a new Business::Bitcoin object (or via the path() accessor).

By default, however, the addresses Business::Bitcoin generates will be
for the key derivation path k/i, where k is the path of the extended
public key provided in the XPUB parameter, and i is the index of the
address being generated.

This provides the flexibility to use Business::Bitcoin in conjunction
with any wallet, because different wallets use different key
derivation paths to generate addresses. e.g. Electrum uses the path
"m/0/i", MultiBit HD uses "m/a'/0/i", Mycellium uses
"m/44'/0'/a'/0/i", etc. (m is the "Master Public Key" and a is the
"account" index).

To have Business::Bitcoin generate addresses matching those generated
by your wallet, ensure that the XPUB parameter contains the public key
for the penultimate element of your wallet's key derivation path. So
for Electrum that would be m/0, for MultiBit HD m/a'/0, and for
Mycellium m/44'/0'/a'/0

Some wallets may not readily provide the key for this element of the
path. In that case you can find it using a tool such as "ku" from
Pycoin L<https://github.com/richardkiss/pycoin> or a JavaScript tool
such as the one at L<http://bip32.org/>. It's probably best never to
paste private keys in web forms however, so if your key derivation
path requires the private key, best to use something like the "ku"
tool on an offline machine.

=head1 METHODS

=head2 new

Create a new Business::Bitcoin object and open (or create) the
requests database. The following named arguments are required:

=over

DB - The filename of the requests database

XPUB - The extended public key for the wallet receiving payments

=back

The following optional named arguments can be provided:

=over

Create - Create the requests table if it doesn't exist. If the table
doesn't exist and Create is not true, the constructor will return
undef. Unset by default.

Clobber - Wipe out any existing database file first. Unset by default.

StartIndex - Start generating receiving keys from the specified index
rather than from 0. Useful if you've already used some receiving
addresses before starting to receive payments using this
module. Only relevant when Create is true and a new
requests table is being created. Ignored when an existing
requests table is being used; in that case the index is generated by the
database. By default, receiving addresses will be generated starting
from the first one, at index 0.

Path - Set the path option for the key provided in the XPUB
parameter. By default this is set to 'penultimate' which means the
XPUB parameter should hold the key of the penultimate path element as
described above. You can also set this to 'electrum', in which case
you can directly provide ELectrum's "Master Public Key" in the XPUB
parameter. (The master public key is at path "m", whereas the
penultimate one to generate Electrum compatible addresses is at
"m/0").

=back

=head2 request

Create a new payment request and generate a new receiving
address. Returns a Business::Bitcoin::Request object if successful, or
undef on error. The following named argument is required:

=over

Amount - The amount of the payment requested, in Satoshi.

=back

The following optional named arguments can be provided:

=over

Confirmations - The number of confirmations needed to verify payment
of this request. The default is 5.

Reference - Optional reference ID to be associated with the request,
to facilitate integration with existing ordering systems. If a
reference ID is provided it should be unique for each request.

=back

=head2 findreq

Find a previously created payment request, by either Address or
Reference. Returns a Business::Bitcoin::Request object if successful,
or undef on error. Exactly one of the following named arguments is
required:

=over

Address - The receiving address associated with the payment request

Reference - The reference ID associated with the payment request

=back

The following optional named argument can be provided:

=over

Confirmations - The number of confirmations needed to verify payment
of this request. The default is 5.

=back

=head1 ACCESSORS

Accessors can be called with no arguments to query the value of an
object property, or with a single argument, to set the property to a
specific value (unless the property is read only).

=head2 db

The filename of the requests DB file.

=head2 xpub

The extended public key from which all receiving keys are generated.

=head2 path

The path option for the XPUB key. This can either be 'penultimate'
(the default) in which case addresses are generated using the path
"k/i", or 'electrum' in which case addresses are generated using the
path "k/0/i", where "k" is the path of the XPUB key provided.

=head2 version

The version number of this module. Read only.

=head1 PREREQUISITES

=head2 DBD::SQLite

Used to keep track of payment requests.

=head2 LWP and an Internet connection

Required to verify payments. Currently this is done via the
blockchain.info API.

=head1 AUTHOR

Ashish Gulhati, C<< <biz-btc at hash.neo.tc> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-business-bitcoin at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-Bitcoin>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::Bitcoin

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Business-Bitcoin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Business-Bitcoin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Business-Bitcoin>

=item * Search CPAN

L<http://search.cpan.org/dist/Business-Bitcoin/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright (c) Ashish Gulhati.

This software package is Open Software; you can use, redistribute,
and/or modify it under the terms of the Open Artistic License 2.0.

Please see L<http://www.opensoftwr.org/oal20.txt> for the full license
terms, and ensure that the license grant applies to you before using
or modifying this software. By using or modifying this software, you
indicate your agreement with the license terms.
