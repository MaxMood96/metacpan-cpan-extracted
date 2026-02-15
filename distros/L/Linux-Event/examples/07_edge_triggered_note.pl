#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../lib";


say "edge_triggered_note:";
say "  Linux::Event supports edge_triggered => 1 on watch().";
say "  In edge-triggered mode, the loop will dispatch readiness once per edge.";
say "  User code must drain reads/writes until EAGAIN to receive the next edge.";
say "  This example is informational; see docs/Linux-Event-M1-Semantics-Freeze.md.";
