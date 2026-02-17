[![Actions Status](https://github.com/kaz-utashiro/Getopt-EX-Config/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/kaz-utashiro/Getopt-EX-Config/actions?workflow=test) [![MetaCPAN Release](https://badge.fury.io/pl/Getopt-EX-Config.svg)](https://metacpan.org/release/Getopt-EX-Config)
# NAME

Getopt::EX::Config - Getopt::EX module configuration interface

# SYNOPSIS

    example -Mfoo::config(foo=yabaa,bar=dabba) ...

    example -Mfoo::config(foo=yabba) --config bar=dabba ... -- ...

    example -Mfoo::config(foo=yabba) --bar=dabba ... -- ...

    example -Mfoo --foo=yabaa --bar=dabba -- ...

# VERSION

Version 1.0202

# DESCRIPTION

This module provides an interface to define configuration information
for `Getopt::EX` modules.  In the traditional way, in order to set
options for a module, it was necessary to define dedicated command
line options for them.  To do so, it is necessary to avoid name
conflicts with existing command options or with other modules used
together.

Using this module, it is possible to define configuration information
only for the module and to define module-specific command options.

You can create config object like this:

    use Getopt::EX::Config;
    my $config = Getopt::EX::Config->new(
        char  => 0,
        width => 0,
        code  => 1,
        name  => "Franky",
    );

This call returns hash object and each member can be accessed like
`$config->{width}`.

You can set these configuration values by calling `config()` function
with module declaration.

    example -Mfoo::config(width,code=0) ...

Parameter list is given by key-value pairs, and `1` is assumed when
value is not given.  Above code set `width` to `1` and `code` to
`0`.

Also module specific options can be taken care of by calling
`deal_with` method from module startup funciton `intialize` or
`finalize`.

    sub finalize {
        our($mod, $argv) = @_;
        $config->deal_with($argv);
    }

Then you can use `--config` module option like this:

    example -Mfoo --config width,code=0 -- ...

The module startup function is executed between the `initialize()`
and `finalize()` calls.  Therefore, if you want to give priority to
module-specific options over the startup function, you must call
`deal_with` in the `finalize()` function.

If you want to make module private option, say `--width` to set `$config->{width}` value, `deal_with` method takes `Getopt::Long`
style option specifications.

    sub finalize {
        our($mod, $argv) = @_;
        $config->deal_with(
            $argv,
            "width!",
            "code!",
            "name=s",
        );
    }

Then you can use module private option like this:

    example -Mcharcode --width --no-code --name=Benjy -- ...

By default, option names with underscores are automatically aliased with
dash equivalents. For example, if you specify `long_lc!`, both `--long_lc`
and `--long-lc` will work. This conversion can be disabled by setting
`$Getopt::EX::Config::REPLACE_UNDERSCORE` to 0.

The reason why it is not necessary to specify the destination of the
value is that the hash object is passed when calling the
`Getopt::Long` library.  The above code is equivalent to the
following code.  See ["Storing options values in a hash" in Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong#Storing-options-values-in-a-hash)
for detail.

## Nested Hash Configuration

Config values can be hash references for structured configuration:

    my $config = Getopt::EX::Config->new(
        mode   => '',
        hashed => { h3 => 0, h4 => 0, h5 => 0, h6 => 0 },
    );

Nested values can be accessed using dot notation in the `config()`
function:

    example -Mfoo::config(hashed.h3=1,hashed.h4=1) ...

    example -Mfoo --config hashed.h3=1 -- ...

The dot notation navigates into nested hashes: `hashed.h3=1` sets
`$config->{hashed}{h3}` to `1`.  The intermediate key
(`hashed`) must exist as a hash reference, and the leaf key (`h3`)
must already exist in that hash.

Hash options can also be defined as module private options using
[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) hash type (`%`):

    $config->deal_with($argv, "hashed=s%");

This allows:

    example -Mfoo --hashed h3=1 --hashed h4=1 -- ...

Note that the `Getopt::Long` hash type auto-vivifies keys, so
`--hashed h3=1` works even when `h3` does not pre-exist in the hash.

The dot notation and nested hash support are designed with future
extensibility in mind.  For example, a configuration file under
`~/.config` could store module settings in YAML-like format:

    # ~/.config/example/foo.yml
    mode: dark
    hashed:
      h3: 1
      h4: 1
      h5: 1
      h6: 1

This would map naturally to the nested hash structure and dot notation
already supported by this module.

    sub finalize {
        our($mod, $argv) = @_;
        $config->deal_with(
            $argv,
            "width!" => \$config->{width},
            "code!"  => \$config->{code},
            "name=s" => \$config->{name},
        );
    }

# FUNCTIONS

- **config**(_key_ => _value_, ...)

    This module exports the function `config` by default.  As explained
    above, this is why the `config` function can be executed with module
    declaration.

    If you want to use a function with a different name, specify it
    explicitly.  In the following example, the function `set` is defined
    and can be used in the same way as `config`.

        use Getopt::EX::Config qw(config set);

- **config**(_key_)

    The `config` function may also be used to refer parameters in the
    program.  In this case, specify single argument.

        my $width = config('width');

    Parameter value references can also be used as left-hand side values,
    so values can be assigned.

        config('width') = 42;

# METHODS

- **new**(_key-value list_)
- **new**(_hash reference_)

    Return configuration object.

    Call with key-value list like this:

        my $config = Getopt::EX::Config->new(
            char  => 0,
            width => 0,
            code  => 1,
            name  => "Franky",
        );

    Or call with hash reference.

        my %config = (
            char  => 0,
            width => 0,
            code  => 1,
            name  => "Franky",
        );
        my $config = Getopt::EX::Config->new(\%config);

    In this case, `\%config` and `$config` should be identical.
    Do not apply `lock_keys` to the hash before calling `new`.

    Config keys must start with a letter (a-z, A-Z).  Keys starting with
    underscore or other characters are reserved for internal use.

- **deal\_with**

    You can get argument reference in `initialize()` or `finalize()`
    function declared in `Getopt::EX` module.  Call `deal_with` method
    with that reference.

        sub finalize {
            our($mod, $argv) = @_;
            $config->deal_with($argv);
        }

    You can define module specific options by giving [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) style
    definition with that call.

        sub finalize {
            our($mod, $argv) = @_;
            $config->deal_with($argv,
                               "width!", "code!", "name=s");
        }

- **configure**(_options_)

    Set [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) configuration options.  Returns the object itself
    for method chaining.  Internally uses [Getopt::Long::Parser](https://metacpan.org/pod/Getopt%3A%3ALong%3A%3AParser) so that
    global configuration is not affected.

        $config->configure('pass_through');
        $config->deal_with($argv, "width!", "name=s");

    Or with method chaining:

        $config->configure('pass_through')->deal_with($argv, ...);

- **argv**

    Returns the remaining arguments after `deal_with` processing.  When
    used with `pass_through` configuration, unrecognized options are
    preserved and can be retrieved with this method.

        sub finalize {
            our($mod, $argv) = @_;
            $config->configure('pass_through')->deal_with($argv, "width!", "name=s");
            my @extra = $config->argv;  # unrecognized options
        }

# VARIABLES

- **$REPLACE\_UNDERSCORE**

    When set to true (default), option names with underscores are automatically
    aliased with dash equivalents. For example, `long_lc!` becomes 
    `long_lc|long-lc!`, allowing both `--long_lc` and `--long-lc` to work.

    Set to false to disable this conversion:

        $Getopt::EX::Config::REPLACE_UNDERSCORE = 0;

# SEE ALSO

[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX)

[Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)

# AUTHOR

Kazumasa Utashiro

# COPYRIGHT

The following copyright notice applies to all the files provided in
this distribution, including binary files, unless explicitly noted
otherwise.

Copyright ©︎ 2025-2026 Kazumasa Utashiro

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
