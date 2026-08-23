use v5.36;
use strict;
use warnings;
use Test::More;

use_ok('Linux::Event::Stream');
use_ok('Linux::Event::Error');
require_ok('Linux::Event::Framer');
use_ok('Linux::Event::Framer::Delimiter');
use_ok('Linux::Event::Framer::Fixed');
use_ok('Linux::Event::Framer::LengthPrefix');
use_ok('Linux::Event::Framer::U32BE');
use_ok('Linux::Event::Framer::Netstring');
use_ok('Linux::Event::Framer::Varint');
use_ok('Linux::Event::Framer::DecimalLength');

done_testing;
