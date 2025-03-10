#!/usr/bin/perl
# Copyright (c) 2016-2025 Sullivan Beck. All rights reserved.
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.

use warnings;
use strict;

$::tests = '';
$::tests = "

2code Phoenician => phnx

2code Phoenician num => 115

2name Phnx => Phoenician

2name phnx => Phoenician

2name 115 num => Phoenician

code2code Phnx alpha num => 115

all_codes 2 => Adlm Afak

all_names 2 => Adlam Afaka

rename AAA newCode2 => 'ERROR: _code: code not in codeset: Aaa [alpha]'

add AAA newCode => 1

delete AAA => 1

add_alias FooBar NewName        => 'ERROR: add_alias: name does not exist: FooBar'

delete_alias Foobar             => 'ERROR: delete_alias: name does not exist: Foobar'

replace_code Foo Bar => 'ERROR: _code: code not in codeset: Foo [alpha]'

add_code_alias Foo Bar => 'ERROR: _code: code not in codeset: Foo [alpha]'

delete_code_alias Foo => 'ERROR: _code: code not in codeset: Foo [alpha]'

";

1;
# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 3
# cperl-continued-statement-offset: 2
# cperl-continued-brace-offset: 0
# cperl-brace-offset: 0
# cperl-brace-imaginary-offset: 0
# cperl-label-offset: 0
# End:

