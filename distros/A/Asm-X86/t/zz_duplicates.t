#!/usr/bin/perl -w
# Asm::X86 - a test for duplicate values.
#
#	Copyright (C) 2008-2024 Bogdan 'bogdro' Drozdowski,
#	  bogdro (at) users . sourceforge . net
#	  bogdro /at\ cpan . org
#
# This file is part of Project Asmosis, a set of tools related to assembly
#  language programming.
# Project Asmosis homepage: https://asmosis.sourceforge.io/
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#

use strict;
use warnings;

use Test::More tests => 19;
use Asm::X86 qw(@regs8_intel @regs16_intel @segregs_intel @regs32_intel @regs64_intel @regs_mm_intel
	@regs_intel @regs_fpu_intel
	@regs8_att @regs16_att @segregs_att @regs32_att @regs64_att @regs_mm_att
	@regs_att @regs_fpu_att
	@instr_intel @instr_att @instr);

sub find_duplicates($$) {

	my $arr = shift;
	my %arr_hash;
	my $arr_name = shift;
	my %dupli;

	foreach (@{$arr}) {

		$dupli{$_} = 1 if defined $arr_hash{$_};
		$arr_hash{$_} = 1;
	}

	my $duplicates = '';
	foreach (keys %dupli) {

		$duplicates .= "[$_]";
	}
	is ( @{$arr}, keys %arr_hash, "No duplicates allowed in array $arr_name: $duplicates" );
}

find_duplicates(\@regs8_intel, '@regs8_intel');
find_duplicates(\@regs16_intel, '@regs16_intel');
find_duplicates(\@segregs_intel, '@segregs_intel');
find_duplicates(\@regs32_intel, '@regs32_intel');
find_duplicates(\@regs64_intel, '@regs64_intel');
find_duplicates(\@regs_mm_intel, '@regs_mm_intel');
find_duplicates(\@regs_intel, '@regs_intel');
find_duplicates(\@regs_fpu_intel, '@regs_fpu_intel');
find_duplicates(\@regs8_att, '@regs8_att');
find_duplicates(\@regs16_att, '@regs16_att');
find_duplicates(\@segregs_att, '@segregs_att');
find_duplicates(\@regs32_att, '@regs32_att');
find_duplicates(\@regs64_att, '@regs64_att');
find_duplicates(\@regs_mm_att, '@regs_mm_att');
find_duplicates(\@regs_att, '@regs_att');
find_duplicates(\@regs_fpu_att, '@regs_fpu_att');
find_duplicates(\@instr_intel, '@instr_intel');
find_duplicates(\@instr_att, '@instr_att');
find_duplicates(\@instr, '@instr');
