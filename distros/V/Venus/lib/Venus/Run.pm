package Venus::Run;

use 5.018;

use strict;
use warnings;

use Venus::Class 'base';

base 'Venus::Task';

use Venus;

our $NAME = __PACKAGE__;
our $FILE = '.vns.pl';

# HOOKS

sub _print {
  do {local $| = 1; CORE::print(@_, "\n")}
}

sub _prompt {
  do {local $\ = ''; local $_ = <STDIN>; chomp; $_}
}

# METHODS

state $args = {
  'command' => {
    help => 'Command to run',
    required => 1,
  }
};

sub args {

  return $args;
}

state $cmds = {
  'func' => {
    help => 'Register function',
    arg => 'command',
  },
  'help' => {
    help => 'Display help and usages',
    arg => 'command',
  },
  'init' => {
    help => 'Initialize the configuration file',
    arg => 'command',
  },
  'with' => {
    help => 'Register subcommand',
    arg => 'command',
  },
};

sub cmds {

  return $cmds;
}

sub conf {
  my ($self) = @_;

  require Venus::Config;

  return Venus::Config->read_file($self->file)->value;
}

sub file {
  my $base = $FILE =~ s/\.\w+$//r;

  return $ENV{VENUS_FILE} || (grep -f, map "$base.$_", qw(yaml yml json js perl pl))[0]
}

state $footer = <<"EOF";
Config:

Here is an example configuration in YAML (e.g. in .vns.yaml).

  ---
  data:
    ECHO: true
  exec:
    cpan: cpanm -llocal -qn
    deps: cpan --installdeps .
    each: \$PERL -MVenus=log -nE
    exec: \$PERL -MVenus=log -E
    okay: \$PERL -c
    repl: \$PERL -dE0
    says: exec "map log(eval), \@ARGV"
    test: \$PROVE
  libs:
  - -Ilib
  - -Ilocal/lib/perl5
  path:
  - bin
  - dev
  - local/bin
  perl:
    perl: perl
    prove: prove
  vars:
    PERL: perl
    PROVE: prove

Examples:

Here are examples usages using the example YAML configuration.

  # Mint a new configuration file
  vns init

  # Install a distribution
  vns cpan \$DIST

  # Install dependencies in the CWD
  vns deps

  # Check that a package can be compiled
  vns okay \$FILE

  # Use the Perl debugger as a REPL
  vns repl

  # Evaluate arbitrary Perl expressions
  vns exec ...

  # Test the Perl project in the CWD
  vns test t

Copyright 2022-2023, Vesion $Venus::VERSION, The Venus "AUTHOR" and "CONTRIBUTORS"

More information on "vns" and/or the "Venus" standard library, visit
https://p3rl.org/vns.
EOF

sub footer {

  return $footer;
}

sub handler {
  my ($self, $data) = @_;

  my $help = $data->{help};
  my $next = $data->{command};

  return $self->okay if !$help && !$next;

  return $self->handler_for_help($data) if (!$next && $help) || (lc($next) eq 'help');

  return $self->handler_for_func($data) if lc($next) eq 'func';

  return $self->handler_for_with($data) if lc($next) eq 'with';

  return $self->handler_for_init($data) if lc($next) eq 'init';

  return $self->handler_for_exec($data);
}

sub handler_for_exec {
  my ($self, $data) = @_;

  my $code = sub {
    my $command = _vars(join ' ', @_);

    $self->log_info('Using:', $command) if $ENV{ECHO};

    my $error = $self->catch('system', $command);

    $self->log_error("Error running command! $command") if $ENV{ECHO} && $error;

    return $error ? false : true;
  };

  return $self->exit(undef, sub{_exec($code, $self->conf, @{$self->data})});
}

sub handler_for_func {
  my ($self, $data) = @_;

  my ($func, $name, $path) = @{$self->cli->data};

  require Venus::Path;

  $path = Venus::Path->new($path)->absolute;

  return $self->fail if !$func;

  if (!$name) {
    return $self->fail(sub{$self->log_error("No function name provided")});
  }

  if (!$path) {
    return $self->fail(sub{$self->log_error("No function path provided")});
  }

  if (!$path->is_file) {
    return $self->fail(sub{$self->log_error("Function path provided doesn't exist")});
  }

  my $command = _vars(join ' ', $func, $name, $path);

  $self->log_info('Using:', $command) if $ENV{ECHO};

  my $conf = $self->conf;

  if (exists $conf->{func}->{$name}) {
    return $self->fail(sub{$self->log_error("Function $name already exists")});
  }

  $conf->{func}->{$name} = "$path";

  my $file = $self->file;

  require Venus::Config;

  Venus::Config->new($conf)->write_file($file);

  return $self->okay('log_info', "Function $name registered in file $file");
}

