package Venus;

use 5.018;

use strict;
use warnings;

# VERSION

our $VERSION = '4.15';

# AUTHORITY

our $AUTHORITY = 'cpan:AWNCORP';

# IMPORTS

sub import {
  my ($self, @args) = @_;

  my $target = caller;

  no strict 'refs';

  my %exports = (
    args => 1,
    array => 1,
    arrayref => 1,
    assert => 1,
    async => 1,
    atom => 1,
    await => 1,
    bool => 1,
    box => 1,
    call => 1,
    cast => 1,
    catch => 1,
    caught => 1,
    chain => 1,
    check => 1,
    clargs => 1,
    cli => 1,
    clone => 1,
    code => 1,
    config => 1,
    container => 1,
    cop => 1,
    data => 1,
    date => 1,
    docs => 1,
    enum => 1,
    error => 1,
    false => 1,
    fault => 1,
    float => 1,
    future => 1,
    gather => 1,
    hash => 1,
    hashref => 1,
    is_bool => 1,
    is_false => 1,
    is_true => 1,
    json => 1,
    list => 1,
    load => 1,
    log => 1,
    make => 1,
    match => 1,
    merge => 1,
    meta => 1,
    name => 1,
    number => 1,
    opts => 1,
    pairs => 1,
    path => 1,
    perl => 1,
    process => 1,
    proto => 1,
    puts => 1,
    raise => 1,
    random => 1,
    range => 1,
    regexp => 1,
    replace => 1,
    render => 1,
    resolve => 1,
    roll => 1,
    search => 1,
    set => 1,
    space => 1,
    schema => 1,
    string => 1,
    syscall => 1,
    template => 1,
    test => 1,
    text => 1,
    then => 1,
    throw => 1,
    true => 1,
    try => 1,
    type => 1,
    unpack => 1,
    vars => 1,
    venus => 1,
    work => 1,
    wrap => 1,
    yaml => 1,
  );

  @args = grep defined && !ref && /^[A-Za-z]/ && $exports{$_}, @args;

  my %seen;
  for my $name (grep !$seen{$_}++, @args, 'true', 'false') {
    *{"${target}::${name}"} = $self->can($name) if !$target->can($name);
  }

  return $self;
}

# HOOKS

sub _qx {
  my (@args) = @_;
  local $| = 1;
  local $SIG{__WARN__} = sub {};
  (do{local $_ = qx(@{[@args]}); chomp if $_; $_}, $?, ($? >> 8))
}

# FUNCTIONS

sub args ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Args;

  if (!$code) {
    return Venus::Args->new($data);
  }

  return Venus::Args->new($data)->$code(@args);
}

sub array ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Array;

  if (!$code) {
    return Venus::Array->new($data);
  }

  return Venus::Array->new($data)->$code(@args);
}

sub arrayref (@) {
  my (@args) = @_;

  return @args > 1
    ? ([@args])
    : ((ref $args[0] eq 'ARRAY') ? ($args[0]) : ([@args]));
}

sub assert ($$) {
  my ($data, $expr) = @_;

  require Venus::Assert;

  my $assert = Venus::Assert->new->expression($expr);

  return $assert->validate($data);
}

sub async ($) {
  my ($code) = @_;

  require Venus::Process;

  return Venus::Process->new->future($code);
}

sub atom (;$) {
  my ($data) = @_;

  require Venus::Atom;

  return Venus::Atom->new($data);
}

sub await ($;$) {
  my ($future, $timeout) = @_;

  require Venus::Future;

  return $future->wait($timeout);
}

sub bool (;$) {
  my ($data) = @_;

  require Venus::Boolean;

  return Venus::Boolean->new($data);
}

sub box ($) {
  my ($data) = @_;

  require Venus::Box;

  my $box = Venus::Box->new($data);

  return $box;
}

sub call (@) {
  my ($data, @args) = @_;
  my $next = @args;
  if ($next && UNIVERSAL::isa($data, 'CODE')) {
    return $data->(@args);
  }
  my $code = shift(@args);
  if ($next && Scalar::Util::blessed($data)) {
    return $data->$code(@args) if UNIVERSAL::can($data, $code)
      || UNIVERSAL::can($data, 'AUTOLOAD');
    $next = 0;
  }
  if ($next && ref($data) eq 'SCALAR') {
    return $$data->$code(@args) if UNIVERSAL::can(load($$data)->package, $code);
    $next = 0;
  }
  if ($next && UNIVERSAL::can(load($data)->package, $code)) {
    no strict 'refs';
    return *{"${data}::${code}"}{"CODE"} ?
      &{"${data}::${code}"}(@args) : $data->$code(@args[1..$#args]);
  }
  if ($next && UNIVERSAL::can($data, 'AUTOLOAD')) {
    no strict 'refs';
    return &{"${data}::${code}"}(@args);
  }
  fault("Exception! call(@{[join(', ', map qq('$_'), @_)]}) failed.");
}

sub cast (;$$) {
  my ($data, $into) = (@_ ? (@_) : ($_));

  require Venus::Type;

  my $type = Venus::Type->new($data);

  return $into ? $type->cast($into) : $type->deduce;
}

sub catch (&) {
  my ($data) = @_;

  my $error;

  require Venus::Try;

  my @result = Venus::Try->new($data)->error(\$error)->result;

  return wantarray ? ($error ? ($error, undef) : ($error, @result)) : $error;
}

sub caught ($$;&) {
  my ($data, $type, $code) = @_;

  ($type, my($name)) = @$type if ref $type eq 'ARRAY';

  my $is_true = $data
    && UNIVERSAL::isa($data, $type)
    && UNIVERSAL::isa($data, 'Venus::Error')
    && (
      $data->name
        ? ($name ? $data->of($name) : true())
        : (!$name ? true() : false())
    );

  if ($is_true) {
    local $_ = $data;

    return $code ? $code->($data) : $data;
  }
  else {
    return undef;
  }
}

sub chain {
  my ($data, @args) = @_;

  return if !$data;

  for my $next (map +(ref($_) eq 'ARRAY' ? $_ : [$_]), @args) {
    $data = call($data, @$next);
  }

  return $data;
}

sub check ($$) {
  my ($data, $expr) = @_;

  require Venus::Assert;

  return Venus::Assert->new->expression($expr)->valid($data);
}

sub clargs (@) {
  my (@args) = @_;

  my ($argv, $specs) = (@args > 1)
    ? (map arrayref($_), @args)
    : ([@ARGV], arrayref(@args));

  return (
    args($argv), opts($argv, 'reparse', $specs), vars({}),
  );
}

sub cli (;$) {
  my ($data) = @_;

  require Venus::Cli;

  my $cli = Venus::Cli->new($data || [@ARGV]);

  return $cli;
}

sub clone ($) {
  my ($data) = @_;

  require Storable;

  return Storable::dclone($data);
}

sub code ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Code;

  if (!$code) {
    return Venus::Code->new($data);
  }

  return Venus::Code->new($data)->$code(@args);
}

sub config ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Config;

  if (!$code) {
    return Venus::Config->new($data);
  }

  return Venus::Config->new($data)->$code(@args);
}

sub container ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Container;

  if (!$code) {
    return Venus::Container->new($data);
  }

  return Venus::Container->new($data)->$code(@args);
}

sub cop (@) {
  my ($data, @args) = @_;

  require Scalar::Util;

  ($data, $args[0]) = map {
    ref eq 'SCALAR' ? $$_ : Scalar::Util::blessed($_) ? ref($_) : $_
  } ($data, $args[0]);

  return space("$data")->cop(@args);
}

sub data ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Data;

  if (!$code) {
    return Venus::Data->new($data);
  }

  return Venus::Data->new($data)->$code(@args);
}

sub date ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Date;

  if (!$code) {
    return Venus::Date->new($data);
  }

  return Venus::Date->new($data)->$code(@args);
}

sub docs {
  my (@args) = @_;

  my $file = (grep -f, (caller(0))[1], $0)[0];

  my $data = data($file);

  return $data->docs->string(@args > 1 ? @args : (undef, @args));
}

sub enum {
  my (@data) = @_;

  require Venus::Enum;

  return Venus::Enum->new(@data);
}

sub error (;$) {
  my ($data) = @_;

  $data //= {};
  $data->{context} //= (caller(1))[3];

  require Venus::Throw;

  return Venus::Throw->new->error($data);
}

sub false () {

  require Venus::False;

  return Venus::False->value;
}

sub fault (;$) {
  my ($data) = @_;

  require Venus::Fault;

  return Venus::Fault->new($data)->throw;
}

sub float ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Float;

  if (!$code) {
    return Venus::Float->new($data);
  }

  return Venus::Float->new($data)->$code(@args);
}

sub future {
  my (@data) = @_;

  require Venus::Future;

  return Venus::Future->new(@data);
}

sub gather ($;&) {
  my ($data, $code) = @_;

  require Venus::Gather;

  my $match = Venus::Gather->new($data);

  return $match if !$code;

  local $_ = $match;

  my $returned = $code->($match, $data);

  $match->data($returned) if ref $returned eq 'HASH';

  return $match->result;
}

sub hash ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Hash;

  if (!$code) {
    return Venus::Hash->new($data);
  }

  return Venus::Hash->new($data)->$code(@args);
}

sub hashref (@) {
  my (@args) = @_;

  return @args > 1
    ? ({(scalar(@args) % 2) ? (@args, undef) : @args})
    : ((ref $args[0] eq 'HASH')
    ? ($args[0])
    : ({(scalar(@args) % 2) ? (@args, undef) : @args}));
}

sub is_bool ($) {
  my ($data) = @_;

  return type($data, 'coded', 'BOOLEAN') ? true() : false();
}

sub is_false ($) {
  my ($data) = @_;

  require Venus::Boolean;

  return Venus::Boolean->new($data)->is_false;
}

sub is_true ($) {
  my ($data) = @_;

  require Venus::Boolean;

  return Venus::Boolean->new($data)->is_true;
}

sub json (;$$) {
  my ($code, $data) = @_;

  require Venus::Json;

  if (!$code) {
    return Venus::Json->new;
  }

  if (lc($code) eq 'decode') {
    return Venus::Json->new->decode($data);
  }

  if (lc($code) eq 'encode') {
    return Venus::Json->new(value => $data)->encode;
  }

  return fault(qq(Invalid "json" action "$code"));
}

sub list (@) {
  my (@args) = @_;

  return map {defined $_ ? (ref eq 'ARRAY' ? (@{$_}) : ($_)) : ($_)} @args;
}

sub load ($) {
  my ($data) = @_;

  return space($data)->do('load');
}

