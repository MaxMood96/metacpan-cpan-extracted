package Zing::Types;

use 5.014;

use strict;
use warnings;

use Data::Object::Types::Keywords;

use base 'Data::Object::Types::Library';

extends 'Types::Standard';

our $VERSION = '0.27'; # VERSION

register {
  name => 'App',
  parent => 'Object',
  validation => is_instance_of('Zing::App'),
};

register {
  name => 'Cartridge',
  parent => 'Object',
  validation => is_instance_of('Zing::Cartridge'),
};

register {
  name => 'Channel',
  parent => 'Object',
  validation => is_instance_of('Zing::Channel'),
};

register {
  name => 'Cli',
  parent => 'Object',
  validation => is_instance_of('Zing::Cli'),
};

register {
  name => 'Cursor',
  parent => 'Object',
  validation => is_instance_of('Zing::Cursor'),
};

register {
  name => 'Daemon',
  parent => 'Object',
  validation => is_instance_of('Zing::Daemon'),
};

register {
  name => 'Data',
  parent => 'Object',
  validation => is_instance_of('Zing::Data'),
};

register {
  name => 'Domain',
  parent => 'Object',
  validation => is_instance_of('Zing::Domain'),
};

register {
  name => 'Encoder',
  parent => 'Object',
  validation => is_instance_of('Zing::Encoder'),
};

register {
  name => 'Entity',
  parent => 'Object',
  validation => is_instance_of('Zing::Entity'),
};

register {
  name => 'Env',
  parent => 'Object',
  validation => is_instance_of('Zing::Env'),
};

register {
  name => 'Error',
  parent => 'Object',
  validation => is_instance_of('Zing::Error'),
};

register {
  name => 'Flow',
  parent => 'Object',
  validation => is_instance_of('Zing::Flow'),
};

register {
  name => 'Fork',
  parent => 'Object',
  validation => is_instance_of('Zing::Fork'),
};

declare 'Interupt',
  as Enum([qw(CHLD HUP INT QUIT TERM USR1 USR2)]);

register {
  name => 'ID',
  parent => 'Object',
  validation => is_instance_of('Zing::ID'),
};

register {
  name => 'Journal',
  parent => 'Object',
  validation => is_instance_of('Zing::Journal'),
};

register {
  name => 'Kernel',
  parent => 'Object',
  validation => is_instance_of('Zing::Kernel'),
};

declare 'Key',
  as Str(),
  where {
    $_ =~ qr(^[^\:]+:[^\:]+:[^\:]+:[^\:]+:[^\:]+$)
  };

register {
  name => 'KeyVal',
  parent => 'Object',
  validation => is_instance_of('Zing::KeyVal'),
};

register {
  name => 'Launcher',
  parent => 'Object',
  validation => is_instance_of('Zing::Launcher'),
};

register {
  name => 'Logic',
  parent => 'Object',
  validation => is_instance_of('Zing::Logic'),
};

register {
  name => 'Lookup',
  parent => 'Object',
  validation => is_instance_of('Zing::Lookup'),
};

register {
  name => 'Loop',
  parent => 'Object',
  validation => is_instance_of('Zing::Loop'),
};

register {
  name => 'Logger',
  parent => 'Object',
  validation => is_instance_of('FlightRecorder'),
};

register {
  name => 'Mailbox',
  parent => 'Object',
  validation => is_instance_of('Zing::Mailbox'),
};

register {
  name => 'Meta',
  parent => 'Object',
  validation => is_instance_of('Zing::Meta'),
};

declare 'Name',
  as Str(),
  where {
    $_ =~ qr(^[^\:\*]+$)
  };

register {
  name => 'Poll',
  parent => 'Object',
  validation => is_instance_of('Zing::Poll'),
};

register {
  name => 'Process',
  parent => 'Object',
  validation => is_instance_of('Zing::Process'),
};

register {
  name => 'PubSub',
  parent => 'Object',
  validation => is_instance_of('Zing::PubSub'),
};

register {
  name => 'Queue',
  parent => 'Object',
  validation => is_instance_of('Zing::Queue'),
};

register {
  name => 'Repo',
  parent => 'Object',
  validation => is_instance_of('Zing::Repo'),
};

register {
  name => 'Ring',
  parent => 'Object',
  validation => is_instance_of('Zing::Ring'),
};

register {
  name => 'Scheduler',
  parent => 'Object',
  validation => is_instance_of('Zing::Scheduler'),
};

register {
  name => 'Search',
  parent => 'Object',
  validation => is_instance_of('Zing::Search'),
};