sub handler_for_help {
  my ($self, $data) = @_;

  my $conf = $self->conf;
  my $type = $self->data->[1];

  if (exists $conf->{help} && exists $conf->{help}{$type}) {
    return $self->fail(sub{$self->log_info($conf->{help}{$type})})
  }
  else {
    return $self->fail(sub{$self->log_info($self->help)});
  }
}

sub handler_for_init {
  my ($self, $data) = @_;

  my $file = $self->file;

  return $self->fail('log_error', "Already using $file") if $file && -f $file;

  $file ||= $FILE;

  require Venus::Config;

  my $init = $self->init;

  Venus::Config->new($self->init)->write_file($file);

  return $self->okay('log_info', "Initialized with generated file $file");
}

sub handler_for_with {
  my ($self, $data) = @_;

  my ($with, $name, $path) = @{$self->cli->data};

  require Venus::Path;

  $path = Venus::Path->new($path)->absolute;

  return $self->fail if !$with;

  if (!$name) {
    return $self->fail(sub{$self->log_error("No subcommand name provided")});
  }

  if (!$path) {
    return $self->fail(sub{$self->log_error("No subcommand path provided")});
  }

  if (!$path->is_file) {
    return $self->fail(sub{$self->log_error("Subcommand path provided doesn't exist")});
  }

  my $command = _vars(join ' ', $with, $name, $path);

  $self->log_info('Using:', $command) if $ENV{ECHO};

  my $conf = $self->conf;

  if (exists $conf->{with}->{$name}) {
    return $self->fail(sub{$self->log_error("Subcommand $name already exists")});
  }

  $conf->{with}->{$name} = "$path";

  my $file = $self->file;

  require Venus::Config;

  Venus::Config->new($conf)->write_file($file);

  return $self->okay('log_info', "Subcommand $name registered in file $file");
}

state $init = {
  data => {
    ECHO => 1,
  },
  exec => {
    brew => 'perlbrew',
    cpan => 'cpanm -llocal -qn',
    docs => 'perldoc',
    each => 'shim -nE',
    edit => '$EDITOR $VENUS_FILE',
    eval => 'shim -E',
    exec => '$PERL',
    info => '$PERL -V',
    lint => 'perlcritic',
    okay => '$PERL -c',
    repl => '$REPL',
    reup => 'cpanm -qn Venus',
    says => 'eval "map log(eval), @ARGV"',
    shim => '$PERL -MVenus=true,false,log',
    test => '$PROVE',
    tidy => 'perltidy',
  },
  libs => [
    '-Ilib',
    '-Ilocal/lib/perl5',
  ],
  path => [
    'bin',
    'dev',
    'local/bin',
  ],
  perl => {
    perl => 'perl',
    prove => 'prove',
  },
  vars => {
    PERL => 'perl',
    PROVE => 'prove',
    REPL => '$PERL -dE0',
  },
};

sub init {

  return $init;
}

sub name {

  return $ENV{VENUS_TASK_NAME} || $NAME;
}

state $opts = {
  'help' => {
    help => 'Show help information',
  }
};

sub opts {

  return $opts;
}

# ROUTINES

sub _exec {
  my ($code, $conf, @data) = @_;

  return () if !@data;

  $conf = _set_conf($conf);

  my %ORIG_ENV = %ENV;

  _set_vars($conf);

  _set_path($conf);

  _set_libs($conf);

  _set_vars($conf);

  my $result;

  for my $step (_flow($conf, @data)) {
    my ($prog, @args) = @{$step};

    ($result = $code->($prog, @args)) ? next : last if $prog;
  }

  %ENV = %ORIG_ENV;

  return $result;
}