sub log (@) {
  my (@args) = @_;

  state $codes = {
    debug => 'debug',
    error => 'error',
    fatal => 'fatal',
    info => 'info',
    trace => 'trace',
    warn => 'warn',
  };

  unshift @args, 'debug' if @args && !$codes->{$args[0]};

  require Venus::Log;

  my $log = Venus::Log->new($ENV{VENUS_LOG_LEVEL});

  return $log if !@args;

  my $code = shift @args;

  return $log->$code(@args);
}

sub make (@) {

  return if !@_;

  return call($_[0], 'new', @_);
}

sub match ($;&) {
  my ($data, $code) = @_;

  require Venus::Match;

  my $match = Venus::Match->new($data);

  return $match if !$code;

  local $_ = $match;

  my $returned = $code->($match, $data);

  $match->data($returned) if ref $returned eq 'HASH';

  return $match->result;
}

sub merge {
  my ($lvalue, @rvalues) = @_;

  if (!$lvalue) {
    return {};
  }

  my $rvalue;

  if (@rvalues > 1) {
    my $result = $lvalue;
    $result = merge($result, $_) for @rvalues;
    return $result;
  }
  else {
    $rvalue = $rvalues[0];
  }

  if (!$rvalue) {
    return $lvalue;
  }

  if (ref $lvalue eq 'HASH') {
    if (ref $rvalue eq 'HASH') {
      for my $index (keys %{$rvalue}) {
        my $lprop = $lvalue->{$index};
        my $rprop = $rvalue->{$index};
        $lvalue->{$index} = (
            ((ref($lprop) eq 'HASH') && (ref($rprop) eq 'HASH'))
            || ((ref($lprop) eq 'ARRAY') && (ref($rprop) eq 'ARRAY'))
          )
          ? merge($lprop, $rprop)
          : $rprop;
      }
    }
    else {
      $lvalue = $rvalue;
    }
  }

  if (ref $lvalue eq 'ARRAY') {
    if (ref $rvalue eq 'ARRAY') {
      for my $index (0..$#{$rvalue}) {
        my $lprop = $lvalue->[$index];
        my $rprop = $rvalue->[$index];
        $lvalue->[$index] = (
            ((ref($lprop) eq 'HASH') && (ref($rprop) eq 'HASH'))
            || ((ref($lprop) eq 'ARRAY') && (ref($rprop) eq 'ARRAY'))
          )
          ? merge($lprop, $rprop)
          : $rprop;
      }
    }
    else {
      $lvalue = $rvalue;
    }
  }

  return $lvalue;
}

sub meta ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Meta;

  if (!$code) {
    return Venus::Meta->new(name => $data);
  }

  return Venus::Meta->new(name => $data)->$code(@args);
}

sub name ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Name;

  if (!$code) {
    return Venus::Name->new($data);
  }

  return Venus::Name->new($data)->$code(@args);
}

sub number ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Number;

  if (!$code) {
    return Venus::Number->new($data);
  }

  return Venus::Number->new($data)->$code(@args);
}

sub opts ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Opts;

  if (!$code) {
    return Venus::Opts->new($data);
  }

  return Venus::Opts->new($data)->$code(@args);
}

sub pairs (@) {
  my ($args) = @_;

  my $result = defined $args
    ? (
    ref $args eq 'ARRAY'
    ? ([map {[$_, $args->[$_]]} 0..$#{$args}])
    : (ref $args eq 'HASH' ? ([map {[$_, $args->{$_}]} sort keys %{$args}]) : ([])))
    : [];

  return wantarray ? @{$result} : $result;
}

sub path ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Path;

  if (!$code) {
    return Venus::Path->new($data);
  }

  return Venus::Path->new($data)->$code(@args);
}

sub perl (;$$) {
  my ($code, $data) = @_;

  require Venus::Dump;

  if (!$code) {
    return Venus::Dump->new;
  }

  if (lc($code) eq 'decode') {
    return Venus::Dump->new->decode($data);
  }

  if (lc($code) eq 'encode') {
    return Venus::Dump->new(value => $data)->encode;
  }

  return fault(qq(Invalid "perl" action "$code"));
}

sub process (;$@) {
  my ($code, @args) = @_;

  require Venus::Process;

  if (!$code) {
    return Venus::Process->new;
  }

  return Venus::Process->new->$code(@args);
}

sub proto ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Prototype;

  if (!$code) {
    return Venus::Prototype->new($data);
  }

  return Venus::Prototype->new($data)->$code(@args);
}

sub puts ($;@) {
  my ($data, @args) = @_;

  $data = cast($data);

  my $result = [];

  if ($data->isa('Venus::Hash')) {
    $result = $data->puts(@args);
  }
  elsif ($data->isa('Venus::Array')) {
    $result = $data->puts(@args);
  }

  return wantarray ? (@{$result}) : $result;
}

sub raise ($;$) {
  my ($self, $data) = @_;

  ($self, my $parent) = (@$self) if (ref($self) eq 'ARRAY');

  $data //= {};
  $data->{context} //= (caller(1))[3];

  $parent = 'Venus::Error' if !$parent;

  require Venus::Throw;

  return Venus::Throw->new(package => $self, parent => $parent)->error($data);
}

sub random (;$@) {
  my ($code, @args) = @_;

  require Venus::Random;

  state $random = Venus::Random->new;

  if (!$code) {
    return $random;
  }

  return $random->$code(@args);
}

sub range ($;@) {
  my ($data, @args) = @_;

  return array($data, 'range', @args);
}

sub regexp ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Regexp;

  if (!$code) {
    return Venus::Regexp->new($data);
  }

  return Venus::Regexp->new($data)->$code(@args);
}

sub render ($;$) {
  my ($data, $args) = @_;

  return template($data, 'render', undef, $args || {});
}

sub replace ($;$@) {
  my ($data, $code, @args) = @_;

  my @keys = qw(
    string
    regexp
    substr
  );

  my @data = (ref $data eq 'ARRAY' ? (map +(shift(@keys), $_), @{$data}) : $data);

  require Venus::Replace;

  if (!$code) {
    return Venus::Replace->new(@data);
  }

  return Venus::Replace->new(@data)->$code(@args);
}

sub resolve ($;@) {
  my ($data, @args) = @_;

  return container($data, 'resolve', @args);
}

sub roll (@) {

  return (@_[1,0,2..$#_]);
}

sub schema ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Schema;

  if (!$code) {
    return Venus::Schema->new($data);
  }

  return Venus::Schema->new($data)->$code(@args);
}

sub search ($;$@) {
  my ($data, $code, @args) = @_;

  my @keys = qw(
    string
    regexp
  );

  my @data = (ref $data eq 'ARRAY' ? (map +(shift(@keys), $_), @{$data}) : $data);

  require Venus::Search;

  if (!$code) {
    return Venus::Search->new(@data);
  }

  return Venus::Search->new(@data)->$code(@args);
}

sub set ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Set;

  if (!$code) {
    return Venus::Set->new($data);
  }

  return Venus::Set->new($data)->$code(@args);
}

sub space ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Space;

  if (!$code) {
    return Venus::Space->new($data);
  }

  return Venus::Space->new($data)->$code(@args);
}

sub string ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::String;

  if (!$code) {
    return Venus::String->new($data);
  }

  return Venus::String->new($data)->$code(@args);
}

sub syscall ($;@) {
  my (@args) = @_;

  require Venus::Os;

  for (my $i = 0; $i < @args; $i++) {
    if ($args[$i] =~ /^\|+$/) {
      next;
    }
    if ($args[$i] =~ /^\&+$/) {
      next;
    }
    if ($args[$i] =~ /^\w+$/) {
      next;
    }
    if ($args[$i] =~ /^[<>]+$/) {
      next;
    }
    if ($args[$i] =~ /^\d[<>&]+\d?$/) {
      next;
    }
    if ($args[$i] =~ /\$[A-Z]\w+/) {
      next;
    }
    if ($args[$i] =~ /^\$\((.*)\)$/) {
      next;
    }
    $args[$i] = Venus::Os->quote($args[$i]);
  }

  my ($data, $exit, $code) = (_qx(@args));

  return wantarray ? ($data, $code) : (($exit == 0) ? true() : false());
}

sub template ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Template;

  if (!$code) {
    return Venus::Template->new($data);
  }

  return Venus::Template->new($data)->$code(@args);
}

sub test ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Test;

  if (!$code) {
    return Venus::Test->new($data);
  }

  return Venus::Test->new($data)->$code(@args);
}

sub text {
  my (@args) = @_;

  my $file = (grep -f, (caller(0))[1], $0)[0];

  my $data = data($file);

  return $data->text->string(@args > 1 ? @args : (undef, @args));
}

sub then (@) {

  return ($_[0], call(@_));
}

sub throw ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Throw;

  my $throw = Venus::Throw->new(context => (caller(1))[3])->do(
    frame => 1,
  );

  if (ref $data ne 'HASH') {
    $throw->package($data) if $data;
  }
  else {
    if (exists $data->{as}) {
      $throw->as($data->{as});
    }
    if (exists $data->{capture}) {
      $throw->capture(@{$data->{capture}});
    }
    if (exists $data->{context}) {
      $throw->context($data->{context});
    }
    if (exists $data->{error}) {
      $throw->error($data->{error});
    }
    if (exists $data->{frame}) {
      $throw->frame($data->{frame});
    }
    if (exists $data->{message}) {
      $throw->message($data->{message});
    }
    if (exists $data->{name}) {
      $throw->name($data->{name});
    }
    if (exists $data->{package}) {
      $throw->package($data->{package});
    }
    if (exists $data->{parent}) {
      $throw->parent($data->{parent});
    }
    if (exists $data->{stash}) {
      $throw->stash($_, $data->{stash}->{$_}) for keys %{$data->{stash}};
    }
    if (exists $data->{on}) {
      $throw->on($data->{on});
    }
  }

  return $throw if !$code;

  return $throw->$code(@args);
}

sub true () {

  require Venus::True;

  return Venus::True->value;
}

sub try ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Try;

  if (!$code) {
    return Venus::Try->new($data);
  }

  return Venus::Try->new($data)->$code(@args);
}

sub type ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Type;

  if (!$code) {
    return Venus::Type->new($data);
  }

  return Venus::Type->new($data)->$code(@args);
}

sub unpack (@) {
  my (@args) = @_;

  require Venus::Unpack;

  return Venus::Unpack->new->do('args', @args)->all;
}

