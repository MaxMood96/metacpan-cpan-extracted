#!/usr/bin/perl
#
# This file is part of App-SpreadRevolutionaryDate
#
# This software is Copyright (c) 2019-2025 by Gérald Sédrati.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#
use utf8;

BEGIN {
    $ENV{OUTPUT_CHARSET} = 'UTF-8';
}
binmode(DATA, ":encoding(UTF-8)");

use Test::More tests => 5;
use Test::Output;
use Test::NoWarnings;

package App::SpreadRevolutionaryDate::Target::Ezln;
use Moose;
with 'App::SpreadRevolutionaryDate::Target' => {worker => 'IO::Handle'};
use namespace::autoclean;
use IO::Handle;

has 'subcomandantes' => (is => 'ro', isa => 'ArrayRef[Str]', required => 1);
has 'land' => (is => 'ro', isa => 'Str', required => 1);

around BUILDARGS => sub {
  my ($orig, $class) = @_;

  my $io = IO::Handle->new;
  $io->fdopen(fileno(STDOUT), "w");
  return $class->$orig(@_, obj => $io);
};

sub spread {
  my ($self, $msg) = @_;

  $self->{obj}->say("From " . $self->land . "\n$msg\nSubcomandantes " . join(', ', @{$self->subcomandantes}));
  $self->obj->flush;
}

1;

package main;

use App::SpreadRevolutionaryDate;

my $spread_revolutionary_date = App::SpreadRevolutionaryDate->new(\*DATA);
is_deeply($spread_revolutionary_date->config->targets, ['ezln'], 'EZLN target option set');
is($spread_revolutionary_date->config->ezln_land, 'Chiapas', 'EZLN land value');
is_deeply($spread_revolutionary_date->config->ezln_subcomandantes, ['Marcos', 'Moises', 'Galeano'], 'EZLN subcomandantes values');
stdout_like {$spread_revolutionary_date->spread } qr/^From Chiapas\nWe are .+\nSubcomandantes Marcos, Moises, Galeano\n$/u, 'Spread to Ezln';

__DATA__
targets = 'ezln'
locale = 'en'

[ezln]
subcomandantes = 'Marcos'
subcomandantes = 'Moises'
subcomandantes = 'Galeano'
land = 'Chiapas'
