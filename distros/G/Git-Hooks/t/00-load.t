#!/usr/bin/env perl

use v5.30.0;
use warnings;
use lib qw/t lib/;
use Test::More tests => 1;

use_ok "Git::Hooks::Test";

1;