sub vars ($;$@) {
  my ($data, $code, @args) = @_;

  require Venus::Vars;

  if (!$code) {
    return Venus::Vars->new($data);
  }

  return Venus::Vars->new($data)->$code(@args);
}

sub venus ($;@) {
  my ($name, @args) = @_;

  @args = ('new') if !@args;

  return chain(\space(join('/', 'Venus', $name))->package, @args);
}

sub work ($) {
  my ($data) = @_;

  require Venus::Process;

  return Venus::Process->new->do('work', $data);
}

sub wrap ($;$) {
  my ($data, $name) = @_;

  return if !@_;

  my $moniker = $name // $data =~ s/\W//gr;
  my $caller = caller(0);

  no strict 'refs';
  no warnings 'redefine';

  return *{"${caller}::${moniker}"} = sub {@_ ? make($data, @_) : $data};
}

sub yaml (;$$) {
  my ($code, $data) = @_;

  require Venus::Yaml;

  if (!$code) {
    return Venus::Yaml->new;
  }

  if (lc($code) eq 'decode') {
    return Venus::Yaml->new->decode($data);
  }

  if (lc($code) eq 'encode') {
    return Venus::Yaml->new(value => $data)->encode;
  }

  return fault(qq(Invalid "yaml" action "$code"));
}

1;


=head1 NAME

Venus - Standard Library

=cut

=head1 ABSTRACT

Standard Library for Perl 5

=cut

=head1 VERSION

4.15

=cut

=head1 SYNOPSIS

  package main;

  use Venus 'catch', 'error', 'raise';

  # error handling
  my ($error, $result) = catch {
    error;
  };

  # boolean keywords
  if ($result) {
    error;
  }

  # raise exceptions
  if ($result) {
    raise 'MyApp::Error';
  }

  # boolean keywords, and more!
  true ne false;

=cut

=head1 DESCRIPTION

This library provides an object-orientation framework and extendible standard
library for Perl 5 with classes which wrap most native Perl data types. Venus
has a simple modular architecture, robust library of classes, methods, and
roles, supports pure-Perl autoboxing, advanced exception handling, "true" and
"false" functions, package introspection, command-line options parsing, and
more. This package will always automatically exports C<true> and C<false>
keyword functions (unless existing routines of the same name already exist in
the calling package or its parents), otherwise exports keyword functions as
requested at import. This library requires Perl C<5.18+>.

=head1 CAPABILITIES

The following is a short list of capabilities:

=over 4

=item *

Perl 5.18.0+

=item *

Zero Dependencies

=item *

Fast Object-Orientation

=item *

Robust Standard Library

=item *

Intuitive Value Classes

=item *

Pure Perl Autoboxing

=item *

Convenient Utility Classes

=item *

Simple Package Reflection

=item *

Flexible Exception Handling

=item *

Composable Standards

=item *

Pluggable (no monkeypatching)

=item *

Proxyable Methods

=item *

Type Assertions

=item *

Type Coercions

=item *

Value Casting

=item *

Boolean Values

=item *

Complete Documentation

=item *

Complete Test Coverage

=back

=cut

=head1 FUNCTIONS

This package provides the following functions:

=cut

=head2 args

  args(arrayref $value, string | coderef $code, any @args) (any)

The args function builds and returns a L<Venus::Args> object, or dispatches to
the coderef or method provided.

I<Since C<3.10>>

=over 4

=item args example 1

  package main;

  use Venus 'args';

  my $args = args ['--resource', 'users'];

  # bless({...}, 'Venus::Args')

=back

=over 4

=item args example 2

  package main;

  use Venus 'args';

  my $args = args ['--resource', 'users'], 'indexed';

  # {0 => '--resource', 1 => 'users'}

=back

=cut

=head2 array

  array(arrayref | hashref $value, string | coderef $code, any @args) (any)

The array function builds and returns a L<Venus::Array> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item array example 1

  package main;

  use Venus 'array';

  my $array = array [];

  # bless({...}, 'Venus::Array')

=back

=over 4

=item array example 2

  package main;

  use Venus 'array';

  my $array = array [1..4], 'push', 5..9;

  # [1..9]

=back

=cut

=head2 arrayref

  arrayref(any @args) (arrayref)

The arrayref function takes a list of arguments and returns a arrayref.

I<Since C<3.10>>

=over 4

=item arrayref example 1

  package main;

  use Venus 'arrayref';

  my $arrayref = arrayref(content => 'example');

  # [content => "example"]

=back

=over 4

=item arrayref example 2

  package main;

  use Venus 'arrayref';

  my $arrayref = arrayref([content => 'example']);

  # [content => "example"]

=back

=over 4

=item arrayref example 3

  package main;

  use Venus 'arrayref';

  my $arrayref = arrayref('content');

  # ['content']

=back

=cut

=head2 assert

  assert(any $data, string $expr) (any)

The assert function builds a L<Venus::Assert> object and returns the result of
a L<Venus::Assert/validate> operation.

I<Since C<2.40>>

=over 4

=item assert example 1

  package main;

  use Venus 'assert';

  my $assert = assert(1234567890, 'number');

  # 1234567890

=back

=over 4

=item assert example 2

  package main;

  use Venus 'assert';

  my $assert = assert(1234567890, 'float');

  # Exception! (isa Venus::Check::Error)

=back

=over 4

=item assert example 3

  package main;

  use Venus 'assert';

  my $assert = assert(1234567890, 'number | float');

  # 1234567890

=back

=cut

=head2 async

  async(coderef $code, any @args) (Venus::Future)

The async function accepts a callback and executes it asynchronously via
L<Venus::Process/future>. This function returns a L<Venus::Future> object which
can be fulfilled via L<Venus::Future/wait>.

I<Since C<3.40>>

=over 4

=item async example 1

  package main;

  use Venus 'async';

  my $async = async sub{
    'done'
  };

  # bless({...}, 'Venus::Future')

=back

=cut

=head2 atom

  atom(any $value) (Venus::Atom)

The atom function builds and returns a L<Venus::Atom> object.

I<Since C<3.55>>

=over 4

=item atom example 1

  package main;

  use Venus 'atom';

  my $atom = atom 'super-admin';

  # bless({scope => sub{...}}, "Venus::Atom")

  # "$atom"

  # "super-admin"

=back

=cut

=head2 await

  await(Venus::Future $future, number $timeout) (any)

The await function accepts a L<Venus::Future> object and eventually returns a
value (or values) for it. The value(s) returned are the return values or
emissions from the asychronous callback executed with L</async> which produced
the process object.

I<Since C<3.40>>

=over 4

=item await example 1

  package main;

  use Venus 'async', 'await';

  my $process;

  my $async = async sub{
    return 'done';
  };

  my $await = await $async;

  # bless(..., "Venus::Future")

=back

=cut

=head2 bool

  bool(any $value) (Venus::Boolean)

The bool function builds and returns a L<Venus::Boolean> object.

I<Since C<2.55>>

=over 4

=item bool example 1

  package main;

  use Venus 'bool';

  my $bool = bool;

  # bless({value => 0}, 'Venus::Boolean')

=back

=over 4

=item bool example 2

  package main;

  use Venus 'bool';

  my $bool = bool 1_000;

  # bless({value => 1}, 'Venus::Boolean')

=back

=cut

=head2 box

  box(any $data) (Venus::Box)

The box function returns a L<Venus::Box> object for the argument provided.

I<Since C<2.32>>

=over 4

=item box example 1

  package main;

  use Venus 'box';

  my $box = box({});

  # bless({value => bless({value => {}}, 'Venus::Hash')}, 'Venus::Box')

=back

=over 4

=item box example 2

  package main;

  use Venus 'box';

  my $box = box([]);

  # bless({value => bless({value => []}, 'Venus::Array')}, 'Venus::Box')

=back

=cut

=head2 call

  call(string | object | coderef $data, any @args) (any)

The call function dispatches function and method calls to a package and returns
the result.

I<Since C<2.32>>

=over 4

=item call example 1

  package main;

  use Venus 'call';

  require Digest::SHA;

  my $result = call(\'Digest::SHA', 'new');

  # bless(do{\(my $o = '...')}, 'digest::sha')

=back

=over 4

=item call example 2

  package main;

  use Venus 'call';

  require Digest::SHA;

  my $result = call('Digest::SHA', 'sha1_hex');

  # "da39a3ee5e6b4b0d3255bfef95601890afd80709"

=back

=over 4

=item call example 3

  package main;

  use Venus 'call';

  require Venus::Hash;

  my $result = call(sub{'Venus::Hash'->new(@_)}, {1..4});

  # bless({value => {1..4}}, 'Venus::Hash')

=back

=over 4

=item call example 4

  package main;

  use Venus 'call';

  require Venus::Box;

  my $result = call(Venus::Box->new(value => {}), 'merge', {1..4});

  # bless({value => bless({value => {1..4}}, 'Venus::Hash')}, 'Venus::Box')

=back

=cut

=head2 cast

  cast(any $data, string $type) (object)

The cast function returns the argument provided as an object, promoting native
Perl data types to data type objects. The optional second argument can be the
name of the type for the object to cast to explicitly.

I<Since C<1.40>>

=over 4

=item cast example 1

  package main;

  use Venus 'cast';

  my $undef = cast;

  # bless({value => undef}, "Venus::Undef")

=back

=over 4

=item cast example 2

  package main;

  use Venus 'cast';

  my @booleans = map cast, true, false;

  # (bless({value => 1}, "Venus::Boolean"), bless({value => 0}, "Venus::Boolean"))

=back

=over 4

=item cast example 3

  package main;

  use Venus 'cast';

  my $example = cast bless({}, "Example");

  # bless({value => 1}, "Example")

=back

=over 4

=item cast example 4

  package main;

  use Venus 'cast';

  my $float = cast 1.23;

  # bless({value => "1.23"}, "Venus::Float")

=back

=cut

=head2 catch

  catch(coderef $block) (Venus::Error, any)

The catch function executes the code block trapping errors and returning the
caught exception in scalar context, and also returning the result as a second
argument in list context.

I<Since C<0.01>>

=over 4

=item catch example 1

  package main;

  use Venus 'catch';

  my $error = catch {die};

  $error;

  # "Died at ..."

=back

=over 4

=item catch example 2

  package main;

  use Venus 'catch';

  my ($error, $result) = catch {error};

  $error;

  # bless({...}, 'Venus::Error')

=back

=over 4

=item catch example 3

  package main;

  use Venus 'catch';

  my ($error, $result) = catch {true};

  $result;

  # 1

=back

=cut

=head2 caught

  caught(object $error, string | tuple[string, string] $identity, coderef $block) (any)