sub _find {
  my ($seen, $conf, @data) = @_;

  return () if !@data;

  @data = map _split($_), @data;

  my @item = shift @data;

  @item = (_find_in_exec($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_find($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_flow($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_func($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_perl($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_task($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_vars($seen, $conf, @item));

  if (@item > 1) {
    unshift @data, @item; @item = shift @data;
  }

  @item = (_find_in_with($seen, $conf, @item));

  if (@item > 1) {
    shift @data; unshift @data, @item; @item = shift @data;
  }

  return (@item, @data);
}

sub _find_in_exec {
  my ($seen, $conf, $item) = @_;

  return $conf->{exec}
    ? (
    $conf->{exec}{$item}
    ? (do {
      my $value = $conf->{exec}{$item};
      ($value eq $item)
        ? ($value)
        : (_find_in_seen($seen, $conf, 'exec', $item, $value));
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_find {
  my ($seen, $conf, $item) = @_;

  return $conf->{find}
    ? (
    $conf->{find}{$item}
    ? (do {
      my $value = $conf->{find}{$item};
      ($value eq $item)
        ? ($value)
        : (_find_in_seen($seen, $conf, 'find', $item, $value));
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_flow {
  my ($seen, $conf, $item) = @_;

  return $conf->{flow}
    ? (
    $conf->{flow}{$item}
    ? (do {
      my $value = $conf->{flow}{$item};
      join ' && ', map +(join(' ', _exec(sub{}, $conf, $_))), @{$value}
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_func {
  my ($seen, $conf, $item) = @_;

  return $conf->{func}
    ? (
    $conf->{func}{$item}
    ? (do {
      my $value = _vars($conf->{func}{$item});
      ('perl', '-E', "(do \"$value\")->(\\\@ARGV)")
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_perl {
  my ($seen, $conf, $item) = @_;

  return $conf->{perl}
    ? (
    $conf->{perl}{$item}
    ? (do {
      my $value = $conf->{perl}{$item};
      ($value eq $item)
        ? ($value)
        : (_find_in_seen($seen, $conf, 'perl', $item, $value));
    },
      _load_from_libs($seen, $conf),
      _load_from_load($seen, $conf),
    )
    : ($item)
    )
    : ($item);
}

sub _find_in_task {
  my ($seen, $conf, $item) = @_;

  return $conf->{task}
    ? (
    $conf->{task}{$item}
    ? (do {
      $ENV{VENUS_TASK_AUTO} = 1;
      my $value = $conf->{task}{$item};
      ($value eq $item)
        ? ($value)
        : (_find_in_seen($seen, $conf, 'task', $item, $value));
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_vars {
  my ($seen, $conf, $item) = @_;

  my ($name) = $item =~ /\$?(.*)/;

  return $conf->{vars}
    ? (
    $conf->{vars}{$name}
    ? (do {
      my $value = $conf->{vars}{$name};
      ($value eq $name)
        ? ($value)
        : (_find_in_seen($seen, $conf, 'vars', $name, $value));
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_with {
  my ($seen, $conf, $item) = @_;

  return $conf->{with}
    ? (
    $conf->{with}{$item}
    ? (do {
      $ENV{ECHO} = 0;
      $ENV{VENUS_FILE} = _vars($conf->{with}{$item});
      $ENV{VENUS_TASK_NAME} || 'vns';
    })
    : ($item)
    )
    : ($item);
}

sub _find_in_seen {
  my ($seen, $conf, $item, $name, $value) = @_;

  return $seen->{$item}{$name}++
    ? ((_split($value))[0])
    : (_find($seen, $conf, $value));
}

sub _flow {
  my ($conf, @data) = @_;

  return () if !@data;

  my $item = shift @data;

  return $conf->{flow}
    ? (
    $conf->{flow}{$item}
    ? (do {
     (map _flow($conf, $_, @data), @{$conf->{flow}{$item}});
    })
    : (_prep($conf, $item, @data))
    )
    : (_prep($conf, $item, @data));
}

sub _libs {
  my ($conf) = @_;

  return (map /^-I\w*?(.*)$/, _load_from_libs({}, $conf));
}

sub _load_from_libs {
  my ($seen, $conf) = @_;

  return !$seen->{libs}++ ? ($conf->{libs} ? (@{$conf->{libs}}) : ()) : ();
}

sub _load_from_load {
  my ($seen, $conf) = @_;

  return !$seen->{load}++ ? ($conf->{load} ? (@{$conf->{load}}) : ()) : ();
}

sub _make {
  my ($conf, $name) = @_;

  my ($item, @data) = _find({}, $conf, $name);

  require Venus::Os;

  my $path = Venus::Os->which($item);

  return (($path ? $path : $item), @data);
}

sub _prep {
  my ($conf, @data) = @_;

  my @args = grep defined, _make($conf, shift(@data)), @data;

  my $prog = _vars(shift(@args));

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
    if ($args[$i] =~ /^\$[A-Z]\w+$/) {
      $args[$i] = _vars($args[$i]);
      next;
    }
    if ($args[$i] =~ /^\$\((.*)\)$/) {
      if ($1) {
        $args[$i] = "\$(@{[@{_prep($conf, $1)}]})";
      }
      next;
    }
    $args[$i] = Venus::Os->quote($args[$i]);
  }

  return [$prog ? ($prog, @args) : ()];
}

sub _split {
  my ($text) = @_;

  return (grep length, ($text // '') =~ /(?x)(?:"([^"]*)"|([^\s]*))\s?/g);
}

sub _set_conf {
  my ($conf) = @_;

  $conf = Venus::merge(Venus::Config->read_file(_vars($_))->value, $conf)
    for (
      $conf->{from}
      ? ((ref $conf->{from} eq 'ARRAY') ? (@{$conf->{from}}) : ($conf->{from}))
      : ()
    );

  if (exists $conf->{when}) {
    require Venus::Os;

    my $type = Venus::Os->type;

    if (exists $conf->{when}{$type}) {
      $conf = Venus::merge($conf, $conf->{when}{$type});
    }
  }

  return $conf;
}

sub _set_libs {
  my ($conf) = @_;

  require Venus::Os;
  require Venus::Path;

  my %seen;
  $ENV{PERL5LIB} = join((Venus::Os->is_win ? ';' : ':'),
    (grep !$seen{$_}++, map Venus::Path->new(_vars($_))->absolute, _libs($conf)));

  return $conf;
}

sub _set_path {
  my ($conf) = @_;

  require Venus::Os;
  require Venus::Path;

  if (my $path = $conf->{path}) {
    $ENV{PATH} = join((Venus::Os->is_win ? ';' : ':'),
      (map Venus::Path->new(_vars($_))->absolute, @{$conf->{path}}), $ENV{PATH});
  }

  return $conf;
}

sub _set_vars {
  my ($conf) = @_;

  if (my $data = $conf->{data}) {
    for my $key (sort keys %{$data}) {
      $ENV{$key} = join(' ', grep defined, $data->{$key});
    }
  }

  if (my $vars = $conf->{vars}) {
    for my $key (sort keys %{$vars}) {
      $ENV{$key} = join(' ', grep defined, @{_prep($conf, $vars->{$key})});
    }
  }

  if (my $asks = $conf->{asks}) {
    for my $key (sort keys %{$asks}) {
      next if defined $ENV{$key}; _print $asks->{$key}; $ENV{$key} = _prompt;
    }
  }

  return $conf;
}

sub _vars {
  (($_[0] // '') =~ s{\$([A-Z_]+)}{$ENV{$1}//"\$".$1}egr)
}

# AUTORUN

auto Venus::Run sub {
  my ($self) = @_;

  my $tryer = $self->tryer;

  $tryer->catch('Venus::Json::Error', sub {
    $self->log_error($_->render);
  });

  $tryer->catch('Venus::Path::Error', sub {
    $self->log_error($_->render);
  });

  $tryer->catch('Venus::Yaml::Error', sub {
    $self->log_error($_->render);
  });

  return $self;
};

1;



=head1 NAME

Venus::Run - Runner Class

=cut

=head1 ABSTRACT

Runner Class for Perl 5

=cut

=head1 SYNOPSIS

  package main;

  use Venus::Run;

  my $run = Venus::Run->new;

  # bless({...}, 'Venus::Run')

=cut

=head1 DESCRIPTION

This package is a subclass of L<Venus::Task> which provides a command execution
system. This package loads the configuration file used for defining tasks (i.e.
command-line operations) which can recursively resolve, injects environment
variables, resets the C<PATH> and C<PERL5LIB> variables where appropriate, and
executes the tasks by name. See L<vns> for an executable file which loads this
package and provides the CLI. See L</FEATURES> for usage and configuration
information.

=cut

=head1 INHERITS

This package inherits behaviors from:

L<Venus::Task>

=cut

=head1 METHODS

This package provides the following methods:

=cut

=head2 args

  args() (hashref)

The args method returns the task argument declarations.

I<Since C<2.91>>

=over 4

=item args example 1

  # given: synopsis

  package main;

  my $args = $run->args;

  # {
  #   'command' => {
  #     help => 'Command to run',
  #     required => 1,
  #   }
  # }

=back

=cut

=head2 cmds

  cmds() (hashref)

The cmds method returns the task command declarations.

I<Since C<2.91>>

=over 4

=item cmds example 1

  # given: synopsis

  package main;

  my $cmds = $run->cmds;

  # {
  #   'help' => {
  #     help => 'Display help and usages',
  #     arg => 'command',
  #   },
  #   'init' => {
  #     help => 'Initialize the configuration file',
  #     arg => 'command',
  #   },
  # }

=back

=cut

=head2 conf

  conf() (hashref)

The conf method loads the configuration file returned by L</file>, then decodes
and returns the information as a hashref.

I<Since C<2.91>>

=over 4

=item conf example 1

  # given: synopsis

  package main;

  my $conf = $run->conf;

  # {}

=back

=over 4

=item conf example 2

  # given: synopsis

  package main;

  local $ENV{VENUS_FILE} = 't/conf/.vns.pl';

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 3

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.yaml file

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 4

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.yml file

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 5

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.json file

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 6

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.js file

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 7

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.perl file

  my $conf = $run->conf;

  # {...}

=back

=over 4

=item conf example 8

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.pl file

  my $conf = $run->conf;

  # {...}

=back

=cut

=head2 file

  file() (string)

The file method returns the configuration file specified in the C<VENUS_FILE>
environment variable, or the discovered configuration file in the current
directory. The default name for a configuration file is in the form of
C<.vns.*>. Configuration files will be decoded based on their file extensions.
Valid file extensions are C<yaml>, C<yml>, C<json>, C<js>, C<perl>, and C<pl>.

I<Since C<2.91>>

=over 4

=item file example 1

  # given: synopsis

  package main;

  my $file = $run->file;

  # undef

=back

=over 4

=item file example 2

  # given: synopsis

  package main;

  local $ENV{VENUS_FILE} = 't/conf/.vns.pl';

  my $file = $run->file;

  # "t/conf/.vns.pl"

=back

=over 4

=item file example 3

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.yaml file

  my $file = $run->file;

  # ".vns.yaml"

=back

=over 4

=item file example 4

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.yml file

  my $file = $run->file;

  # ".vns.yml"

=back

=over 4

=item file example 5

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.json file

  my $file = $run->file;

  # ".vns.json"

=back

=over 4

=item file example 6

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.js file

  my $file = $run->file;

  # ".vns.js"

=back

=over 4

=item file example 7

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.perl file

  my $file = $run->file;

  # ".vns.perl"

=back

=over 4

=item file example 8

  # given: synopsis

  package main;

  # e.g. current directory has only a .vns.pl file

  my $file = $run->file;

  # ".vns.pl"

=back

=cut

=head2 footer

  footer() (string)

The footer method returns examples and usage information used in usage text.

I<Since C<2.91>>

=over 4

=item footer example 1

  # given: synopsis

  package main;

  my $footer = $run->footer;

  # "..."

=back

=cut

=head2 handler

  handler(hashref $data) (any)

The handler method processes the data provided and executes the request then
returns the invocant unless the program is exited.

I<Since C<2.91>>

=over 4

=item handler example 1

  package main;

  use Venus::Run;

  my $run = Venus::Run->new;

  $run->execute;

  # ()

=back

=over 4

=item handler example 2

  package main;

  use Venus::Run;

  my $run = Venus::Run->new(['help']);

  $run->execute;

  # ()

=back

=over 4

=item handler example 3

  package main;

  use Venus::Run;

  my $run = Venus::Run->new(['--help']);

  $run->execute;

  # ()

=back

=over 4

=item handler example 4

  package main;

  use Venus::Run;

  my $run = Venus::Run->new(['init']);

  $run->execute;

  # ()

=back

=over 4

=item handler example 5

  package main;

  use Venus::Run;

  # on linux

  my $run = Venus::Run->new(['echo']);

  $run->execute;

  # ()

  # i.e. ['echo']

=back

=over 4

=item handler example 6

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   cpan: cpanm -llocal -qn
  #
  # ...

  my $run = Venus::Run->new(['cpan', 'Venus']);

  $run->execute;

  # ()

  # i.e. cpanm '-llocal' '-qn' Venus

=back

=over 4

=item handler example 7

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   cpan: cpanm -llocal -qn
  #   deps: cpan --installdeps .
  #
  # ...

  my $run = Venus::Run->new(['cpan', '--installdeps', '.']);

  $run->execute;

  # ()

  # i.e. cpanm '-llocal' '-qn' '--installdeps' '.'

=back

=over 4

=item handler example 8

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   okay: $PERL -c
  #
  # ...
  #
  # libs:
  # - -Ilib
  # - -Ilocal/lib/perl5
  #
  # ...
  #
  # vars:
  #   PERL: perl
  #
  # ...

  my $run = Venus::Run->new(['okay', 'lib/Venus.pm']);

  $run->execute;

  # ()

  # i.e. perl '-Ilib' '-Ilocal/lib/perl5' '-c'

=back

=over 4

=item handler example 9

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   repl: $REPL
  #
  # ...
  #
  # libs:
  # - -Ilib
  # - -Ilocal/lib/perl5
  #
  # ...
  #
  # vars:
  #   PERL: perl
  #   REPL: $PERL -dE0
  #
  # ...

  my $run = Venus::Run->new(['repl']);

  $run->execute;

  # ()

  # i.e. perl '-Ilib' '-Ilocal/lib/perl5' '-dE0'

=back

=over 4

=item handler example 10

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   exec: $PERL
  #
  # ...
  #
  # libs:
  # - -Ilib
  # - -Ilocal/lib/perl5
  #
  # ...
  #
  # vars:
  #   PERL: perl
  #
  # ...

  my $run = Venus::Run->new(['exec', '-MVenus=date', 'say date']);

  $run->execute;

  # ()

  # i.e. perl '-Ilib' '-Ilocal/lib/perl5' '-MVenus=date' 'say date'

=back

=over 4

=item handler example 11

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   test: $PROVE
  #
  # ...
  #
  # libs:
  # - -Ilib
  # - -Ilocal/lib/perl5
  #
  # ...
  #
  # vars:
  #   PROVE: prove
  #
  # ...

  my $run = Venus::Run->new(['test', 't']);

  $run->execute;

  # ()

  # i.e. prove '-Ilib' '-Ilocal/lib/perl5' t

=back

=over 4

=item handler example 12

  package main;

  use Venus::Run;

  # on linux

  my $run = Venus::Run->new(['echo', 1, '|', 'less']);

  $run->execute;

  # ()

  # i.e. echo 1 | less

=back

=over 4

=item handler example 13

  package main;

  use Venus::Run;

  # on linux

  my $run = Venus::Run->new(['echo', 1, '&&', 'echo', 2]);

  $run->execute;

  # ()

  # i.e. echo 1 && echo 2

=back

=over 4

=item handler example 14

  package main;

  use Venus::Run;

  # on linux

  local $ENV{VENUS_FILE} = 't/conf/from.perl';

  # in config
  #
  # ---
  # from:
  # - /path/to/parent
  #
  # ...
  #
  # exec:
  #   mypan: cpan -M https://pkg.myapp.com

  # in config (/path/to/parent)
  #
  # ---
  # exec:
  #   cpan: cpanm -llocal -qn
  #
  # ...

  my $run = Venus::Run->new(['mypan']);

  $run->execute;

  # ()

  # i.e. cpanm '-llocal' '-qn' '-M' 'https://pkg.myapp.com'

=back

=over 4

=item handler example 15

  package main;

  use Venus::Run;

  # on linux

  local $ENV{VENUS_FILE} = 't/conf/with.perl';

  # in config
  #
  # ---
  # with:
  #   psql: /path/to/other
  #
  # ...

  # in config (/path/to/other)
  #
  # ---
  # exec:
  #   backup: pg_backupcluster
  #   restore: pg_restorecluster
  #
  # ...

  my $run = Venus::Run->new(['psql', 'backup']);

  $run->execute;

  # ()

  # i.e. vns backup

=back

=over 4

=item handler example 16

  package main;

  use Venus::Run;

  # on linux

  local $ENV{VENUS_FILE} = 't/conf/with.perl';

  # in config
  #
  # ---
  # with:
  #   psql: /path/to/other
  #
  # ...

  # in config (/path/to/other)
  #
  # ---
  # exec:
  #   backup: pg_backupcluster
  #   restore: pg_restorecluster
  #
  # ...

  my $run = Venus::Run->new(['psql', 'backup']);

  $run->execute;

  # VENUS_FILE=t/conf/psql.perl vns backup

  local $ENV{VENUS_FILE} = 't/conf/psql.perl';

  $run = Venus::Run->new(['backup']);

  $run->execute;

  # ()

  # i.e. pg_backupcluster

=back

=over 4

=item handler example 17

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # exec:
  #   cpan: cpanm -llocal -qn
  #
  # ...
  #
  # flow:
  #   setup-term:
  #   - cpan Term::ReadKey
  #   - cpan Term::ReadLine::Gnu
  #
  # ...

  local $ENV{VENUS_FILE} = 't/conf/flow.perl';

  my $run = Venus::Run->new(['setup-term']);

  $run->execute;

  # ()

  # i.e.
  # cpanm '-llocal' '-qn' 'Term::ReadKey'
  # cpanm '-llocal' '-qn' 'Term::ReadLine::Gnu'

=back

=over 4

=item handler example 18

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # asks:
  #   PASS: What's the password
  #
  # ...

  local $ENV{VENUS_FILE} = 't/conf/asks.perl';

  my $run = Venus::Run->new(['echo', '$PASS']);

  $run->execute;

  # ()

  # i.e. echo '$PASS'

=back

=over 4

=item handler example 19

  package main;

  use Venus::Run;

  # on linux

  # in config
  #
  # ---
  # func:
  #   dump: /path/to/dump.pl
  #
  # ...

  # in dump.pl (/path/to/dump.pl)
  #
  # sub {
  #   my ($args) = @_;
  #
  #   ...
  # }

  local $ENV{VENUS_FILE} = 't/conf/func.perl';

  my $run = Venus::Run->new(['dump', '--', 'hello']);

  $run->execute;

  # ()

  # i.e. perl -Ilib ... -E '(do "./t/path/etc/dump.pl")->(\@ARGV)' '--' hello

=back

=over 4

=item handler example 20

  package main;

  use Venus::Run;

  # on linux

  local $ENV{VENUS_FILE} = 't/conf/when.perl';

  # in config
  #
  # ---
  # exec:
  #   name: echo $OSNAME
  #
  # ...
  # when:
  #   is_lin:
  #     data:
  #       OSNAME: LINUX
  #   is_win:
  #     data:
  #       OSNAME: WINDOW
  #
  # ...

  my $run = Venus::Run->new(['name']);

  $run->execute;

  # ()

  # i.e. echo $OSNAME

  # i.e. echo LINUX

=back

=over 4

=item handler example 21

  package main;

  use Venus::Run;

  # on mswin32

  local $ENV{VENUS_FILE} = 't/conf/when.perl';

  # in config
  #
  # ---
  # exec:
  #   name: echo $OSNAME
  #
  # ...
  # when:
  #   is_lin:
  #     data:
  #       OSNAME: LINUX
  #   is_win:
  #     data:
  #       OSNAME: WINDOW
  #
  # ...

  my $run = Venus::Run->new(['name']);

  $run->execute;

  # ()

  # i.e. echo $OSNAME

  # i.e. echo WINDOWS

=back

=over 4

=item handler example 22

  package main;

  use Venus::Run;

  # on linux

  local $ENV{VENUS_FILE} = 't/conf/help.perl';

  # in config
  #
  # ---
  # exec:
  #   exec: perl -c
  #
  # ...
  # help:
  #   exec: Usage: perl -c <FILE>
  #
  # ...

  my $run = Venus::Run->new(['help', 'exec']);

  $run->execute;

  # ()

  # i.e. Usage: perl -c <FILE>

=back

=over 4

=item handler example 23

  package main;

  use Venus::Run;

  my $run = Venus::Run->new(['func', 'dump', 't/path/etc/dump.pl']);

  $run->execute;

  # ()

=back

=over 4

=item handler example 24

  package main;

  use Venus::Run;

  my $run = Venus::Run->new(['with', 'asks', 't/conf/asks.perl']);

  $run->execute;

  # ()

=back

=cut

=head2 init

  init() (hashref)

The init method returns the default configuration to be used when initializing
the system with a new configuration file.

I<Since C<2.91>>

=over 4

=item init example 1

  # given: synopsis

  package main;

  my $init = $run->init;

  # {
  #   data => {
  #     ECHO => 1,
  #   },
  #   exec => {
  #     brew => 'perlbrew',
  #     cpan => 'cpanm -llocal -qn',
  #     docs => 'perldoc',
  #     each => 'shim -nE',
  #     edit => '$EDITOR $VENUS_FILE',
  #     eval => 'shim -E',
  #     exec => '$PERL',
  #     info => '$PERL -V',
  #     lint => 'perlcritic',
  #     okay => '$PERL -c',
  #     repl => '$REPL',
  #     reup => 'cpanm -qn Venus',
  #     says => 'eval "map log(eval), @ARGV"',
  #     shim => '$PERL -MVenus=true,false,log',
  #     test => '$PROVE',
  #     tidy => 'perltidy',
  #   },
  #   libs => [
  #     '-Ilib',
  #     '-Ilocal/lib/perl5',
  #   ],
  #   path => [
  #     './bin',
  #     './dev',
  #     './local/bin',
  #   ],
  #   perl => {
  #     perl => 'perl',
  #     prove => 'prove',
  #   },
  #   vars => {
  #     PERL => 'perl',
  #     PROVE => 'prove'
  #     REPL => '$PERL -dE0'
  #   },
  # }

=back

=cut

=head2 name

  name() (string)

The name method returns the default name for the task. This is used in usage
text and can be controlled via the C<VENUS_TASK_NAME> environment variable, or
the C<NAME> package variable.

I<Since C<2.91>>

=over 4

=item name example 1

  # given: synopsis

  package main;

  my $name = $run->name;

  # "Venus::Run"

=back

=over 4

=item name example 2

  # given: synopsis

  package main;

  local $ENV{VENUS_TASK_NAME} = 'venus-runner';

  my $name = $run->name;

  # "venus-runner"

=back

=over 4

=item name example 3

  # given: synopsis

  package main;

  local $Venus::Run::NAME = 'venus-runner';

  my $name = $run->name;

  # "venus-runner"

=back

=cut

=head2 opts

  opts() (hashref)

The opts method returns the task options declarations.

I<Since C<2.91>>

=over 4

=item opts example 1

  # given: synopsis

  package main;

  my $opts = $run->opts;

  # {
  #   'help' => {
  #     help => 'Show help information',
  #   }
  # }

=back

=cut

=head1 FEATURES

This package provides the following features:

=cut

=over 4

=item config

The CLI provided by this package operates on a configuration file, typically
having a base name of C<.vns> with a Perl, JSON, or YAML file extension. Here
is an example of a configuration file using YAML with the filename
C<.vns.yaml>.

  ---
  data:
    ECHO: true
  exec:
    cpan: cpanm -llocal -qn
    okay: $PERL -c
    repl: $PERL -dE0
    says: $PERL -E "map log(eval), @ARGV"
    test: $PROVE
  libs:
  - -Ilib
  - -Ilocal/lib/perl5
  load:
  - -MVenus=true,false
  path:
  - ./bin
  - ./dev
  - -Ilocal/bin
  perl:
    perl: perl
    prove: prove
  vars:
    PERL: perl
    PROVE: prove

=back

=over 4

=item config-asks

  ---
  asks:
    HOME: Enter your home dir

The configuration file's C<asks> section provides a list of key/value pairs
where the key is the name of the environment variable and the value is used as
the message used by the CLI to prompt for input if the environment variable is
not defined.

=back

=over 4

=item config-data

  ---
  data:
    ECHO: true

The configuration file's C<data> section provides a non-dynamic list of
key/value pairs that will be used as environment variables.

=back

=over 4

=item config-exec

  ---
  exec:
    okay: $PERL -c

The configuration file's C<exec> section provides the main dynamic tasks which
can be recursively resolved and expanded.

=back

=over 4

=item config-find

  ---
  find:
    cpanm: /usr/local/bin/cpanm

The configuration file's C<find> section provides aliases which can be
recursively resolved and expanded for use in other tasks.

=back

=over 4

=item config-flow

  ---
  flow:
    deps:
    - cpan Term::ReadKey
    - cpan Term::ReadLine::Gnu

The configuration file's C<flow> section provides chainable tasks which are
recursively resolved and expanded from other tasks.

=back

=over 4

=item config-from

  ---
  from:
  - /usr/share/vns/.vns.yaml

The configuration file's C<from> section provides paths to other configuration
files which will be merged before execution allowing the inheritance of of
configuration values.

=back

=over 4

=item config-func

  ---
  func:
    build: ./scripts/build.pl

The configuration file's C<func> section provides a list of static key/value
pairs where the key is the "subcommand" passed to the runner as the first
arugment, and the value is the Perl script that will be loaded and executed.
The Perl script is expected to return a subroutine reference and will be passed
an array reference to the arguments provided.

=back

=over 4

=item config-help

  ---
  help:
    build: Usage: vns build [<option>]

The configuration file's C<help> section provides a list of static key/value
pairs where the key is the "subcommand" to display help text for, and the value
is the help text to be displayed.

=back

=over 4

=item config-libs

  ---
  libs:
  - -Ilib
  - -Ilocal/lib/perl5

The configuration file's C<libs> section provides a list of C<-I/path/to/lib>
"include" statements that will be automatically added to tasks expanded from
the C<perl> section.

=back

=over 4

=item config-load

  ---
  load:
  - -MVenus=true,false

The configuration file's C<load> section provides a list of C<-MPackage>
"import" statements that will be automatically added to tasks expanded from the
C<perl> section.

=back

=over 4

=item config-path

  ---
  path:
  - ./bin
  - ./dev
  - -Ilocal/bin

The configuration file's C<path> section provides a list of paths to be
prepended to the C<PATH> environment variable which allows programs to be
found.

=back

=over 4

=item config-perl

  ---
  perl:
    perl: perl

The configuration file's C<perl> section provides the dynamic perl tasks which
can serve as tasks with default commands (with options) and which can be
recursively resolved and expanded.

=back

=over 4

=item config-task

  ---
  task:
    setup: $PERL -MMyApp::Task::Setup -E0 --

The configuration file's C<task> section provides the dynamic perl tasks which
"load" L<Venus::Task> derived packages, and which can be recursively resolved
and expanded. These tasks will typically take the form of C<perl -Ilib
-MMyApp::Task -E0 --> and will be automatically executed as a CLI.

=back

=over 4

=item config-vars

  ---
  vars:
    PERL: perl

The configuration file's C<vars> section provides a list of dynamic key/value
pairs that can be recursively resolved and expanded and will be used as
environment variables.

=back

=over 4

=item config-when

  ---
  when:
    is_lin:
      data:
        OSNAME: LINUX
    is_win:
      data:
        OSNAME: WINDOWS

The configuration file's C<when> section provides a configuration tree to be
merged with the existing configuration based on the name current operating
system. The C<is_$name> key should correspond to one of the types specified by
L<Venus::Os/type>.

=back

=over 4

=item config-with

  ---
  with:
    psql: ./psql-tools/.vns.yml

The configuration file's C<with> section provides a list of static key/value
pairs where the key is the "subcommand" passed to the runner as the first
arugment, and the value is the configuration file where the subcommand task
definitions are defined which the runner dispatches to.

=back

=over 4

=item vns-cli

Here are example usages of the configuration file mentioned, executed by the
L<vns> CLI, which is simply an executable file which loads this package.

  # Mint a new configuration file
  vns init

  ...

  # Mint a new JSON configuration file
  VENUS_FILE=.vns.json vns init

  # Mint a new YAML configuration file
  VENUS_FILE=.vns.yaml vns init

  ...

  # Install a distribution
  vns cpan $DIST

  # i.e.
  # cpanm --llocal -qn $DIST

  # Check that a package can be compiled
  vns okay $FILE

  # i.e.
  # perl -Ilib -Ilocal/lib/perl5 -c $FILE

  # Use the Perl debugger as a REPL
  vns repl

  # i.e.
  # perl -Ilib -Ilocal/lib/perl5 -dE0

  # Evaluate arbitrary Perl expressions
  vns exec ...

  # i.e.
  # perl -Ilib -Ilocal/lib/perl5 -MVenus=log -E $@

  # Test the Perl project in the CWD
  vns test t

  # i.e.
  # prove -Ilib -Ilocal/lib/perl5 t

=back

=head1 AUTHORS

Awncorp, C<awncorp@cpan.org>

=cut

=head1 LICENSE

Copyright (C) 2022, Awncorp, C<awncorp@cpan.org>.

This program is free software, you can redistribute it and/or modify it under
the terms of the Apache license version 2.0.

=cut