use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.007005
use Test::Spelling 0.12;
use Pod::Wordlist;

set_spell_cmd('aspell list');
add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib ) );
__DATA__
49699333
Aas
Adam
Alders
Alex
Base
Berners
Bonaccorso
Branislav
Brendan
Byrd
CRS
Ceccarelli
Chae
Chase
Costa
David
Deguest
Dick
Dorian
Dubois
Escape
Etheridge
FAT
Fiegehenn
Fredric
Förtsch
Gianni
Gisle
Graham
HOTP
Herzog
Heuristic
Honma
Håkon
Hægland
IDNA
IRI
ISBNs
Ishigaki
Jacques
James
Jan
Joenio
John
Julien
Kaitlyn
Kaji
Kapranoff
Karen
Karr
Kenichi
Kent
Kereliuk
Knop
Koster
Lawrence
Mac
Mark
Martijn
Masahiro
Masinter
Matt
Matthew
Michael
Miller
Miyagawa
OIDs
OS2
OTP
Olaf
OpenLDAP
Parkhurst
Perl
Perlbotics
Peter
Piotr
Punycode
QNX
QueryParam
Rabbitson
Raspass
Rezic
Roszatycki
Ryan
Salvatore
Schmidt
Schwern
Sebastian
Shoichi
Skyttä
Slaven
Split
Stosberg
TCP
TLS
TOTP
Tatsuhiko
Taylor
Torsten
UDP
UNC
URI
URL
Unix
Ville
Whitener
Willing
Win32
WithBase
Zahradník
_foreign
_generic
_idna
_ldap
_login
_punycode
_query
_segment
_server
_userpass
adam
brainbuz
brian
capoeirab
carnil
cryptographic
data
davewood
ddick
dependabot
dorian
ether
etype
evalue
file
foy
ftp
ftpes
ftps
geo
gerard
gianni
gisle
gopher
gregoa
gregor
haarg
hakon
happy
herrmann
hiratara
hotp
http
https
icap
icaps
irc
ircs
isbn
ishigaki
jack
jand
joenio
john
jraspass
kapranoff
kentfredric
ldap
ldapi
ldaps
lib
lon
lowercasing
mailto
mark
matthewlawrence
miyagawa
mms
mschae
news
nntp
nntps
oid
olaf
otpauth
perlbotix
piotr
pop
relativize
ribasushi
rlogin
rsync
rtsp
rtspu
ryker
schwern
scp
sewi
sftp
simbabque
sip
sips
skaji
slaven
snews
ssh
symkat
telnet
tn3270
torsten
totp
unicode
uppercasing
urn
ville
xn