The caught function evaluates the exception object provided and validates its
identity and name (if provided) then executes the code block provided returning
the result of the callback. If no callback is provided this function returns
the exception object on success and C<undef> on failure.

I<Since C<1.95>>

=over 4

=item caught example 1

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error };

  my $result = caught $error, 'Venus::Error';

  # bless(..., 'Venus::Error')

=back

=over 4

=item caught example 2

  package main;

  use Venus 'catch', 'caught', 'raise';

  my $error = catch { raise 'Example::Error' };

  my $result = caught $error, 'Venus::Error';

  # bless(..., 'Venus::Error')

=back

=over 4

=item caught example 3

  package main;

  use Venus 'catch', 'caught', 'raise';

  my $error = catch { raise 'Example::Error' };

  my $result = caught $error, 'Example::Error';

  # bless(..., 'Venus::Error')

=back

=over 4

=item caught example 4

  package main;

  use Venus 'catch', 'caught', 'raise';

  my $error = catch { raise 'Example::Error', { name => 'on.test' } };

  my $result = caught $error, ['Example::Error', 'on.test'];

  # bless(..., 'Venus::Error')

=back

=over 4

=item caught example 5

  package main;

  use Venus 'catch', 'caught', 'raise';

  my $error = catch { raise 'Example::Error', { name => 'on.recv' } };

  my $result = caught $error, ['Example::Error', 'on.send'];

  # undef

=back

=over 4

=item caught example 6

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error };

  my $result = caught $error, ['Example::Error', 'on.send'];

  # undef

=back

=over 4

=item caught example 7

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error };

  my $result = caught $error, ['Example::Error'];

  # undef

=back

=over 4

=item caught example 8

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error };

  my $result = caught $error, 'Example::Error';

  # undef

=back

=over 4

=item caught example 9

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error { name => 'on.send' } };

  my $result = caught $error, ['Venus::Error', 'on.send'];

  # bless(..., 'Venus::Error')

=back

=over 4

=item caught example 10

  package main;

  use Venus 'catch', 'caught', 'error';

  my $error = catch { error { name => 'on.send.open' } };

  my $result = caught $error, ['Venus::Error', 'on.send'], sub {
    $error->stash('caught', true) if $error->is('on.send.open');
    return $error;
  };

  # bless(..., 'Venus::Error')

=back

=cut

=head2 chain

  chain(string | object | coderef $self, string | within[arrayref, string] @args) (any)

The chain function chains function and method calls to a package (and return
values) and returns the result.

I<Since C<2.32>>

=over 4

=item chain example 1

  package main;

  use Venus 'chain';

  my $result = chain('Venus::Path', ['new', 't'], 'exists');

  # 1

=back

=over 4

=item chain example 2

  package main;

  use Venus 'chain';

  my $result = chain('Venus::Path', ['new', 't'], ['test', 'd']);

  # 1

=back

=cut

=head2 check

  check(any $data, string $expr) (boolean)

The check function builds a L<Venus::Assert> object and returns the result of
a L<Venus::Assert/check> operation.

I<Since C<2.40>>

=over 4

=item check example 1

  package main;

  use Venus 'check';

  my $check = check(rand, 'float');

  # true

=back

=over 4

=item check example 2

  package main;

  use Venus 'check';

  my $check = check(rand, 'string');

  # false

=back

=cut

=head2 clargs

  clargs(arrayref $args, arrayref $spec) (Venus::Args, Venus::Opts, Venus::Vars)

The clargs function accepts a single arrayref of L<Getopt::Long> specs, or an
arrayref of arguments followed by an arrayref of L<Getopt::Long> specs, and
returns a three element list of L<Venus::Args>, L<Venus::Opts>, and
L<Venus::Vars> objects. If only a single arrayref is provided, the arguments
will be taken from C<@ARGV>.

I<Since C<3.10>>

=over 4

=item clargs example 1

  package main;

  use Venus 'clargs';

  my ($args, $opts, $vars) = clargs;

  # (
  #   bless(..., 'Venus::Args'),
  #   bless(..., 'Venus::Opts'),
  #   bless(..., 'Venus::Vars')
  # )

=back

=over 4

=item clargs example 2

  package main;

  use Venus 'clargs';

  my ($args, $opts, $vars) = clargs ['resource|r=s', 'help|h'];

  # (
  #   bless(..., 'Venus::Args'),
  #   bless(..., 'Venus::Opts'),
  #   bless(..., 'Venus::Vars')
  # )

=back

=over 4

=item clargs example 3

  package main;

  use Venus 'clargs';

  my ($args, $opts, $vars) = clargs ['--resource', 'help'],
    ['resource|r=s', 'help|h'];

  # (
  #   bless(..., 'Venus::Args'),
  #   bless(..., 'Venus::Opts'),
  #   bless(..., 'Venus::Vars')
  # )

=back

=cut

=head2 cli

  cli(arrayref $args) (Venus::Cli)

The cli function builds and returns a L<Venus::Cli> object.

I<Since C<2.55>>

=over 4

=item cli example 1

  package main;

  use Venus 'cli';

  my $cli = cli;

  # bless({...}, 'Venus::Cli')

=back

=over 4

=item cli example 2

  package main;

  use Venus 'cli';

  my $cli = cli ['--help'];

  # bless({...}, 'Venus::Cli')

  # $cli->set('opt', 'help', {})->opt('help');

  # 1

=back

=cut

=head2 clone

  clone(ref $value) (ref)

The clone function uses L<Storable/dclone> to perform a deep clone of the
reference provided and returns a copy.

I<Since C<3.55>>

=over 4

=item clone example 1

  package main;

  use Venus 'clone';

  my $orig = {1..4};

  my $clone = clone $orig;

  $orig->{3} = 5;

  my $result = $clone;

  # {1..4}

=back

=over 4

=item clone example 2

  package main;

  use Venus 'clone';

  my $orig = {1,2,3,{1..4}};

  my $clone = clone $orig;

  $orig->{3}->{3} = 5;

  my $result = $clone;

  # {1,2,3,{1..4}}

=back

=cut

=head2 code

  code(coderef $value, string | coderef $code, any @args) (any)

The code function builds and returns a L<Venus::Code> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item code example 1

  package main;

  use Venus 'code';

  my $code = code sub {};

  # bless({...}, 'Venus::Code')

=back

=over 4

=item code example 2

  package main;

  use Venus 'code';

  my $code = code sub {[1, @_]}, 'curry', 2,3,4;

  # sub {...}

=back

=cut

=head2 config

  config(hashref $value, string | coderef $code, any @args) (any)

The config function builds and returns a L<Venus::Config> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item config example 1

  package main;

  use Venus 'config';

  my $config = config {};

  # bless({...}, 'Venus::Config')

=back

=over 4

=item config example 2

  package main;

  use Venus 'config';

  my $config = config {}, 'read_perl', '{"data"=>1}';

  # bless({...}, 'Venus::Config')

=back

=cut

=head2 container

  container(hashref $value, string | coderef $code, any @args) (any)

The container function builds and returns a L<Venus::Container> object, or
dispatches to the coderef or method provided.

I<Since C<3.20>>

=over 4

=item container example 1

  package main;

  use Venus 'container';

  my $container = container {};

  # bless({...}, 'Venus::Config')

=back

=over 4

=item container example 2

  package main;

  use Venus 'container';

  my $data = {
    '$metadata' => {
      tmplog => "/tmp/log"
    },
    '$services' => {
      log => {
        package => "Venus/Path",
        argument => {
          '$metadata' => "tmplog"
        }
      }
    }
  };

  my $log = container $data, 'resolve', 'log';

  # bless({value => '/tmp/log'}, 'Venus::Path')

=back

=cut

=head2 cop

  cop(string | object | coderef $self, string $name) (coderef)

The cop function attempts to curry the given subroutine on the object or class
and if successful returns a closure.

I<Since C<2.32>>

=over 4

=item cop example 1

  package main;

  use Venus 'cop';

  my $coderef = cop('Digest::SHA', 'sha1_hex');

  # sub { ... }

=back

=over 4

=item cop example 2

  package main;

  use Venus 'cop';

  require Digest::SHA;

  my $coderef = cop(Digest::SHA->new, 'digest');

  # sub { ... }

=back

=cut

=head2 data

  data(string $value, string | coderef $code, any @args) (any)

The data function builds and returns a L<Venus::Data> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item data example 1

  package main;

  use Venus 'data';

  my $data = data 't/data/sections';

  # bless({...}, 'Venus::Data')

=back

=over 4

=item data example 2

  package main;

  use Venus 'data';

  my $data = data 't/data/sections', 'string', undef, 'name';

  # "Example #1\nExample #2"

=back

=cut

=head2 date

  date(number $value, string | coderef $code, any @args) (any)

The date function builds and returns a L<Venus::Date> object, or dispatches to
the coderef or method provided.

I<Since C<2.40>>

=over 4

=item date example 1

  package main;

  use Venus 'date';

  my $date = date time, 'string';

  # '0000-00-00T00:00:00Z'

=back

=over 4

=item date example 2

  package main;

  use Venus 'date';

  my $date = date time, 'reset', 570672000;

  # bless({...}, 'Venus::Date')

  # $date->string;

  # '1988-02-01T00:00:00Z'

=back

=over 4

=item date example 3

  package main;

  use Venus 'date';

  my $date = date time;

  # bless({...}, 'Venus::Date')

=back

=cut

=head2 docs

  docs(any @args) (any)

The docs function builds a L<Venus::Data> object using L<Venus::Data/docs> for
the current file, i.e. L<perlfunc/__FILE__> or script, i.e. C<$0>, and returns
the result of a L<Venus::Data/string> operation using the arguments provided.

I<Since C<3.30>>

=over 4

=item docs example 1

  package main;

  use Venus 'docs';

  # =head1 ABSTRACT
  #
  # Example Abstract
  #
  # =cut

  my $docs = docs 'head1', 'ABSTRACT';

  # "Example Abstract"

=back

=over 4

=item docs example 2

  package main;

  use Venus 'docs';

  # =head1 NAME
  #
  # Example #1
  #
  # =cut
  #
  # =head1 NAME
  #
  # Example #2
  #
  # =cut

  my $docs = docs 'head1', 'NAME';

  # "Example #1\nExample #2"

=back

=cut

=head2 enum

  enum(arrayref | hashref $value) (Venus::Enum)

The enum function builds and returns a L<Venus::Enum> object.

I<Since C<3.55>>

=over 4