declare 'Schedule',
  as Tuple([Str(), ArrayRef([Str()]), HashRef()]);

declare 'Scheme',
  as Tuple([Str(), ArrayRef(), Int()]);

register {
  name => 'Savepoint',
  parent => 'Object',
  validation => is_instance_of('Zing::Savepoint'),
};

register {
  name => 'Simple',
  parent => 'Object',
  validation => is_instance_of('Zing::Simple'),
};

register {
  name => 'Single',
  parent => 'Object',
  validation => is_instance_of('Zing::Single'),
};

register {
  name => 'Space',
  parent => 'Object',
  validation => is_instance_of('Data::Object::Space'),
};

register {
  name => 'Spawner',
  parent => 'Object',
  validation => is_instance_of('Zing::Spawner'),
};

register {
  name => 'Store',
  parent => 'Object',
  validation => is_instance_of('Zing::Store'),
};

register {
  name => 'Table',
  parent => 'Object',
  validation => is_instance_of('Zing::Table'),
};

declare 'TableType',
  as Enum([qw(channel domain keyval lookup queue repo table)]);

register {
  name => 'Term',
  parent => 'Object',
  validation => is_instance_of('Zing::Term'),
};

register {
  name => 'Timer',
  parent => 'Object',
  validation => is_instance_of('Zing::Timer'),
};

register {
  name => 'Watcher',
  parent => 'Object',
  validation => is_instance_of('Zing::Watcher'),
};

register {
  name => 'Worker',
  parent => 'Object',
  validation => is_instance_of('Zing::Worker'),
};

register {
  name => 'Zing',
  parent => 'Object',
  validation => is_instance_of('Zing'),
};

1;


=encoding utf8

=head1 NAME

Zing::Types - Type Library

=cut

=head1 ABSTRACT

Type Library

=cut

=head1 SYNOPSIS

  package main;

  use Zing::Types;

  1;

=cut

=head1 DESCRIPTION

This package provides type constraint for the L<Zing> process management
system.

=cut

=head1 LIBRARIES

This package uses type constraints from:

L<Types::Standard>

=cut

=head1 CONSTRAINTS

This package declares the following type constraints:

=cut

=head2 app

  App

This type is defined in the L<Zing::Types> library.

=over 4

=item app parent

  Object

=back

=over 4

=item app composition

  InstanceOf["Zing::App"]

=back

=over 4

=item app example #1

  # given: synopsis

  use Zing::App;

  my $app = Zing::App->new;

=back

=cut

=head2 channel

  Channel

This type is defined in the L<Zing::Types> library.

=over 4

=item channel parent

  Object

=back

=over 4

=item channel composition

  InstanceOf["Zing::Channel"]

=back

=over 4

=item channel example #1

  # given: synopsis

  use Zing::Channel;

  my $chan = Zing::Channel->new(name => 'share');

=back

=cut

=head2 cli

  Cli

This type is defined in the L<Zing::Types> library.

=over 4

=item cli parent

  Object

=back

=over 4

=item cli composition

  InstanceOf["Zing::Cli"]

=back

=over 4

=item cli example #1

  # given: synopsis

  use Zing::Cli;

  my $cli = Zing::Cli->new;

=back

=cut

=head2 cursor

  Cursor

This type is defined in the L<Zing::Types> library.

=over 4

=item cursor parent

  Object

=back

=over 4

=item cursor composition

  InstanceOf["Zing::Cursor"]

=back

=over 4

=item cursor example #1

  # given: synopsis

  use Zing::Cursor;
  use Zing::Lookup;

  my $cursor = Zing::Cursor->new(
    lookup => Zing::Lookup->new(
      name => 'people'
    )
  );

=back

=cut

=head2 daemon

  Daemon

This type is defined in the L<Zing::Types> library.

=over 4

=item daemon parent

  Object

=back

=over 4

=item daemon composition

  InstanceOf["Zing::Daemon"]

=back

=over 4

=item daemon example #1

  # given: synopsis

  use Zing::Cartridge;
  use Zing::Daemon;

  my $daemon = Zing::Daemon->new(
    cartridge => Zing::Cartridge->new(name => 'myapp')
  );

=back

=cut

=head2 data

  Data

This type is defined in the L<Zing::Types> library.

=over 4

=item data parent

  Object

=back

=over 4

=item data composition

  InstanceOf["Zing::Data"]

=back

=over 4

=item data example #1

  # given: synopsis

  use Zing::Data;
  use Zing::Process;

  my $data = Zing::Data->new(name => 'random');

=back

=cut

=head2 domain

  Domain

