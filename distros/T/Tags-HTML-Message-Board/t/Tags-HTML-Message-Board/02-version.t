use strict;
use warnings;

use Tags::HTML::Message::Board;
use Test::More 'tests' => 2;
use Test::NoWarnings;

# Test.
is($Tags::HTML::Message::Board::VERSION, 0.05, 'Version.');