=item enum example 1

  package main;

  use Venus 'enum';

  my $themes = enum ['light', 'dark'];

  # bless({scope => sub{...}}, "Venus::Enum")

  # my $result = $themes->get('dark');

  # bless({scope => sub{...}}, "Venus::Enum")

  # "$result"

  # "dark"

=back

=over 4

=item enum example 2

  package main;

  use Venus 'enum';

  my $themes = enum {
    light => 'light_theme',
    dark => 'dark_theme',
  };

  # bless({scope => sub{...}}, "Venus::Enum")

  # my $result = $themes->get('dark');

  # bless({scope => sub{...}}, "Venus::Enum")

  # "$result"

  # "dark_theme"

=back

=cut

=head2 error

  error(maybe[hashref] $args) (Venus::Error)

The error function throws a L<Venus::Error> exception object using the
exception object arguments provided.

I<Since C<0.01>>

=over 4

=item error example 1

  package main;

  use Venus 'error';

  my $error = error;

  # bless({...}, 'Venus::Error')

=back

=over 4

=item error example 2

  package main;

  use Venus 'error';

  my $error = error {
    message => 'Something failed!',
  };

  # bless({message => 'Something failed!', ...}, 'Venus::Error')

=back

=cut

=head2 false

  false() (boolean)

The false function returns a falsy boolean value which is designed to be
practically indistinguishable from the conventional numerical C<0> value.

I<Since C<0.01>>

=over 4

=item false example 1

  package main;

  use Venus;

  my $false = false;

  # 0

=back

=over 4

=item false example 2

  package main;

  use Venus;

  my $true = !false;

  # 1

=back

=cut

=head2 fault

  fault(string $args) (Venus::Fault)

The fault function throws a L<Venus::Fault> exception object and represents a
system failure, and isn't meant to be caught.

I<Since C<1.80>>

=over 4

=item fault example 1

  package main;

  use Venus 'fault';

  my $fault = fault;

  # bless({message => 'Exception!'}, 'Venus::Fault')

=back

=over 4

=item fault example 2

  package main;

  use Venus 'fault';

  my $fault = fault 'Something failed!';

  # bless({message => 'Something failed!'}, 'Venus::Fault')

=back

=cut

=head2 float

  float(string $value, string | coderef $code, any @args) (any)

The float function builds and returns a L<Venus::Float> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item float example 1

  package main;

  use Venus 'float';

  my $float = float 1.23;

  # bless({...}, 'Venus::Float')

=back

=over 4

=item float example 2

  package main;

  use Venus 'float';

  my $float = float 1.23, 'int';

  # 1

=back

=cut

=head2 future

  future(coderef $code) (Venus::Future)

The future function builds and returns a L<Venus::Future> object.

I<Since C<3.55>>

=over 4

=item future example 1

  package main;

  use Venus 'future';

  my $future = future(sub{
    my ($resolve, $reject) = @_;

    return int(rand(2)) ? $resolve->result('pass') : $reject->result('fail');
  });

  # bless(..., "Venus::Future")

  # $future->is_pending;

  # false

=back

=cut

=head2 gather

  gather(any $value, coderef $callback) (any)

The gather function builds a L<Venus::Gather> object, passing it and the value
provided to the callback provided, and returns the return value from
L<Venus::Gather/result>.

I<Since C<2.50>>

=over 4

=item gather example 1

  package main;

  use Venus 'gather';

  my $gather = gather ['a'..'d'];

  # bless({...}, 'Venus::Gather')

  # $gather->result;

  # undef

=back

=over 4

=item gather example 2

  package main;

  use Venus 'gather';

  my $gather = gather ['a'..'d'], sub {{
    a => 1,
    b => 2,
    c => 3,
  }};

  # [1..3]

=back

=over 4

=item gather example 3

  package main;

  use Venus 'gather';

  my $gather = gather ['e'..'h'], sub {{
    a => 1,
    b => 2,
    c => 3,
  }};

  # []

=back

=over 4

=item gather example 4

  package main;

  use Venus 'gather';

  my $gather = gather ['a'..'d'], sub {
    my ($case) = @_;

    $case->when(sub{lc($_) eq 'a'})->then('a -> A');
    $case->when(sub{lc($_) eq 'b'})->then('b -> B');
  };

  # ['a -> A', 'b -> B']

=back

=over 4

=item gather example 5

  package main;

  use Venus 'gather';

  my $gather = gather ['a'..'d'], sub {

    $_->when(sub{lc($_) eq 'a'})->then('a -> A');
    $_->when(sub{lc($_) eq 'b'})->then('b -> B');
  };

  # ['a -> A', 'b -> B']

=back

=cut

=head2 hash

  hash(hashref $value, string | coderef $code, any @args) (any)

The hash function builds and returns a L<Venus::Hash> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item hash example 1

  package main;

  use Venus 'hash';

  my $hash = hash {1..4};

  # bless({...}, 'Venus::Hash')

=back

=over 4

=item hash example 2

  package main;

  use Venus 'hash';

  my $hash = hash {1..8}, 'pairs';

  # [[1, 2], [3, 4], [5, 6], [7, 8]]

=back

=cut

=head2 hashref

  hashref(any @args) (hashref)

The hashref function takes a list of arguments and returns a hashref.

I<Since C<3.10>>

=over 4

=item hashref example 1

  package main;

  use Venus 'hashref';

  my $hashref = hashref(content => 'example');

  # {content => "example"}

=back

=over 4

=item hashref example 2

  package main;

  use Venus 'hashref';

  my $hashref = hashref({content => 'example'});

  # {content => "example"}

=back

=over 4

=item hashref example 3

  package main;

  use Venus 'hashref';

  my $hashref = hashref('content');

  # {content => undef}

=back

=over 4

=item hashref example 4

  package main;

  use Venus 'hashref';

  my $hashref = hashref('content', 'example', 'algorithm');

  # {content => "example", algorithm => undef}

=back

=cut

=head2 is_bool

  is_bool(any $arg) (boolean)

The is_bool function returns L</true> if the value provided is a boolean value,
not merely truthy, and L</false> otherwise.

I<Since C<3.18>>

=over 4

=item is_bool example 1

  package main;

  use Venus 'is_bool';

  my $is_bool = is_bool true;

  # true

=back

=over 4

=item is_bool example 2

  package main;

  use Venus 'is_bool';

  my $is_bool = is_bool false;

  # true

=back

=over 4

=item is_bool example 3

  package main;

  use Venus 'is_bool';

  my $is_bool = is_bool 1;

  # false

=back

=over 4

=item is_bool example 4

  package main;

  use Venus 'is_bool';

  my $is_bool = is_bool 0;

  # false

=back

=cut

=head2 is_false

  is_false(any $data) (boolean)

The is_false function accepts a scalar value and returns true if the value is
falsy.

I<Since C<3.04>>

=over 4

=item is_false example 1

  package main;

  use Venus 'is_false';

  my $is_false = is_false 0;

  # true

=back

=over 4

=item is_false example 2

  package main;

  use Venus 'is_false';

  my $is_false = is_false 1;

  # false

=back

=cut

=head2 is_true

  is_true(any $data) (boolean)

The is_true function accepts a scalar value and returns true if the value is
truthy.

I<Since C<3.04>>

=over 4

=item is_true example 1

  package main;

  use Venus 'is_true';

  my $is_true = is_true 1;

  # true

=back

=over 4

=item is_true example 2

  package main;

  use Venus 'is_true';

  my $is_true = is_true 0;

  # false

=back

=cut

=head2 json

  json(string $call, any $data) (any)

The json function builds a L<Venus::Json> object and will either
L<Venus::Json/decode> or L<Venus::Json/encode> based on the argument provided
and returns the result.

I<Since C<2.40>>

=over 4

=item json example 1

  package main;

  use Venus 'json';

  my $decode = json 'decode', '{"codename":["Ready","Robot"],"stable":true}';

  # { codename => ["Ready", "Robot"], stable => 1 }

=back

=over 4

=item json example 2

  package main;

  use Venus 'json';

  my $encode = json 'encode', { codename => ["Ready", "Robot"], stable => true };

  # '{"codename":["Ready","Robot"],"stable":true}'

=back

=over 4

=item json example 3

  package main;

  use Venus 'json';

  my $json = json;

  # bless({...}, 'Venus::Json')

=back

=over 4

=item json example 4

  package main;

  use Venus 'json';

  my $json = json 'class', {data => "..."};

  # Exception! (isa Venus::Fault)

=back

=cut

=head2 list

  list(any @args) (any)

The list function accepts a list of values and flattens any arrayrefs,
returning a list of scalars.

I<Since C<3.04>>

=over 4

=item list example 1

  package main;

  use Venus 'list';

  my @list = list 1..4;

  # (1..4)

=back

=over 4

=item list example 2

  package main;

  use Venus 'list';

  my @list = list [1..4];

  # (1..4)

=back

=over 4

=item list example 3

  package main;

  use Venus 'list';

  my @list = list [1..4], 5, [6..10];

  # (1..10)

=back

=cut

=head2 load

  load(any $name) (Venus::Space)

The load function loads the package provided and returns a L<Venus::Space> object.

I<Since C<2.32>>

=over 4

=item load example 1

  package main;

  use Venus 'load';

  my $space = load 'Venus::Scalar';

  # bless({value => 'Venus::Scalar'}, 'Venus::Space')

=back

=cut

=head2 log

  log(any @args) (Venus::Log)

The log function prints the arguments provided to STDOUT, stringifying complex
values, and returns a L<Venus::Log> object. If the first argument is a log
level name, e.g. C<debug>, C<error>, C<fatal>, C<info>, C<trace>, or C<warn>,
it will be used when emitting the event. The desired log level is specified by
the C<VENUS_LOG_LEVEL> environment variable and defaults to C<trace>.

I<Since C<2.40>>

=over 4

=item log example 1

  package main;

  use Venus 'log';

  my $log = log;

  # bless({...}, 'Venus::Log')

  # log time, rand, 1..9;

  # 00000000 0.000000, 1..9

=back

=cut

=head2 make

  make(string $package, any @args) (any)

The make function L<"calls"|Venus/call> the C<new> routine on the invocant and
returns the result which should be a package string or an object.

I<Since C<2.32>>

=over 4

=item make example 1

  package main;

  use Venus 'make';

  my $made = make('Digest::SHA');

  # bless(do{\(my $o = '...')}, 'Digest::SHA')

=back

=over 4

=item make example 2

  package main;

  use Venus 'make';

  my $made = make('Digest', 'SHA');

  # bless(do{\(my $o = '...')}, 'Digest::SHA')

=back

=cut

=head2 match

  match(any $value, coderef $callback) (any)