This type is defined in the L<Zing::Types> library.

=over 4

=item domain parent

  Object

=back

=over 4

=item domain composition

  InstanceOf["Zing::Domain"]

=back

=over 4

=item domain example #1

  # given: synopsis

  use Zing::Domain;

  my $domain = Zing::Domain->new(name => 'exchange');

=back

=cut

=head2 encoder

  Encoder

This type is defined in the L<Zing::Types> library.

=over 4

=item encoder parent

  Object

=back

=over 4

=item encoder composition

  InstanceOf["Zing::Encoder"]

=back

=over 4

=item encoder example #1

  # given: synopsis

  use Zing::Encoder;

  my $encoder = Zing::Encoder->new;

=back

=cut

=head2 entity

  Entity

This type is defined in the L<Zing::Types> library.

=over 4

=item entity parent

  Object

=back

=over 4

=item entity composition

  InstanceOf["Zing::Entity"]

=back

=over 4

=item entity example #1

  # given: synopsis

  use Zing::Entity;

  my $app = Zing::Entity->new;

=back

=cut

=head2 env

  Env

This type is defined in the L<Zing::Types> library.

=over 4

=item env parent

  Object

=back

=over 4

=item env composition

  InstanceOf["Zing::Env"]

=back

=over 4

=item env example #1

  # given: synopsis

  use Zing::Env;

  my $env = Zing::Env->new;

=back

=cut

=head2 error

  Error

This type is defined in the L<Zing::Types> library.

=over 4

=item error parent

  Object

=back

=over 4

=item error composition

  InstanceOf["Zing::Error"]

=back

=over 4

=item error example #1

  # given: synopsis

  use Zing::Error;

  my $error = Zing::Error->new;

=back

=cut

=head2 flow

  Flow

This type is defined in the L<Zing::Types> library.

=over 4

=item flow parent

  Object

=back

=over 4

=item flow composition

  InstanceOf["Zing::Flow"]

=back

=over 4

=item flow example #1

  # given: synopsis

  use Zing::Flow;

  my $flow = Zing::Flow->new(name => 'step_1', code => sub {1});

=back

=cut

=head2 fork

  Fork

This type is defined in the L<Zing::Types> library.

=over 4

=item fork parent

  Object

=back

=over 4

=item fork composition

  InstanceOf["Zing::Fork"]

=back

=over 4

=item fork example #1

  # given: synopsis

  use Zing::Fork;
  use Zing::Process;

  my $scheme = ['MyApp', [], 1];
  my $fork = Zing::Fork->new(scheme => $scheme, parent => Zing::Process->new);

=back

=cut

=head2 id

  ID

This type is defined in the L<Zing::Types> library.

=over 4

=item id composition

  InstanceOf["Zing::ID"]

=back

=over 4

=item id example #1

  # given: synopsis

  use Zing::ID;

  my $id = Zing::ID->new;

=back

=cut

=head2 interupt

  Interupt

This type is defined in the L<Zing::Types> library.

=over 4

=item interupt composition

  Enum[qw(CHLD HUP INT QUIT TERM USR1 USR2)]

=back

=over 4

=item interupt example #1

  # given: synopsis

  'QUIT'

=back

=cut

=head2 kernel

  Kernel

This type is defined in the L<Zing::Types> library.

=over 4

=item kernel parent

  Object

=back

=over 4

=item kernel composition

  InstanceOf["Zing::Kernel"]

=back

=over 4

=item kernel example #1

  # given: synopsis

  use Zing::Kernel;

  my $kernel = Zing::Kernel->new(scheme => ['MyApp', [], 1]);

=back

=cut

=head2 key

  Key

This type is defined in the L<Zing::Types> library.

=over 4

=item key parent

  Str

=back

=over 4

=item key composition

  StrMatch[qr(^[^\:\*]+:[^\:\*]+:[^\:\*]+:[^\:\*]+:[^\:\*]+$)]

=back

=over 4

=item key example #1

  # given: synopsis

  "zing:main:global:repo:random"

=back

=cut

=head2 keyval

  KeyVal

This type is defined in the L<Zing::Types> library.

=over 4

=item keyval parent

  Object

=back

=over 4

=item keyval composition

  InstanceOf["Zing::KeyVal"]

=back

=over 4

=item keyval example #1

  # given: synopsis

  use Zing::KeyVal;

  my $keyval = Zing::KeyVal->new(name => 'notes');

=back

=cut

=head2 logger

  Logger

This type is defined in the L<Zing::Types> library.

=over 4

=item logger parent

  Object

=back

=over 4

