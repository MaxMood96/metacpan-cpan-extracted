#!/usr/bin/env perl

use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME            => q{IPC::LockTicket},
	VERSION_FROM    => q{lib/IPC/LockTicket.pm},
	ABSTRACT	=> q{Inter process locking mechanism},
	AUTHOR		=> q{Dominik Bernhardt <domasprogrammer@gmail.com>},
	LICENSE		=> q{freebsd}, # BSD-2-Clause
	MIN_PERL_VERSION => q{5.040001},
	README		=> q{README.pod},
	test		=> {
		TESTS	=> q{t/*.t},
		},
	);