The match function builds a L<Venus::Match> object, passing it and the value
provided to the callback provided, and returns the return value from
L<Venus::Match/result>.

I<Since C<2.50>>

=over 4

=item match example 1

  package main;

  use Venus 'match';

  my $match = match 5;

  # bless({...}, 'Venus::Match')

  # $match->result;

  # undef

=back

=over 4

=item match example 2

  package main;

  use Venus 'match';

  my $match = match 5, sub {{
    1 => 'one',
    2 => 'two',
    5 => 'five',
  }};

  # 'five'

=back

=over 4

=item match example 3

  package main;

  use Venus 'match';

  my $match = match 5, sub {{
    1 => 'one',
    2 => 'two',
    3 => 'three',
  }};

  # undef

=back

=over 4

=item match example 4

  package main;

  use Venus 'match';

  my $match = match 5, sub {
    my ($case) = @_;

    $case->when(sub{$_ < 5})->then('< 5');
    $case->when(sub{$_ > 5})->then('> 5');
  };

  # undef

=back

=over 4

=item match example 5

  package main;

  use Venus 'match';

  my $match = match 6, sub {
    my ($case, $data) = @_;

    $case->when(sub{$_ < 5})->then("$data < 5");
    $case->when(sub{$_ > 5})->then("$data > 5");
  };

  # '6 > 5'

=back

=over 4

=item match example 6

  package main;

  use Venus 'match';

  my $match = match 4, sub {

    $_->when(sub{$_ < 5})->then("$_[1] < 5");
    $_->when(sub{$_ > 5})->then("$_[1] > 5");
  };

  # '4 < 5'

=back

=cut

=head2 merge

  merge(any @args) (any)

The merge function returns a value which is a merger of all of the arguments
provided.

I<Since C<2.32>>

=over 4

=item merge example 1

  package main;

  use Venus 'merge';

  my $merged = merge({1..4}, {5, 6});

  # {1..6}

=back

=over 4

=item merge example 2

  package main;

  use Venus 'merge';

  my $merged = merge({1..4}, {5, 6}, {7, 8, 9, 0});

  # {1..9, 0}

=back

=cut

=head2 meta

  meta(string $value, string | coderef $code, any @args) (any)

The meta function builds and returns a L<Venus::Meta> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item meta example 1

  package main;

  use Venus 'meta';

  my $meta = meta 'Venus';

  # bless({...}, 'Venus::Meta')

=back

=over 4

=item meta example 2

  package main;

  use Venus 'meta';

  my $result = meta 'Venus', 'sub', 'meta';

  # 1

=back

=cut

=head2 name

  name(string $value, string | coderef $code, any @args) (any)

The name function builds and returns a L<Venus::Name> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item name example 1

  package main;

  use Venus 'name';

  my $name = name 'Foo/Bar';

  # bless({...}, 'Venus::Name')

=back

=over 4

=item name example 2

  package main;

  use Venus 'name';

  my $name = name 'Foo/Bar', 'package';

  # "Foo::Bar"

=back

=cut

=head2 number

  number(Num $value, string | coderef $code, any @args) (any)

The number function builds and returns a L<Venus::Number> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item number example 1

  package main;

  use Venus 'number';

  my $number = number 1_000;

  # bless({...}, 'Venus::Number')

=back

=over 4

=item number example 2

  package main;

  use Venus 'number';

  my $number = number 1_000, 'prepend', 1;

  # 11_000

=back

=cut

=head2 opts

  opts(arrayref $value, string | coderef $code, any @args) (any)

The opts function builds and returns a L<Venus::Opts> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item opts example 1

  package main;

  use Venus 'opts';

  my $opts = opts ['--resource', 'users'];

  # bless({...}, 'Venus::Opts')

=back

=over 4

=item opts example 2

  package main;

  use Venus 'opts';

  my $opts = opts ['--resource', 'users'], 'reparse', ['resource|r=s', 'help|h'];

  # bless({...}, 'Venus::Opts')

  # my $resource = $opts->get('resource');

  # "users"

=back

=cut

=head2 pairs

  pairs(any $data) (arrayref)

The pairs function accepts an arrayref or hashref and returns an arrayref of
arrayrefs holding keys (or indices) and values. The function returns an empty
arrayref for all other values provided. Returns a list in list context.

I<Since C<3.04>>

=over 4

=item pairs example 1

  package main;

  use Venus 'pairs';

  my $pairs = pairs [1..4];

  # [[0,1], [1,2], [2,3], [3,4]]

=back

=over 4

