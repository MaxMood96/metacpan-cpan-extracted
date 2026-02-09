#!/usr/bin/perl

use v5.14;
use warnings;

use IO::Async::LoopTests 0.24;

use Future::IO;
Future::IO->load_best_impl;

run_tests( 'IO::Async::Loop::FutureIO', 'idle' );
