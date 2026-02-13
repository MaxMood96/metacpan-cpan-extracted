#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(fc);
use builtin qw(true false);
use Test::More;

my $rxp_TempFS		= qr{^(?:tmp|ram)fs$}i;
my $rxp_OptionSplit	= qr{,\s*};
my $rxp_MountLinux	= qr{^
	([^\s]+)	# Device	1
	\s+on\s+
	([^\s]+)/*	# Mount point	2
	\s+type\s+
	([^\s]+)	# File system	3
	\s*\(		# literal braket
	(.+)		# Options	4
	\s*\)\s*	# literal braket
	$}xx;
my $rxp_MountBSD	= qr{^
	([^\s]+)	# Device	1
	\s+on\s+
	([^\s]+)/*	# Mount point	2
	\s*\(		# literal braket
	([^\s,]+)	# File system	3
	(?:, ?)?
	(.+)?		# Options	4
	\s*\)\s*	# literal braket
	$}xx;
my $rxp_Accord		= ( fc($^O) eq fc(q(FreeBSD)) ) ? $rxp_MountBSD : $rxp_MountLinux;

my @uri_LinuxDirs	= qw( /dev/shm /run/shm /run /tmp );
my @uri_BSDirs		= qw( /run /var/spool/lock /tmp );
my @uri_Accord		= ( fc($^O) eq fc(q(FreeBSD)) ) ? @uri_BSDirs : @uri_LinuxDirs;

sub GetMounts {
	my @str_Mounts	= qx(mount);
	my @har_Mounts	= (
		# uri_Device		=> < URI Path to device >,
		# uri_MountPoint	=> < URI Path to dir >,
		# str_FileSystem	=> < STR like ext4, autofs, tmpfs, etc. >,
		# are_Options		=> [ ARE of split() ],
		);

	foreach my $str_Line ( @str_Mounts ) {
		chomp($str_Line);

		if ( $str_Line =~ m($rxp_Accord) ) {
			push(@har_Mounts, {
				uri_Device	=> $1,
				uri_MountPoint	=> $2,
				str_FileSystem	=> $3,
				are_Options	=> [
					( $4 ) ? split(m($rxp_OptionSplit), $4) : ()
					],
				});
			}
		}

	return(\@har_Mounts);
	}

sub CheckOperatingSystem {
	if ( grep { fc($^O) eq fc($_) } qw(FreeBSD Linux) ) {
		return(true);
		}
	else {
		#print STDERR qq{Not working on $^O.\n};
		return(false);
		}
	}

sub CheckTestUser {
	if ( ! defined( $ENV{USER} // $ENV{LOGNAME} ) ) {
		print STDERR qq{Can't distinguish user name.\n};
		return(false);
		}
	elsif ( ( $ENV{USER} // $ENV{LOGNAME} ) eq q{root} ) {
		print STDERR qq{Running this test as 'root' would show false results.\n};
		return(false);
		}

	return(true);
	}

sub CheckGoodMountPoint {
	# Reverse sorted list of mounts as hash ref
	my $are_Mounts		= GetMounts() or die qq{Got no mounts.\n};

	# Get the first matching writable mount point according to all interesting locations
	my ($har_FirstMount)	= grep { my $har_ToTest = $_;
		grep { $har_ToTest->{uri_MountPoint} eq $_ && -w && $har_ToTest->{str_FileSystem} =~ m{$rxp_TempFS} } @uri_Accord
		} @{$are_Mounts};

	if ( ! defined($har_FirstMount) ) {
		# Get the first matching writable mount point according to all interesting locations
		($har_FirstMount)	= grep { my $har_ToTest = $_;
			grep { $har_ToTest->{uri_MountPoint} eq $_ && -w $_ } @uri_Accord
			} @{$are_Mounts};
		}

	# If nothing was found
	if ( ! defined($har_FirstMount) ) {
		print STDERR qq{There is no fitting tmpfs.\n}
			. ( ( fc($^O) eq fc(q(FreeBSD)) ) ? qq{At least /run is required, preferred mounted on tmpfs, writable to all users.\n} : '' )
			. qq{Any of these directories are appropriate:\n}
			. join('', map { qq{  $_\n} } @uri_Accord );
		return(false);
		}

	# Found good mount point
	print qq{Default caching direcotry will usually be "$har_FirstMount->{uri_MountPoint}" on this system.\n};

	if ( $har_FirstMount->{str_FileSystem} !~ m{$rxp_TempFS} ) {
		print STDERR qq{(It is not a tmpfs, so IPC may be slow.)\n};
		}

	return(true);
	}

if ( ! CheckOperatingSystem() ) {
	plan(skip_all => qq{Not implemented for $^O.});
	}
elsif ( ! CheckTestUser() ) {
	plan(skip_all => qq{Testing as 'root' is useless.});
	}
else {
	plan(tests => 3);
	}

ok(CheckOperatingSystem(),	q{OS});
ok(CheckTestUser(),		q{Test User});
ok(CheckGoodMountPoint(),	q{Good Mount Point});

exit(0);