=item pairs example 2

  package main;

  use Venus 'pairs';

  my $pairs = pairs {'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4};

  # [['a',1], ['b',2], ['c',3], ['d',4]]

=back

=over 4

=item pairs example 3

  package main;

  use Venus 'pairs';

  my @pairs = pairs [1..4];

  # ([0,1], [1,2], [2,3], [3,4])

=back

=over 4

=item pairs example 4

  package main;

  use Venus 'pairs';

  my @pairs = pairs {'a' => 1, 'b' => 2, 'c' => 3, 'd' => 4};

  # (['a',1], ['b',2], ['c',3], ['d',4])

=back

=cut

=head2 path

  path(string $value, string | coderef $code, any @args) (any)

The path function builds and returns a L<Venus::Path> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item path example 1

  package main;

  use Venus 'path';

  my $path = path 't/data/planets';

  # bless({...}, 'Venus::Path')

=back

=over 4

=item path example 2

  package main;

  use Venus 'path';

  my $path = path 't/data/planets', 'absolute';

  # bless({...}, 'Venus::Path')

=back

=cut

=head2 perl

  perl(string $call, any $data) (any)

The perl function builds a L<Venus::Dump> object and will either
L<Venus::Dump/decode> or L<Venus::Dump/encode> based on the argument provided
and returns the result.

I<Since C<2.40>>

=over 4

=item perl example 1

  package main;

  use Venus 'perl';

  my $decode = perl 'decode', '{stable=>bless({},\'Venus::True\')}';

  # { stable => 1 }

=back

=over 4

=item perl example 2

  package main;

  use Venus 'perl';

  my $encode = perl 'encode', { stable => true };

  # '{stable=>bless({},\'Venus::True\')}'

=back

=over 4

=item perl example 3

  package main;

  use Venus 'perl';

  my $perl = perl;

  # bless({...}, 'Venus::Dump')

=back

=over 4

=item perl example 4

  package main;

  use Venus 'perl';

  my $perl = perl 'class', {data => "..."};

  # Exception! (isa Venus::Fault)

=back

=cut

=head2 process

  process(string | coderef $code, any @args) (any)

The process function builds and returns a L<Venus::Process> object, or
dispatches to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item process example 1

  package main;

  use Venus 'process';

  my $process = process;

  # bless({...}, 'Venus::Process')

=back

=over 4

=item process example 2

  package main;

  use Venus 'process';

  my $process = process 'do', 'alarm', 10;

  # bless({...}, 'Venus::Process')

=back

=cut

=head2 proto

  proto(hashref $value, string | coderef $code, any @args) (any)

The proto function builds and returns a L<Venus::Prototype> object, or
dispatches to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item proto example 1

  package main;

  use Venus 'proto';

  my $proto = proto {
    '$counter' => 0,
  };

  # bless({...}, 'Venus::Prototype')

=back

=over 4

=item proto example 2

  package main;

  use Venus 'proto';

  my $proto = proto { '$counter' => 0 }, 'apply', {
    '&decrement' => sub { $_[0]->counter($_[0]->counter - 1) },
    '&increment' => sub { $_[0]->counter($_[0]->counter + 1) },
  };

  # bless({...}, 'Venus::Prototype')

=back

=cut

=head2 puts

  puts(any @args) (arrayref)

The puts function select values from within the underlying data structure using
L<Venus::Array/path> or L<Venus::Hash/path>, optionally assigning the value to
the preceeding scalar reference and returns all the values selected.

I<Since C<3.20>>

=over 4

=item puts example 1

  package main;

  use Venus 'puts';

  my $data = {
    size => "small",
    fruit => "apple",
    meta => {
      expiry => '5d',
    },
    color => "red",
  };

  puts $data, (
    \my $fruit, 'fruit',
    \my $expiry, 'meta.expiry'
  );

  my $puts = [$fruit, $expiry];

  # ["apple", "5d"]

=back

=cut

=head2 raise

  raise(string $class | tuple[string, string] $class, maybe[hashref] $args) (Venus::Error)

The raise function generates and throws a named exception object derived from
L<Venus::Error>, or provided base class, using the exception object arguments
provided.

I<Since C<0.01>>

=over 4

=item raise example 1

  package main;

  use Venus 'raise';

  my $error = raise 'MyApp::Error';

  # bless({...}, 'MyApp::Error')

=back

=over 4

=item raise example 2

  package main;

  use Venus 'raise';

  my $error = raise ['MyApp::Error', 'Venus::Error'];

  # bless({...}, 'MyApp::Error')

=back

=over 4

=item raise example 3

  package main;

  use Venus 'raise';

  my $error = raise ['MyApp::Error', 'Venus::Error'], {
    message => 'Something failed!',
  };

  # bless({message => 'Something failed!', ...}, 'MyApp::Error')

=back

=cut

=head2 random

  random(string | coderef $code, any @args) (any)

The random function builds and returns a L<Venus::Random> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item random example 1

  package main;

  use Venus 'random';

  my $random = random;

  # bless({...}, 'Venus::Random')

=back

=over 4

=item random example 2

  package main;

  use Venus 'random';

  my $random = random 'collect', 10, 'letter';

  # "ryKUPbJHYT"

=back

=cut

=head2 range

  range(number | string @args) (arrayref)

The range function returns the result of a L<Venus::Array/range> operation.

I<Since C<3.20>>

=over 4

=item range example 1

  package main;

  use Venus 'range';

  my $range = range [1..9], ':4';

  # [1..5]

=back

=over 4

=item range example 2

  package main;

  use Venus 'range';

  my $range = range [1..9], '-4:-1';

  # [6..9]

=back

=cut

=head2 regexp

  regexp(string $value, string | coderef $code, any @args) (any)

The regexp function builds and returns a L<Venus::Regexp> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item regexp example 1

  package main;

  use Venus 'regexp';

  my $regexp = regexp '[0-9]';

  # bless({...}, 'Venus::Regexp')

=back

=over 4

=item regexp example 2

  package main;

  use Venus 'regexp';

  my $replace = regexp '[0-9]', 'replace', 'ID 12345', '0', 'g';

  # bless({...}, 'Venus::Replace')

  # $replace->get;

  # "ID 00000"

=back

=cut

=head2 render

  render(string $data, hashref $args) (string)

The render function accepts a string as a template and renders it using
L<Venus::Template>, and returns the result.

I<Since C<3.04>>

=over 4

=item render example 1

  package main;

  use Venus 'render';

  my $render = render 'hello {{name}}', {
    name => 'user',
  };

  # "hello user"

=back

=cut

=head2 replace

  replace(arrayref $value, string | coderef $code, any @args) (any)

The replace function builds and returns a L<Venus::Replace> object, or
dispatches to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item replace example 1

  package main;

  use Venus 'replace';

  my $replace = replace ['hello world', 'world', 'universe'];

  # bless({...}, 'Venus::Replace')

=back

=over 4

=item replace example 2

  package main;

  use Venus 'replace';

  my $replace = replace ['hello world', 'world', 'universe'], 'get';

  # "hello universe"

=back

=cut

=head2 resolve

  resolve(hashref $value, any @args) (any)

The resolve function builds and returns an object via L<Venus::Container/resolve>.

I<Since C<3.30>>

=over 4

=item resolve example 1

  package main;

  use Venus 'resolve';

  my $resolve = resolve {};

  # undef

=back

=over 4

=item resolve example 2

  package main;

  use Venus 'resolve';

  my $data = {
    '$services' => {
      log => {
        package => "Venus/Path",
      }
    }
  };

  my $log = resolve $data, 'log';

  # bless({...}, 'Venus::Path')

=back

=cut

=head2 roll

  roll(string $name, any @args) (any)

The roll function takes a list of arguments, assuming the first argument is
invokable, and reorders the list such that the routine name provided comes
after the invocant (i.e. the 1st argument), creating a list acceptable to the
L</call> function.

I<Since C<2.32>>

=over 4

=item roll example 1

  package main;

  use Venus 'roll';

  my @list = roll('sha1_hex', 'Digest::SHA');

  # ('Digest::SHA', 'sha1_hex');

=back

=over 4

=item roll example 2

  package main;

  use Venus 'roll';

  my @list = roll('sha1_hex', call(\'Digest::SHA', 'new'));

  # (bless(do{\(my $o = '...')}, 'Digest::SHA'), 'sha1_hex');

=back

=cut

=head2 schema

  schema(string $value, string | coderef $code, any @args) (any)

The schema function builds and returns a L<Venus::Schema> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item schema example 1

  package main;

  use Venus 'schema';

  my $schema = schema { name => 'string' };

  # bless({...}, "Venus::Schema")

=back

=over 4

=item schema example 2

  package main;

  use Venus 'schema';

  my $result = schema { name => 'string' }, 'validate', { name => 'example' };

  # { name => 'example' }

=back

=cut

=head2 search

  search(arrayref $value, string | coderef $code, any @args) (any)

The search function builds and returns a L<Venus::Search> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item search example 1

  package main;

  use Venus 'search';

  my $search = search ['hello world', 'world'];

  # bless({...}, 'Venus::Search')

=back

=over 4

=item search example 2

  package main;

  use Venus 'search';

  my $search = search ['hello world', 'world'], 'count';

  # 1

=back

=cut

=head2 set

  set(arrayref $value) (Venus::Set)

The set function returns a L<Venus::Set> object for the arrayref provided.

I<Since C<4.11>>

=over 4

=item set example 1

  package main;

  use Venus 'set';

  my $set = set [1..9];

  # bless(..., 'Venus::Set')

=back

=cut

=head2 space

  space(any $name) (Venus::Space)

The space function returns a L<Venus::Space> object for the package provided.

I<Since C<2.32>>

=over 4

=item space example 1

  package main;

  use Venus 'space';

  my $space = space 'Venus::Scalar';

  # bless({value => 'Venus::Scalar'}, 'Venus::Space')

=back

=cut

=head2 string

  string(string $value, string | coderef $code, any @args) (any)

The string function builds and returns a L<Venus::String> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item string example 1

  package main;

  use Venus 'string';

  my $string = string 'hello world';

  # bless({...}, 'Venus::String')

=back

=over 4

=item string example 2

  package main;

  use Venus 'string';

  my $string = string 'hello world', 'camelcase';

  # "helloWorld"

=back

=cut

=head2 syscall

  syscall(number | string @args) (any)

The syscall function perlforms system call, i.e. a L<perlfunc/qx> operation,
and returns C<true> if the command succeeds, otherwise returns C<false>. In
list context, returns the output of the operation and the exit code.

I<Since C<3.04>>

=over 4

=item syscall example 1

  package main;

  use Venus 'syscall';

  my $syscall = syscall 'perl', '-v';

  # true

=back

=over 4

=item syscall example 2

  package main;

  use Venus 'syscall';

  my $syscall = syscall 'perl', '-z';

  # false

=back

=over 4

=item syscall example 3

  package main;

  use Venus 'syscall';

  my ($data, $code) = syscall 'sun', '--heat-death';

  # ('done', 0)

=back

=over 4

=item syscall example 4

  package main;

  use Venus 'syscall';

  my ($data, $code) = syscall 'earth', '--melt-icecaps';

  # ('', 127)

=back

=cut

=head2 template

  template(string $value, string | coderef $code, any @args) (any)

The template function builds and returns a L<Venus::Template> object, or
dispatches to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item template example 1

  package main;

  use Venus 'template';

  my $template = template 'Hi {{name}}';

  # bless({...}, 'Venus::Template')

=back

=over 4

=item template example 2

  package main;

  use Venus 'template';

  my $template = template 'Hi {{name}}', 'render', undef, {
    name => 'stranger',
  };

  # "Hi stranger"

=back

=cut

=head2 test

  test(string $value, string | coderef $code, any @args) (any)

The test function builds and returns a L<Venus::Test> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item test example 1

  package main;

  use Venus 'test';

  my $test = test 't/Venus.t';

  # bless({...}, 'Venus::Test')

=back

=over 4

=item test example 2

  package main;

  use Venus 'test';

  my $test = test 't/Venus.t', 'for', 'synopsis';

  # bless({...}, 'Venus::Test')

=back

=cut

=head2 text

  text(any @args) (any)

The text function builds a L<Venus::Data> object using L<Venus::Data/text> for
the current file, i.e. L<perlfunc/__FILE__> or script, i.e. C<$0>, and returns
the result of a L<Venus::Data/string> operation using the arguments provided.

I<Since C<3.30>>

=over 4

=item text example 1

  package main;

  use Venus 'text';

  # @@ name
  #
  # Example Name
  #
  # @@ end
  #
  # @@ titles #1
  #
  # Example Title #1
  #
  # @@ end
  #
  # @@ titles #2
  #
  # Example Title #2
  #
  # @@ end

  my $text = text 'name';

  # "Example Name"

=back

=over 4

=item text example 2

  package main;

  use Venus 'text';

  # @@ name
  #
  # Example Name
  #
  # @@ end
  #
  # @@ titles #1
  #
  # Example Title #1
  #
  # @@ end
  #
  # @@ titles #2
  #
  # Example Title #2
  #
  # @@ end

  my $text = text 'titles', '#1';

  # "Example Title #1"

=back

=over 4

=item text example 3

  package main;

  use Venus 'text';

  # @@ name
  #
  # Example Name
  #
  # @@ end
  #
  # @@ titles #1
  #
  # Example Title #1
  #
  # @@ end
  #
  # @@ titles #2
  #
  # Example Title #2
  #
  # @@ end

  my $text = text undef, 'name';

  # "Example Name"

=back

=cut

=head2 then

  then(string | object | coderef $self, any @args) (any)

The then function proxies the call request to the L</call> function and returns
the result as a list, prepended with the invocant.

I<Since C<2.32>>

=over 4

=item then example 1

  package main;

  use Venus 'then';

  my @list = then('Digest::SHA', 'sha1_hex');

  # ("Digest::SHA", "da39a3ee5e6b4b0d3255bfef95601890afd80709")

=back

=cut

=head2 throw

  throw(string | hashref $value, string | coderef $code, any @args) (any)

The throw function builds and returns a L<Venus::Throw> object, or dispatches
to the coderef or method provided.

I<Since C<2.55>>

=over 4

=item throw example 1

  package main;

  use Venus 'throw';

  my $throw = throw 'Example::Error';

  # bless({...}, 'Venus::Throw')

=back

=over 4

=item throw example 2

  package main;

  use Venus 'throw';

  my $throw = throw 'Example::Error', 'catch', 'error';

  # bless({...}, 'Example::Error')

=back

=over 4

=item throw example 3

  package main;

  use Venus 'throw';

  my $throw = throw {
    name => 'on.execute',
    package => 'Example::Error',
    capture => ['...'],
    stash => {
      time => time,
    },
  };

  # bless({...}, 'Venus::Throw')

=back

=cut

=head2 true

  true() (boolean)

The true function returns a truthy boolean value which is designed to be
practically indistinguishable from the conventional numerical C<1> value.

I<Since C<0.01>>

=over 4

=item true example 1

  package main;

  use Venus;

  my $true = true;

  # 1

=back

=over 4

=item true example 2

  package main;

  use Venus;

  my $false = !true;

  # 0

=back

=cut

=head2 try

  try(any $data, string | coderef $code, any @args) (any)

The try function builds and returns a L<Venus::Try> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item try example 1

  package main;

  use Venus 'try';

  my $try = try sub {};

  # bless({...}, 'Venus::Try')

  # my $result = $try->result;

  # ()

=back

=over 4

=item try example 2

  package main;

  use Venus 'try';

  my $try = try sub { die };

  # bless({...}, 'Venus::Try')

  # my $result = $try->result;

  # Exception! (isa Venus::Error)

=back

=over 4

=item try example 3

  package main;

  use Venus 'try';

  my $try = try sub { die }, 'maybe';

  # bless({...}, 'Venus::Try')

  # my $result = $try->result;

  # undef

=back

=cut

=head2 type

  type(any $data, string | coderef $code, any @args) (any)

The type function builds and returns a L<Venus::Type> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item type example 1

  package main;

  use Venus 'type';

  my $type = type [1..4];

  # bless({...}, 'Venus::Type')

  # $type->deduce;

  # bless({...}, 'Venus::Array')

=back

=over 4

=item type example 2

  package main;

  use Venus 'type';

  my $type = type [1..4], 'deduce';

  # bless({...}, 'Venus::Array')

=back

=cut

=head2 unpack

  unpack(any @args) (Venus::Unpack)

The unpack function builds and returns a L<Venus::Unpack> object.

I<Since C<2.40>>

=over 4

=item unpack example 1

  package main;

  use Venus 'unpack';

  my $unpack = unpack;

  # bless({...}, 'Venus::Unpack')

  # $unpack->checks('string');

  # false

  # $unpack->checks('undef');

  # false

=back

=over 4

=item unpack example 2

  package main;

  use Venus 'unpack';

  my $unpack = unpack rand;

  # bless({...}, 'Venus::Unpack')

  # $unpack->check('number');

  # false

  # $unpack->check('float');

  # true

=back

=cut

=head2 vars

  vars(hashref $value, string | coderef $code, any @args) (any)

The vars function builds and returns a L<Venus::Vars> object, or dispatches to
the coderef or method provided.

I<Since C<2.55>>

=over 4

=item vars example 1

  package main;

  use Venus 'vars';

  my $vars = vars {};

  # bless({...}, 'Venus::Vars')

=back

=over 4

=item vars example 2

  package main;

  use Venus 'vars';

  my $path = vars {}, 'exists', 'path';

  # "..."

=back

=cut

=head2 venus

  venus(string $name, any @args) (any)

The venus function build a L<Venus> package via the L</chain> function based on
the name provided and returns an instance of that package.

I<Since C<2.40>>

=over 4

=item venus example 1

  package main;

  use Venus 'venus';

  my $space = venus 'space';

  # bless({value => 'Venus'}, 'Venus::Space')

=back

=over 4

=item venus example 2

  package main;

  use Venus 'venus';

  my $space = venus 'space', ['new', 'venus/string'];

  # bless({value => 'Venus::String'}, 'Venus::Space')

=back

=over 4

=item venus example 3

  package main;

  use Venus 'venus';

  my $space = venus 'code';

  # bless({value => sub{...}}, 'Venus::Code')

=back

=cut

=head2 work

  work(coderef $callback) (Venus::Process)

The work function builds a L<Venus::Process> object, forks the current process
using the callback provided via the L<Venus::Process/work> operation, and
returns an instance of L<Venus::Process> representing the current process.

I<Since C<2.40>>

=over 4

=item work example 1

  package main;

  use Venus 'work';

  my $parent = work sub {
    my ($process) = @_;
    # in forked process ...
    $process->exit;
  };

  # bless({...}, 'Venus::Process')

=back

=cut

=head2 wrap

  wrap(string $data, string $name) (coderef)

The wrap function installs a wrapper function in the calling package which when
called either returns the package string if no arguments are provided, or calls
L</make> on the package with whatever arguments are provided and returns the
result. Unless an alias is provided as a second argument, special characters
are stripped from the package to create the function name.

I<Since C<2.32>>

=over 4

=item wrap example 1

  package main;

  use Venus 'wrap';

  my $coderef = wrap('Digest::SHA');

  # sub { ... }

  # my $digest = DigestSHA();

  # "Digest::SHA"

  # my $digest = DigestSHA(1);

  # bless(do{\(my $o = '...')}, 'Digest::SHA')

=back

=over 4

=item wrap example 2

  package main;

  use Venus 'wrap';

  my $coderef = wrap('Digest::SHA', 'SHA');

  # sub { ... }

  # my $digest = SHA();

  # "Digest::SHA"

  # my $digest = SHA(1);

  # bless(do{\(my $o = '...')}, 'Digest::SHA')

=back

=cut

=head2 yaml

  yaml(string $call, any $data) (any)

The yaml function builds a L<Venus::Yaml> object and will either
L<Venus::Yaml/decode> or L<Venus::Yaml/encode> based on the argument provided
and returns the result.

I<Since C<2.40>>

=over 4

=item yaml example 1

  package main;

  use Venus 'yaml';

  my $decode = yaml 'decode', "---\nname:\n- Ready\n- Robot\nstable: true\n";

  # { name => ["Ready", "Robot"], stable => 1 }

=back

=over 4

=item yaml example 2

  package main;

  use Venus 'yaml';

  my $encode = yaml 'encode', { name => ["Ready", "Robot"], stable => true };

  # '---\nname:\n- Ready\n- Robot\nstable: true\n'

=back

=over 4

=item yaml example 3

  package main;

  use Venus 'yaml';

  my $yaml = yaml;

  # bless({...}, 'Venus::Yaml')

=back

=over 4

=item yaml example 4

  package main;

  use Venus 'yaml';

  my $yaml = yaml 'class', {data => "..."};

  # Exception! (isa Venus::Fault)

=back

=cut

=head1 FEATURES

This package provides the following features:

=cut

=over 4

=item venus-args

This library contains a L<Venus::Args> class which provides methods for
accessing C<@ARGS> items.

=back

=over 4

=item venus-array

This library contains a L<Venus::Array> class which provides methods for
manipulating array data.

=back

=over 4

=item venus-assert

This library contains a L<Venus::Assert> class which provides a mechanism for
asserting type constraints and coercion.

=back

=over 4

=item venus-boolean

This library contains a L<Venus::Boolean> class which provides a representation
for boolean values.

=back

=over 4

=item venus-box

This library contains a L<Venus::Box> class which provides a pure Perl boxing
mechanism.

=back

=over 4

=item venus-class

This library contains a L<Venus::Class> class which provides a class builder.

=back

=over 4

=item venus-cli

This library contains a L<Venus::Cli> class which provides a superclass for
creating CLIs.

=back

=over 4

=item venus-code

This library contains a L<Venus::Code> class which provides methods for
manipulating subroutines.

=back

=over 4

=item venus-config

This library contains a L<Venus::Config> class which provides methods for
loading Perl, YAML, and JSON configuration data.

=back

=over 4

=item venus-data

This library contains a L<Venus::Data> class which provides methods for
extracting C<DATA> sections and POD block.

=back

=over 4

=item venus-date

This library contains a L<Venus::Date> class which provides methods for
formatting, parsing, and manipulating dates.

=back

=over 4

=item venus-dump

This library contains a L<Venus::Dump> class which provides methods for reading
and writing dumped Perl data.

=back

=over 4

=item venus-error

This library contains a L<Venus::Error> class which represents a context-aware
error (exception object).

=back

=over 4

=item venus-false

This library contains a L<Venus::False> class which provides the global
C<false> value.

=back

=over 4

=item venus-fault

This library contains a L<Venus::Fault> class which represents a generic system
error (exception object).

=back

=over 4

=item venus-float

This library contains a L<Venus::Float> class which provides methods for
manipulating float data.

=back

=over 4

=item venus-gather

This library contains a L<Venus::Gather> class which provides an
object-oriented interface for complex pattern matching operations on
collections of data, e.g. array references.

=back

=over 4

=item venus-hash

This library contains a L<Venus::Hash> class which provides methods for
manipulating hash data.

=back

=over 4

=item venus-json

This library contains a L<Venus::Json> class which provides methods for reading
and writing JSON data.

=back

=over 4

=item venus-log

This library contains a L<Venus::Log> class which provides methods for logging
information using various log levels.

=back

=over 4

=item venus-match

This library contains a L<Venus::Match> class which provides an object-oriented
interface for complex pattern matching operations on scalar values.

=back

=over 4

=item venus-meta

This library contains a L<Venus::Meta> class which provides configuration
information for L<Venus> derived classes.

=back

=over 4

=item venus-mixin

This library contains a L<Venus::Mixin> class which provides a mixin builder.

=back

=over 4

=item venus-name

This library contains a L<Venus::Name> class which provides methods for parsing
and formatting package namespaces.

=back

=over 4

=item venus-number

This library contains a L<Venus::Number> class which provides methods for
manipulating number data.

=back

=over 4

=item venus-opts

This library contains a L<Venus::Opts> class which provides methods for
handling command-line arguments.

=back

=over 4

=item venus-path

This library contains a L<Venus::Path> class which provides methods for working
with file system paths.

=back

=over 4

=item venus-process

This library contains a L<Venus::Process> class which provides methods for
handling and forking processes.

=back

=over 4

=item venus-prototype

This library contains a L<Venus::Prototype> class which provides a simple
construct for enabling prototype-base programming.

=back

=over 4

=item venus-random

This library contains a L<Venus::Random> class which provides an
object-oriented interface for Perl's pseudo-random number generator.

=back

=over 4

=item venus-regexp

This library contains a L<Venus::Regexp> class which provides methods for
manipulating regexp data.

=back

=over 4

=item venus-replace

This library contains a L<Venus::Replace> class which provides methods for
manipulating regexp replacement data.

=back

=over 4

=item venus-run

This library contains a L<Venus::Run> class which provides a base class for
providing a command execution system for creating CLIs (command-line
interfaces).

=back

=over 4

=item venus-scalar

This library contains a L<Venus::Scalar> class which provides methods for
manipulating scalar data.

=back

=over 4

=item venus-search

This library contains a L<Venus::Search> class which provides methods for
manipulating regexp search data.

=back

=over 4

=item venus-space

This library contains a L<Venus::Space> class which provides methods for
parsing and manipulating package namespaces.

=back

=over 4

=item venus-string

This library contains a L<Venus::String> class which provides methods for
manipulating string data.

=back

=over 4

=item venus-task

This library contains a L<Venus::Task> class which provides a base class for
creating CLIs (command-line interfaces).

=back

=over 4

=item venus-template

This library contains a L<Venus::Template> class which provides a templating
system, and methods for rendering template.

=back

=over 4

=item venus-test

This library contains a L<Venus::Test> class which aims to provide a standard
for documenting L<Venus> derived software projects.

=back

=over 4

=item venus-throw

This library contains a L<Venus::Throw> class which provides a mechanism for
generating and raising error objects.

=back

=over 4

=item venus-true

This library contains a L<Venus::True> class which provides the global C<true>
value.

=back

=over 4

=item venus-try

This library contains a L<Venus::Try> class which provides an object-oriented
interface for performing complex try/catch operations.

=back

=over 4

=item venus-type

This library contains a L<Venus::Type> class which provides methods for casting
native data types to objects.

=back

=over 4

=item venus-undef

This library contains a L<Venus::Undef> class which provides methods for
manipulating undef data.

=back

=over 4

=item venus-unpack

This library contains a L<Venus::Unpack> class which provides methods for
validating, coercing, and otherwise operating on lists of arguments.

=back

=over 4

=item venus-vars

This library contains a L<Venus::Vars> class which provides methods for
accessing C<%ENV> items.

=back

=over 4

=item venus-yaml

This library contains a L<Venus::Yaml> class which provides methods for reading
and writing YAML data.

=back

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut

=head1 LICENSE

Copyright (C) 2022, Awncorp, C<awncorp@cpan.org>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Apache license version 2.0.

=cut