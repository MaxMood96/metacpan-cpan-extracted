use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.007005
use Test::Spelling 0.12;
use Pod::Wordlist;


add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib ) );
__DATA__
Base
BuildAll
Bunce
Constructor
George
Graham
Hartzell
JJ
Kaufman
Knop
Late
Merelo
MooX
Role
Samuel
StrictConstructor
Tim
haarg
hartzell
jjmerelo
jjrs
jrubinator
lib
mohawk2
samuel
