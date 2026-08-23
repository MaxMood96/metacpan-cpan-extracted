# Loaded by t/00_diag.t, which requires this file if it exists.  Everything here
# is diagnostics only: it must never die, or it takes the whole suite with it.
#
# What this Alien advertises is the first thing wanted when a smoke report comes
# back from a platform we cannot reproduce.  A Solaris smoker failed t/04_flags.t
# and t/06_bundled_perl_modules.t with an empty dynamic_libs and no libnetsnmp in
# the advertised lib dir, and the report carried no way to tell which directories
# those assertions had actually looked at.
#
# Calls into Test::More are fully qualified rather than relying on the importing
# file's `diag`, so this file still compiles on its own under perl -c.

use strict;
use warnings;

our $format;

sub _diag_gap { Test::More::diag('') for 1 .. 3 }

sub _diag_pair {
    my ($label, $value) = @_;
    Test::More::diag(sprintf $format || '%-20s %s', $label,
                     defined $value ? $value : 'undef');
}

_diag_gap();

if (eval { require Alien::SNMP; 1 }) {
    _diag_pair($_, scalar eval { Alien::SNMP->$_ })
      for qw( version install_type cflags libs cflags_static libs_static );

    for my $list (qw( dynamic_libs bin_dir )) {
        my @values = eval { Alien::SNMP->$list };
        _diag_pair($list, @values ? '' : '(empty)');
        Test::More::diag("  $_") for @values;
    }

    # t/04_flags.t indexes [0] of each of these, so report them broken out rather
    # than leaving a reader to parse them back out of cflags and libs by hand.
    my @include_dirs = (scalar eval { Alien::SNMP->cflags } || '') =~ /-I(\S+)/g;
    my @lib_dirs     = (scalar eval { Alien::SNMP->libs }   || '') =~ /-L(\S+)/g;

    _diag_pair($_, -d $_ ? 'exists' : 'MISSING') for @include_dirs, @lib_dirs;
}
else {
    Test::More::diag('Alien::SNMP failed to load, so no Alien properties can be reported:');
    Test::More::diag($@);
}

1;
