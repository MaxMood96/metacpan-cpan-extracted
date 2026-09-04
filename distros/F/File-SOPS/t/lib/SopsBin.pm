package SopsBin;

use strict;
use warnings;
use Cwd qw(abs_path);
use Exporter qw(import);

our @EXPORT_OK = qw(find_sops_bin);

# Resolve which sops binary the interop-driving tests should use, in order:
#
#   1. $SOPS_BIN, if set -- an explicit choice always wins. If it is set to
#      something that is not executable, that is a misconfiguration worth
#      failing loudly on, not silently falling through to another binary:
#      falling through would prove compatibility against a binary the
#      caller did not choose, and nobody would notice.
#   2. A `sops` found on PATH -- so a normal install (e.g. ~/bin/sops) is
#      picked up with zero configuration.
#   3. .sops-bin/sops, resolved (via Cwd::abs_path) against the current
#      working directory at detection time -- the repo-local convention (see
#      maint/fetch-sops): gitignored, survives a /tmp wipe, and found
#      automatically since `prove -lr t/` and `dzil test` both run with the
#      repo root as cwd. Returned as an ABSOLUTE path deliberately: several
#      callers build shell command strings of the form
#      "cd $other_dir && $sops_bin ..." to exercise sops's own
#      cwd-relative .sops.yaml search, and a bare relative ".sops-bin/sops"
#      would silently resolve against the wrong directory once the shell
#      has cd'd elsewhere (measured: t/04-interop.t's creation-rules subtest
#      fails exactly this way with a relative path).
#   4. /tmp/sops, kept for backwards compatibility with the old hardcoded
#      location.
#
# Returns the resolved path, or undef if none of the four yielded one.

sub _find_on_path {
    my ($name) = @_;
    for my $dir (split /:/, $ENV{PATH} // '') {
        next unless length $dir;
        my $candidate = "$dir/$name";
        return $candidate if -x $candidate && !-d $candidate;
    }
    return undef;
}

sub find_sops_bin {
    if (defined $ENV{SOPS_BIN} && length $ENV{SOPS_BIN}) {
        die "SOPS_BIN is set to '$ENV{SOPS_BIN}' but that is not executable. "
          . "Fix the path, or unset SOPS_BIN to auto-detect sops on PATH.\n"
            unless -x $ENV{SOPS_BIN};
        # Resolve to an ABSOLUTE path for the same reason the .sops-bin literal
        # below is: several callers build "cd $other_dir && $sops_bin ..." to
        # exercise sops's own cwd-relative .sops.yaml search, and a relative
        # SOPS_BIN (e.g. .sops-bin/sops) would resolve against the wrong
        # directory once the shell has cd'd -- silently failing exactly the
        # creation-rules and RE2 interop subtests (t/04, t/62, t/79).
        return abs_path($ENV{SOPS_BIN});
    }

    return _find_on_path('sops')
        || (-x '.sops-bin/sops' ? abs_path('.sops-bin/sops') : undef)
        || (-x '/tmp/sops' ? '/tmp/sops' : undef);
}

1;
