# Term::CmdLine

Command-line interface module using Term::ReadLine with built-in commands, history management, variable interpolation, and command completion.

## Installation

To install this module, run the following commands:

```bash
perl Makefile.PL
make
make test
make install
```

## Dependencies

This module requires these other modules and libraries:

- Term::ReadLine (required)
- Term::ANSIColor (required)
- Term::ReadLine::Gnu (optional, but highly recommended for full functionality)

## Usage

```perl
use Term::CmdLine;

my %cmds = (
  list => {
    help        => 'list [options]',
    description => 'List items',
  },
  execute => {
    help        => 'execute <cmd>',
    description => 'Execute a command',
  },
);

my $cmdline = Term::CmdLine->new('myapp', undef, %cmds);

while (my ($cmd, $result) = $cmdline->get) {
  last if $cmd eq 'exit';
  # Process your commands here
}
```

## Features

- Command-line editing with history (via Term::ReadLine)
- Command completion (requires Term::ReadLine::Gnu)
- Built-in commands: help, history, set/get variables, source files, trace/color control
- Variable interpolation
- Command history management
- Customizable prompts

## Author

Andrew DeFaria <Andrew@DeFaria.com>

## License

This module is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.

## Copyright

Copyright (C) 2011-2026 Andrew DeFaria
