# NAME

CLI::Simple - a minimalist object oriented base class for CLI applications

# SYNOPSIS

    #!/usr/bin/env perl

    package MyScript;

    use strict;
    use warnings;

    use CLI::Simple::Constants qw(:booleans :chars);
    use CLI::Simple qw($AUTO_HELP $AUTO_DEFAULT);

    use parent qw(CLI::Simple);
    
    sub execute {
      my ($self) = @_;

      # retrieve a CLI option   
      my $file = $self->get_file;
      ...
    }
    
    sub list { 
      my ($self) = @_

      # retrieve a command argument
      my ($file) = $self->get_args();
      ...
    }

    sub main {

      # Disable auto-default for single commands, enable auto-help
      $AUTO_DEFAULT = 0;
      $AUTO_HELP = 1;

      my $cli = MyScript->new(
       option_specs    => [ qw( help format=s file=s) ],
       default_options => { format => 'json' }, # set some defaults
       extra_options   => [ qw( content ) ], # non-option, setter/getter
       commands        => { execute => \&execute, list => \&list,  }
       alias           => { options => { fmt => 'format' }, commands => { ls => 'list' } },
      );

      return $cli->run();
    }

    exit main();

    1;

# DESCRIPTION

Tired of writing the same 'ol boilerplate code for command line
scripts? Want a standard, simple way to create a Perl script that
takes options and commands?  `CLI::Simple` makes it easy to create
scripts that take _options_, _commands_ and _arguments_.