=item logger composition

  InstanceOf["Zing::Logger"]

=back

=over 4

=item logger example #1

  # given: synopsis

  use FlightRecorder;

  my $logger = FlightRecorder->new;

=back

=cut

=head2 logic

  Logic

This type is defined in the L<Zing::Types> library.

=over 4

=item logic parent

  Object

=back

=over 4

=item logic composition

  InstanceOf["Zing::Logic"]

=back

=over 4

=item logic example #1

  # given: synopsis

  use Zing::Logic;
  use Zing::Process;

  my $logic = Zing::Logic->new(process => Zing::Process->new);

=back

=cut

=head2 lookup

  Lookup

This type is defined in the L<Zing::Types> library.

=over 4

=item lookup parent

  Object

=back

=over 4

=item lookup composition

  InstanceOf["Zing::Lookup"]

=back

=over 4

=item lookup example #1

  # given: synopsis

  use Zing::Lookup;

  my $lookup = Zing::Lookup->new(
    name => 'users'
  );

=back

=cut

=head2 loop

  Loop

This type is defined in the L<Zing::Types> library.

=over 4

=item loop parent

  Object

=back

=over 4

=item loop composition

  InstanceOf["Zing::Loop"]

=back

=over 4

=item loop example #1

  # given: synopsis

  use Zing::Flow;
  use Zing::Loop;

  my $loop = Zing::Loop->new(
    flow => Zing::Flow->new(name => 'init', code => sub {1})
  );

=back

=cut

=head2 mailbox

  Mailbox

This type is defined in the L<Zing::Types> library.

=over 4

=item mailbox parent

  Object

=back

=over 4

=item mailbox composition

  InstanceOf["Zing::Mailbox"]

=back

=over 4

=item mailbox example #1

  # given: synopsis

  use Zing::Mailbox;
  use Zing::Process;

  my $mailbox = Zing::Mailbox->new(name => 'shared');

=back

=cut

=head2 meta

  Meta

This type is defined in the L<Zing::Types> library.

=over 4

=item meta parent

  Object

=back

=over 4

=item meta composition

  InstanceOf["Zing::Meta"]

=back

=over 4

=item meta example #1

  # given: synopsis

  use Zing::Meta;

  my $meta = Zing::Meta->new(name => '$process');

=back

=cut

=head2 name

  Name

This type is defined in the L<Zing::Types> library.

=over 4

=item name parent

  Str

=back

=over 4

=item name composition

  StrMatch[qr(^[^\:\*]+$)]

=back

=over 4

=item name example #1

  # given: synopsis

  "main"

=back

=cut

=head2 poll

  Poll

This type is defined in the L<Zing::Types> library.

=over 4

=item poll parent

  Object

=back

=over 4

=item poll composition

  InstanceOf["Zing::Poll"]

=back

=over 4

=item poll example #1

  # given: synopsis

  use Zing::Poll;
  use Zing::KeyVal;

  my $keyval = Zing::KeyVal->new(name => 'notes');
  my $poll = Zing::Poll->new(name => 'last-week', repo => $keyval);

=back

=cut

=head2 process

  Process

This type is defined in the L<Zing::Types> library.

=over 4

=item process parent

  Object

=back

=over 4

=item process composition

  InstanceOf["Zing::Process"]

=back

=over 4

=item process example #1

  # given: synopsis

  use Zing::Process;

  my $process = Zing::Process->new;

=back

=cut

=head2 pubsub

  PubSub

This type is defined in the L<Zing::Types> library.

=over 4

=item pubsub parent

  Object

=back

=over 4

=item pubsub composition

  InstanceOf["Zing::PubSub"]

=back

=over 4

=item pubsub example #1

  # given: synopsis

  use Zing::PubSub;

  my $pubsub = Zing::PubSub->new(name => 'tasks');

=back

=cut

=head2 queue

  Queue

This type is defined in the L<Zing::Types> library.

=over 4

=item queue parent

  Object

=back

=over 4

=item queue composition

  InstanceOf["Zing::Queue"]

=back

=over 4

=item queue example #1

  # given: synopsis

  use Zing::Queue;

  my $queue = Zing::Queue->new(name => 'tasks');

=back

=cut

=head2 repo

  Repo

This type is defined in the L<Zing::Types> library.

=over 4

=item repo parent

  Object

=back

=over 4

=item repo composition

  InstanceOf["Zing::Repo"]

=back

=over 4

=item repo example #1

  # given: synopsis

  use Zing::Repo;

  my $repo = Zing::Repo->new(name => 'repo');

=back

=cut

