use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.007005
use Test::Spelling 0.12;
use Pod::Wordlist;


add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib ) );
__DATA__
Alders
Alders'
Andy
Code
Dave
Eilam
Eilam's
Fmt
Go
Greg
Gregory
Inc
Jack
MAXMIND
MAXMIND's
MaxMind
MaxMind's
Oschwald
Oschwald's
PayPal
Plugin
Rolsky
Rolsky's
TidyAll
Vet
andyjack
distro
drolsky
gofmt
goschwald
lib
oschwald