For common constant values (like `$TRUE`, `$DASH`, or `$SUCCESS`), see
[CLI::Simple::Constants](https://metacpan.org/pod/CLI%3A%3ASimple%3A%3AConstants), which pairs naturally with this module.

# VERSION

This documentation refers to version 1.0.12.

## Changes from Version 1.0.8

- New package variables $AUTO\_HELP and $AUTO\_DEFAULT

    These new package variables allow finer grained control over default
    behaviors when no command is provided on the command line. These
    changes were made to allow for a more flexible lifecycle. See ["The
    init-run Lifecycle"](#the-init-run-lifecycle).

    - In previous versions, by default, `CLI::Simple` would print help
    information if it was available and if there was no command provided
    on the command line. That behavior is now controlled by $AUTO\_HELP.
    - In previous versions, by default, `CLI::Simple` would run a
    default command if only one command was defined and there was no
    command on the command line. That behavior is now controlled by
    $AUTO\_DEFAULT.

## Features

- accept command line arguments ala [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)
- supports commands and command arguments
- automatically add a logger
- global or custom log levels per command
- easily add usage notes
- automatically create setter/getters for your script
- low dependency profile

Command line scripts often take _options_, sometimes a _command_ and
perhaps _arguments_ to those commands.  For example, consider the
script `myscript` that takes options and implements a few commands
(_send-message_, _receive-message_) that also take arguments.

    myscript [options] command args

or

    myscript command [options] args

Examples:

    myscript --foo bar --log-level debug send-message "Hello World" now

    myscript --bar --log-level info receive-message

Using `CLI::Simple` to implement this script looks like this...

    package MyScript;

    use parent qw(CLI::Simple);

    caller or __PACKAGE__->main();

    sub send_message {...}

    sub default {...}

    sub receive_message {...}
    
    sub main {
      return __PACKAGE__->new(
        option_specs => [
          qw(
            foo=s
            bar
            log-level
          )
        ],
        commands => {
          send    => \&send_message,
          receive => \&receive_message,
        },
      )->run;
    }

    1;

# PHILOSOPHY AND DESIGN PRINCIPLES

`CLI::Simple` is intentionally minimalist. It provides just enough
structure to build command-line tools with subcommands, option
parsing, and help handling -- but without enforcing any particular
framework or lifecycle.

## Not a Framework

This module is not [App::Cmd](https://metacpan.org/pod/App%3A%3ACmd), [MooseX::Getopt](https://metacpan.org/pod/MooseX%3A%3AGetopt), or a full
application toolkit.  Instead, it offers:

- An object-oriented base class with a clean `run()` dispatcher
- Command-line parsing via `Getopt::Long`
- Built-in logging via `Log::Log4perl`
- Subclass hooks like `init()` for setup and validation

The philosophy is: provide just enough infrastructure, then get out of your way.

## Validation, Defaults, and Configuration

`CLI::Simple` does not impose a validation model. You may:

- Use `Getopt::Long` features (e.g., type constraints, default values)
- Write your own validation logic in `init()`
- Throw exceptions, emit usage, or exit early at any point

The lifecycle is explicit and under your control. You decide how much structure
you want to add on top of it.

## When to Use

`CLI::Simple` is ideal for:

- Internal tools and admin scripts
- Bootstrapped CLIs where you don't want a framework
- Users who want to subclass a clean, minimal interface

For more advanced features - like command trees, plugin support, or interactive
CLI handling - consider heavier modules like [App::Cmd](https://metacpan.org/pod/App%3A%3ACmd), [CLI::Framework](https://metacpan.org/pod/CLI%3A%3AFramework), or
[MooX::Options](https://metacpan.org/pod/MooX%3A%3AOptions).

## The init-run Lifecycle

`CLI::Simple` is built on a flexible, two-phase lifecycle that 
separates application setup from command execution.

- **Phase 1: Initialization (`new` => `init`)**

    When your script calls `CLI::Simple->`new()>, the constructor parses
    all command-line arguments and then immediately calls your `init()` 
    method.

    Inside `init()`, your application has full access to the parsed options 
    and arguments. This phase is the ideal hook for all final setup tasks, 
    such as:

    - Validating command-line arguments.
    - Loading configuration files based on a `--config` option.
    - Dynamically overriding the command (e..g, `$self->command('new_default')`).
    - Performing any setup required **before** a command is run.

    This `init()` phase **always runs** as part of object construction.

- **Phase 2: Execution (`run`)**

    After the `new()` method returns your object, your script then calls
    the `run()` method. This method is responsible for dispatching to 
    the **currently set** command.

## "opt-in" Default Command

By design, `CLI::Simple` **does not impose a default command**.
This provides total flexibility for the application author:

- **You Can Set a Default:** If your application needs a default
command (e.g., to run `help` when no command is given), you can set
`$AUTO_HELP`, explicitly set the `default` command in the `command`
hash you pass to the constructor or uset `command()` to set one
inside the `init()` method.
- **You Can Have No Default:** If you do **not** set a default,
`run()` will simply do nothing and return cleanly if no command
is provided on the command line.

This "no default by default" behavior is what enables a powerful 
"setup-only" execution mode. A user can run your script _without_
specifying a command. This will:

- 1. Run the entire `new()` / `init()` phase, performing all setup.
- 2. Call `run()`, which will find no command and exit cleanly.

This provides an ideal hook for applications that need to perform
"on-demand initialization" (e.g., seeding a database, authenticating)
by checking for a specific flag inside `init()`, without also
triggering an unwanted command.

## `$AUTO_HELP` and `$AUTO_DEFAULT`

Two package variables can be used to further control the lifecycle. By
default, the framework provides no default command as explained in the
sections above. Some scripters may want default behaviors that assume
a command or provide usage if no command is provided.

- `$AUTO_HELP`

    Set the package variable `$AUTO_HELP` to a true value if you want
    `CLI::Simple` to provide help when no command is provided.

    default: false

- `$AUTO_DEFAULT`

    Set the package variable `$AUTO_DEFAULT` to a true value if you want
    `CLI::Simple` to automatically select a command if you have only 1
    command defined and no command is provided on the command line. When
    true, it will prepend the single command name to the argument list,
    allowing any subsequent arguments to be correctly parsed as args for
    that command.

    default: false

# CONSTANTS

`CLI::Simple` does not define its own constants directly, but it is often used
in conjunction with [CLI::Simple::Constants](https://metacpan.org/pod/CLI%3A%3ASimple%3A%3AConstants), which provides a collection of
exportable values commonly needed in command-line scripts.

These include:

- Boolean flags like `$TRUE`, `$FALSE`, `$SUCCESS`, and `$FAILURE`
- Common character tokens such as `$COLON`, `$DASH`, `$EQUALS_SIGN`, etc.
- Log level names compatible with [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl)

To use them in your script:

    use CLI::Simple::Constants qw(:all);

# ADDITIONAL NOTES

- All options are case insensitive
- See [CLI::Simple::Utils](https://metacpan.org/pod/CLI%3A%3ASimple%3A%3AUtils) to learn about some additional
utililities that are useful when writing scripts.

# METHODS AND SUBROUTINES

## new

    new( args )

Instantiates a new `CLI::Simple` instance, parses options, optionally
initializes logging, and makes options available via dynamically
generated accessors.

_Note: The `new()` constructor uses [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)'s `GetOptions`,
which directly modifies `@ARGV` by removing any recognized
options. The remaining elements of `@ARGV` are treated as the command
name and its arguments._

`args` is a hash or hash reference containing the following keys:

- abbreviations

    A boolean that determines whether abbreviated command names are allowed.

    When true, the `run()` method will treat the provided command as a prefix
    and compare it to the keys in the command hash. If exactly one match is
    found, it will be used. If more than one match is found, or if no match is
    found, `run()` will throw an exception.

    This allows for convenient shorthand like:

        mytool disable-sched    # expands to 'disable-scheduled-task'

    default: false

- commands (required)

    A hash mapping command names to either a subroutine reference or an
    array reference.

    If an array reference is used, the first element must be a subroutine
    reference and the second should be a valid log level. (See
    ["Per Command Log Levels"](#per-command-log-levels).)

    Example:

        {
          send          => \&send_message,
          receive       => \&receive_message,
          list_messages => [ \&list_messages, 'error' ],
        }

    If your script does not use command names, you may set a `default` key
    to the subroutine or method to run:

        { default => \&main }

    If no default is provided, the behavior is controlled by the
    `$AUTO_DEFAULT` and `$AUTO_HELP` package variables.

    Setting `$AUTO_DEFAULT` to true will when your `commands` hash
    contains only a single command, will cause that command to be run
    automatically when no command name is given on the command line. This
    allows you to treat the program like a single-command tool, where
    arguments can be passed directly without explicitly naming the
    command.

- default\_options (optional)

    A hash reference providing default values for options. These values
    apply if the corresponding option is not given on the command line.

- extra\_options (optional)

    An array reference of names for additional accessors you want to create,
    even if they are not part of `option_specs`.

    Example:

        extra_options => [ qw(foo bar baz) ]

- option\_specs (optional)

    An array reference of option specifications, as accepted by
    [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong). These define the command-line options your program
    recognizes.

## command

    command
    command(command)

Get or sets the command to execute. Usually this is the first argument
on the command line after all options have been parsed. There are
times when you might want to override the argument. You can pass a new
command that will be executed when you call the `run()` method.

## commands

    commands
    commands(command, handler)

Returns the hash you passed in the constructor as `commands` or can
be used to insert a new command into the `commands` hash. `handler`
should be a code reference.

    commands(foo => sub { return 'foo' });

## run

Execute the script with the given options, commands and arguments. The
`run` method interprets the command line and passes control to your
command subroutines. Your subroutines should return a 0 for success
and a non-zero value for failure.  This error code is passed to the
shell as the script return code.

## get\_args

Return the arguments that follow the command.

    get_args(NAME, ... )     # with names
    get_args()               # raw positional args

With names:

\- In scalar context, returns a hash reference mapping each NAME to the
  corresponding positional argument.
\- In list context, returns a flat list of `(name =` value)> pairs.

With no names:

\- Returns the command's positional arguments (array in list context;
  array reference in scalar context).

Example:

    sub send_message {
      my ($self) = @_;

      my %args = $self->get_args(qw(message email));

      _send_message($args{message}, $args{email});
    }

When you call `get_args` with a list of names, values are assigned in
order: the first name gets the first argument, the second name gets the
second argument, and so on. If you only want specific positions, you may
use `undef` as a placeholder:

    my %args = $self->get_args('message', undef, 'cc');  # args 1 and 3

If there are fewer positional arguments than names, the remaining names
are set to `undef`. Extra positional arguments (beyond the provided
names) are ignored.

## init

If you define your own `init()` method, it will be called by the
constructor. Use this method to perform any actions you require before
you execute the `run()` method.

# USING PACKAGE VARIABLES

You can pass the necessary parameter required to implement your
command line scripts in the constructor or some people prefer to see
them clearly defined in the code. Accordingly, you can use package
variables with the same name as the constructor arguments (in upper
case).

    our $OPTION_SPECS = [
      qw(
        help|h
        log-level=s|L
        debug|d
      )
    ];
    
    our $COMMANDS = {
      foo => \&foo,
      bar => \&bar,
    };

# COMMAND LINE OPTIONS

Command-line options are defined using [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)-style
specifications. You pass these into the constructor via the
`option_specs` parameter:

    my $cli = CLI::Simple->new(
      option_specs => [ qw( help|h foo-bar=s log-level=s ) ]
    );

In your command subroutines, you can access these values using
automatically generated getter methods:

    $cli->get_foo();
    $cli->get_log_level();

Option names that contain dashes (`-`) are automatically converted to
snake\_case for the accessor methods. For example:

    option_specs => [ 'foo-bar=s' ]

...results in:

    $cli->get_foo_bar();

# COMMAND ARGUMENTS

If your commands accept positional arguments, you can retrieve them
using the `get_args` method.

You may optionally provide a list of argument names, in which case the
arguments will be returned as a hash (or hashref in scalar context)
with named values.

Example:

    sub send_message {
      my ($self) = @_;

      my %args = $self->get_args(qw(phone_number message));

      send_sms_message($args{phone_number}, $args{message});
    }

If you call `get_args()` without any argument names, it simply
returns all remaining arguments as a list:

    my ($phone_number, $message) = $self->get_args;

_Note: When called with names, `get_args` returns a hash in list
context and a hash reference in scalar context._

# CUSTOM ERROR HANDLER

By default, `CLI::Simple` will exit if `GetOptions` returns a false
value, indicating an error while parsing options. You can override this
behavior in one of two ways:

- Set `$CLI::Simple::EXIT_ON_ERROR` to a false value.

    This disables automatic exiting and lets your program decide what to do
    after an option-parsing failure.

- Provide an `error_handler` callback in the constructor.

        my $cli = CLI::Simple->new(
          commands        => \%commands,
          default_options => \%default_options,
          extra_options   => \@extra_options,
          option_specs    => \@option_specs,
          abbreviations   => $TRUE,
          error_handler   => sub {
            my ($msg) = @_;
            print {*STDERR} $msg;
            return $TRUE;   # continue processing
          },
        );

    The error handler is called with the error message from `GetOptions`.
    It must return a boolean: a true value allows processing to continue,
    while a false value causes `CLI::Simple` to exit immediately.

# SETTING DEFAULT VALUES FOR OPTIONS

To assign default values to your options, pass a hash reference as the
`default_options` argument to the constructor. These values will be
used unless explicitly overridden by the user on the command line.

Example:

    my $cli = CLI::Simple->new(
      default_options => { foo => 'bar' },
      option_specs    => [ qw(foo=s bar=s) ],
      commands        => {
        foo => \&foo,
        bar => \&bar,
      },
    );

Defaulted options are accessible through their corresponding getter
methods, just like options set via the command line.

# ADDING USAGE TO YOUR SCRIPTS

To provide built-in usage/help output, include a `=head1 USAGE`
section in your script's POD:

    =head1 USAGE

      usage: myscript [options] command args

      Options
      -------
      --help, -h      Display help
      ...

If the user supplies the command `help`, or the `--help` option,
`CLI::Simple` will display this section automatically:

    perl myscript.pm --help
    perl myscript.pm help

## Custom help() Method

If you need full control over the help output, you can define a custom
`help` method and assign it as a command:

    commands => {
      help => \&help,
      ...
    }

This is useful if your module follows the modulino pattern and you
want to present usage information that differs from the embedded
POD. Without a custom handler, `CLI::Simple` defaults to displaying the
`USAGE` POD section.

# ADDING ADDITIONAL SETTERS

All command-line options are automatically available through getter
methods named `get_*`.

If you need to create additional accessors (getters and setters) for
values that are not derived from the command line, use the
`extra_options` parameter.

This is useful for passing runtime configuration or computed values
throughout your application.

Example:

    my $cli = CLI::Simple->new(
      default_options => { foo => 'bar' },
      option_specs    => [ qw(foo=s bar=s) ],
      extra_options   => [ qw(biz buz baz) ],
      commands        => {
        foo => \&foo,
        bar => \&bar,
      },
    );

This will generate `get_biz`, `set_biz`, `get_buz`, etc., for
internal use.

# LOGGING

`CLI::Simple` integrates with [Log::Log4perl](https://metacpan.org/pod/Log%3A%3ALog4perl) to provide structured
logging for your scripts.

To enable logging, call the class method `use_log4perl()` in your
module or script:

    __PACKAGE__->use_log4perl(
      level  => 'info',
      config => $log4perl_config_string
    );

If you do not explicitly include a `log-level` option in your
`option_specs`, CLI::Simple will automatically add one for you.

Once enabled, you can access the logger instance via:

    my $logger = $self->get_logger;

This logger supports the standard Log4perl methods like `info`,
`debug`, `warn`, etc.

## Per Command Log Levels

Some commands may require more verbose logging than others. For
example, certain commands might perform complex actions that benefit
from detailed logs, while others are designed solely to produce clean,
structured output.

To assign a custom log level to a command, use an array reference as
the value for that command in the commands hash passed to the
constructor.

The array reference should contain at least two elements:

- A code reference to the command subroutine
- A log level string: one of 'trace', 'debug', 'info', 'warn',
'error', or 'fatal'

Example:

    CLI::Simple->new(
      option_specs    => [qw( help format=s )],
      default_options => { format => 'json' },  # set some defaults
      extra_options   => [qw( content )],       # non-option, setter/getter
      commands        => {
        execute => \&execute,
        list    => [ \&list, 'error' ],
      }
    )->run;

_TIP: add other elements to the array for your command to process._

# FAQ

- How do I execute startup code before my command runs?

    Implement an `init()` method in your class. The `new()` constructor
    will invoke this method before returning and before `run()` is
    executed.

    Your `init()` method will have access to all options and
    arguments. Logging will also be initialized, so you can use
    `get_logger()` to emit messages.

- Do I need to implement commands?

    No. If your script doesn't support multiple commands, you can specify
    a `default` key instead:

        commands => { default => \&main }

- Must I subclass `CLI::Simple`?

    No. You can use it procedurally or functionally.

- How do I turn my class into a script?

    Use the modulino pattern: create a class that checks whether it is
    being invoked directly:

        package MyScript;

        caller or __PACKAGE__->main();

        sub main {
          ...
        }

    This lets the file be used as both a module and an executable script.

- How do the helper scripts work?

    This distribution includes two scripts to help with modulino-style
    scripts:

    - modulino

        A generic launcher that runs a Perl module as a script.

    - create-modulino.pl

        Creates a symbolic link or wrapper script to make your modulino-based
        module runnable from the command line.

        Example:

            sudo create-modulino.pl Foo::Bar foo-bar

        This creates an executable called `foo-bar` that loads and invokes
        `Foo::Bar` as a modulino script.

# ALIASING OPTIONS AND COMMANDS

`CLI::Simple` lets you define short, human-friendly aliases for both
option names and command names. Use the `alias` parameter to `new():`

    my $app = CLI::Simple->new(
      option_specs    => [ qw(config=s verbose!) ],
      commands        => { list => \&list, execute => \&execute },
      alias => {
        options  => { cfg => 'config', v => 'verbose' },
        commands => { ls  => 'list'   }
      },
    );

## How option aliases work

- Spec tail is copied automatically

    You only name the canonical option in `option_specs`. For each alias,
    `CLI::Simple` finds the canonical option's spec tail (for example
    `=s`, `:i`, `!`, `+`) and appends it to the alias. In the example
    above, `cfg` behaves as if you had written `cfg=s`, and `v` behaves
    as if you had written `v!`.

    _Note: If your option includes a one-letter short-cut and the alias
    does not start with the same letter it will not be automatically
    enabled as a short-cut._

- Accessors are created for both names

    Accessors are generated from all option names (canonical and aliases),
    with '-' normalized to '\_'. In the example, both `get_config()` and
    `get_cfg()` are available.

- Values are mirrored after parsing

    After option parsing and normalization, values are mirrored so either
    name can be used consistently. If both the canonical name and its alias
    are provided on the command line, the alias wins and becomes the final
    value for both names.

- No duplicate injection

    If the alias already exists in `option_specs`, it will not be injected
    again; value mirroring still occurs.

- Errors are explicit

    If an alias points at a canonical option that does not exist,
    `CLI::Simple` croaks with a clear error.

- Case sensitivity

    `Getopt::Long` is used with `:config no_ignore_case`, so option names
    (and therefore aliases) are case sensitive by default.

## How command aliases work

- Simple mapping

    Provide `alias =` { commands => { alias => canonical } }> to map an alias
    to an existing command. In the example, `ls` dispatches to the `list`
    command.

- Applied before abbreviations

    Aliases are installed before command abbreviation resolution. If you
    enable abbreviations, they apply to the full set of command names,
    including any aliases.

- Errors are explicit

    If an alias points at a command that does not exist, `CLI::Simple` croaks
    with a clear error.

## Usage examples

    # Using an option alias
    script.pl --cfg app.json execute

    # Using a command alias
    script.pl ls

After parsing, both `get_config()` and `get_cfg()` will return the
same value. If the user passes both `--config` and `--cfg`, the value
from `--cfg` (the alias) is used.

## Recommendations

- Keep the canonical spec single-named

    Define a single canonical name in `option_specs` and add other spellings
    via `alias`. Avoid multi-name specs like `config|cfg=s`; use `alias`
    instead.

- Document your precedence

    If you prefer the alias name to win when both are supplied, enforce
    that in your application or adjust the mirroring order. By default, the
    canonical name wins.

# ERRORS/EXIT CODES

When you execute the `run()` method it passes control to the method
that implements the command specified on the command line. Your method
is expected to return 0 for success or an error code that you can the
pass to the shell on exit.

    exit CLI::Simple->new(commands => { foo => \&cmd_foo })->run();

## Exit Codes

`CLI::Simple` uses conventional exit codes so that calling scripts
can distinguish between normal completion and error conditions.

- '0'

    Successful completion of a command (`SUCCESS`).

- '1'

    General usage error, such as `--help` display via `pod2usage`, or an
    invalid command line (`FAILURE`).

- '2'

    Option parsing failure, such as an unrecognized option or invalid
    argument (also reported as `FAILURE`).

- Any other code

    If a user-supplied command callback explicitly calls `exit()` or
    returns a numeric value other than 0 - 2, that code is passed through
    unchanged to the shell. This allows application-specific exit codes.

# EXAMPLE

Run the shell script that comes with the distribution to output a
working example.

    cli-simple-example > example.pl

# LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  See
[https://dev.perl.org/licenses/](https://dev.perl.org/licenses/) for more information.

# SEE ALSO

[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong), [CLI::Simple::Utils](https://metacpan.org/pod/CLI%3A%3ASimple%3A%3AUtils), [Pod::Usage](https://metacpan.org/pod/Pod%3A%3AUsage), [App::Cmd](https://metacpan.org/pod/App%3A%3ACmd),
[CLI::Framework](https://metacpan.org/pod/CLI%3A%3AFramework), [MooX::Options](https://metacpan.org/pod/MooX%3A%3AOptions)

# AUTHOR

Rob Lauer - <bigfoot@cpan.org>
