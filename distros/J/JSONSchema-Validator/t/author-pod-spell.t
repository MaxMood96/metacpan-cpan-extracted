
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;
use Test::More;

# generated by Dist::Zilla::Plugin::Test::PodSpelling 2.007005
use Test::Spelling 0.12;
use Pod::Wordlist;


add_stopwords(<DATA>);
all_pod_files_spelling_ok( qw( bin lib ) );
__DATA__
Alexey
Andrey
Anton
Constraints
Denis
Draft4
Draft6
Draft7
Erik
Error
Fedotov
Format
Huelsmann
Ibaev
Ivan
JSONPointer
JSONSchema
James
Khozov
OAS30
OpenAPI
Putintsev
Stavrov
URIResolver
Util
Validator
Waters
andrey
deserializers
dionys
ehuels
james
lib
logioniz
tosha
uid
validator
validators
