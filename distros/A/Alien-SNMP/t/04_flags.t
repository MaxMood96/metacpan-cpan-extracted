use strict;
use warnings;
use Test::More;
use Alien::SNMP;

# Guards the DESTDIR/staging and cflags/libs relocatability class of bug: the
# compiler/linker flags this Alien advertises must point at directories and
# files that actually exist in the share, not at a stale or mis-staged prefix.

my @include_dirs = Alien::SNMP->cflags =~ /-I(\S+)/g;
my @lib_dirs     = Alien::SNMP->libs   =~ /-L(\S+)/g;

ok scalar(@include_dirs), 'cflags__share_build__advertises_an_include_dir';
ok scalar(@lib_dirs),     'libs__share_build__advertises_a_lib_dir';

for my $include_dir (@include_dirs) {
    ok -d $include_dir, "cflags__share_build__include_dir_exists ($include_dir)";
}

ok -e "$include_dirs[0]/net-snmp/net-snmp-config.h",
  'cflags__share_build__points_at_real_netsnmp_headers';

# net-snmp lists snmpIPBaseDomain.h among the transport headers to install but ships
# it under snmplib/transports/, outside the tree the install rule reads from.  GNU
# make swallows the resulting `install` failure, so the header just goes missing;
# BSD and Solaris make abort the whole build.  The alienfile stages the header before
# configure runs, and a complete header set is the observable proof that it worked.
ok -e "$include_dirs[0]/net-snmp/library/snmpIPBaseDomain.h",
  'cflags__share_build__installs_every_configured_transport_header'
  or diag "no snmpIPBaseDomain.h under $include_dirs[0]/net-snmp/library/; "
        . "cflags is: " . Alien::SNMP->cflags;

# net-snmp-config.h includes one platform header chosen at configure time, and
# net-snmp has shipped headers it forgot to add to the install list: on FreeBSD 15
# the config header asks for net-snmp/system/freebsd15.h, which was in the source
# but never installed, so every compile against these cflags failed.  Read the
# name out of the installed header rather than assuming a platform.
# Do not die if the header cannot be read.  This file's whole value on a platform
# we cannot reproduce is the assertions below and the diagnostics they carry, and
# a die here throws all of them away along with the rest of the run.
my $config_header = "$include_dirs[0]/net-snmp/net-snmp-config.h";
my ($system_header) = do {
    if (open my $fh, '<', $config_header) {
        map { /^#define\s+NETSNMP_SYSTEM_INCLUDE_FILE\s+"([^"]+)"/ ? $1 : () } <$fh>;
    }
    else {
        diag "can't read $config_header: $!";
        ();
    }
};

ok defined $system_header,
  'cflags__share_build__config_header_names_a_system_header';

SKIP: {
    skip 'no NETSNMP_SYSTEM_INCLUDE_FILE to check', 1 unless defined $system_header;

    ok -e "$include_dirs[0]/$system_header",
      'cflags__share_build__installs_the_system_header_it_includes'
      or diag "$config_header includes $system_header, which is not in the share";
}

for my $lib_dir (@lib_dirs) {
    ok -d $lib_dir, "libs__share_build__lib_dir_exists ($lib_dir)";
}

# A bare failure here says nothing about *which* directory was searched, and the
# advertised -L is not necessarily the Alien's own: a Solaris smoker failed this
# with an empty dynamic_libs while t/02_compile.t linked and ran fine, which is
# what a foreign -L sorting first would look like.  Report all of them.
ok scalar(glob "$lib_dirs[0]/libnetsnmp.*"),
  'libs__share_build__contains_a_libnetsnmp'
  or diag "nothing matches libnetsnmp.* in $lib_dirs[0]\n"
        . "libs is: " . Alien::SNMP->libs . "\n"
        . "all advertised lib dirs and what each holds:\n"
        . join '', map {
            # Not s///r: this distribution supports back to perl 5.10, and the
            # /r modifier arrived in 5.14.
            my @found = map { my $f = $_; $f =~ s{.*/}{}; $f }
                        glob "$_/libnetsnmp*";
            "  $_\n" . (@found ? "    @found\n" : "    (no libnetsnmp* here)\n")
          } @lib_dirs;

done_testing;