=head2 schedule

  Schedule

This type is defined in the L<Zing::Types> library.

=over 4

=item schedule composition

  Tuple[Str, ArrayRef[Str], HashRef]

=back

=over 4

=item schedule example #1

  # given: synopsis

  # at 00:00 on day-of-month 1 in january

  ['0 0 1 1 *', ['task_queue'], { task => 'execute' }];

=back

=over 4

=item schedule example #2

  # given: synopsis

  # at 00:00 on saturday

  ['0 0 * * SAT', ['task_queue'], { task => 'execute' }];

=back

=over 4

=item schedule example #3

  # given: synopsis

  # at minute 0 (hourly)

  ['0 * * * *', ['task_queue'], { task => 'execute' }];

=back

=cut

=head2 scheme

  Scheme

This type is defined in the L<Zing::Types> library.

=over 4

=item scheme composition

  Tuple[Str, ArrayRef, Int]

=back

=over 4

=item scheme example #1

  # given: synopsis

  ['MyApp', [], 1_000];

=back

=cut

=head2 search

  Search

This type is defined in the L<Zing::Types> library.

=over 4

=item search parent

  Object

=back

=over 4

=item search composition

  InstanceOf["Zing::Search"]

=back

=over 4

=item search example #1

  # given: synopsis

  use Zing::Search;

  my $search = Zing::Search->new;

=back

=cut

=head2 space

  Space

This type is defined in the L<Zing::Types> library.

=over 4

=item space parent

  Object

=back

=over 4

=item space composition

  InstanceOf["Zing::Space"]

=back

=over 4

=item space example #1

  # given: synopsis

  use Data::Object::Space;

  Data::Object::Space->new('MyApp');

=back

=cut

=head2 store

  Store

This type is defined in the L<Zing::Types> library.

=over 4

=item store parent

  Object

=back

=over 4

=item store composition

  InstanceOf["Zing::Store"]

=back

=over 4

=item store example #1

  # given: synopsis

  use Zing::Store;

  my $store = Zing::Store->new;

=back

=cut

=head2 table

  Table

This type is defined in the L<Zing::Types> library.

=over 4

=item table parent

  Object

=back

=over 4

=item table composition

  InstanceOf["Zing::Table"]

=back

=over 4

=item table example #1

  # given: synopsis

  use Zing::Table;

  my $table = Zing::Table->new(
    name => 'users'
  );

=back

=cut

=head2 term

  Term

This type is defined in the L<Zing::Types> library.

=over 4

=item term parent

  Object

=back

=over 4

=item term composition

  InstanceOf["Zing::Term"]

=back

=over 4

=item term example #1

  # given: synopsis

  bless {}, 'Zing::Term';

=back

=cut

=head2 watcher

  Watcher

This type is defined in the L<Zing::Types> library.

=over 4

=item watcher parent

  Object

=back

=over 4

=item watcher composition

  InstanceOf["Zing::Watcher"]

=back

=over 4

=item watcher example #1

  # given: synopsis

  bless {}, 'Zing::Watcher';

=back

=cut

=head2 worker

  Worker

This type is defined in the L<Zing::Types> library.

=over 4

=item worker parent

  Object

=back

=over 4

=item worker composition

  InstanceOf["Zing::Worker"]

=back

=over 4

=item worker example #1

  # given: synopsis

  bless {}, 'Zing::Worker';

=back

=cut

=head2 zing

  Zing

This type is defined in the L<Zing::Types> library.

=over 4

=item zing parent

  Object

=back

=over 4

=item zing composition

  InstanceOf["Zing::Zing"]

=back

=over 4

=item zing example #1

  # given: synopsis

  use Zing;

  my $zing = Zing->new(scheme => ['MyApp', [], 1]);

=back

=cut

=head1 AUTHOR

Al Newkirk, C<awncorp@cpan.org>

=head1 LICENSE

Copyright (C) 2011-2019, Al Newkirk, et al.

This is free software; you can redistribute it and/or modify it under the terms
of the The Apache License, Version 2.0, as elucidated in the L<"license
file"|https://github.com/cpanery/zing/blob/master/LICENSE>.

=head1 PROJECT

L<Wiki|https://github.com/cpanery/zing/wiki>

L<Project|https://github.com/cpanery/zing>

L<Initiatives|https://github.com/cpanery/zing/projects>

L<Milestones|https://github.com/cpanery/zing/milestones>

L<Contributing|https://github.com/cpanery/zing/blob/master/CONTRIBUTE.md>

L<Issues|https://github.com/cpanery/zing/issues>

=cut
