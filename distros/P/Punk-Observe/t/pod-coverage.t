#!perl
# Every package this distribution installs is loadable and documented.
#
# The packages are declared in the XS rather than in the .pm files, so the
# list is taken from the loaded symbol table rather than from lib/: a package
# that gained an XSUB and no POD is exactly what this is here to catch.
#
# Pod::Coverage is optional and its absence skips only the checks that need
# it. The rest run everywhere, because "skipped" on the machine that would
# have caught the problem is the same as not having written the test.
use 5.010;
use strict;
use warnings;
use Test::More;

use Punk::Observe ();

my @pkg = qw(
    Punk::Observe
    Punk::Observe::Alert
    Punk::Observe::Dashboard
    Punk::Observe::Decode
    Punk::Observe::Exec
    Punk::Observe::Flame
    Punk::Observe::Ingest
    Punk::Observe::Key
    Punk::Observe::Limit
    Punk::Observe::Live
    Punk::Observe::Log
    Punk::Observe::Map
    Punk::Observe::Metric
    Punk::Observe::Plot
    Punk::Observe::Query
    Punk::Observe::Scan
    Punk::Observe::Retain
    Punk::Observe::Route
    Punk::Observe::SegIO
    Punk::Observe::Segment
    Punk::Observe::Store
    Punk::Observe::SVG
    Punk::Observe::View
    Punk::Observe::Target
    Punk::Observe::Tenant
    Punk::Observe::Trace
    Punk::Observe::WAL
);

my $have_pc = eval {
    require Test::Pod::Coverage; Test::Pod::Coverage->VERSION('1.08');
    require Pod::Coverage;       Pod::Coverage->VERSION('0.18');
    1;
};

# Loading one module bootstraps them all, but each must also be loadable by
# name: a package a stack trace mentions and `use` cannot find is a dead end.
for my $p (@pkg) {
    my $file = $p; $file =~ s{::}{/}g; $file .= '.pm';
    ok(eval { require $file; 1 }, "$p is loadable by name") or diag $@;
}

# Every function in every package is named somewhere in that package's POD.
# This is the coarse version of what Pod::Coverage does, and it needs nothing
# installed, so it is what actually runs on a smoker.
my %private = map { $_ => 1 } qw(DESTROY bootstrap import AUTOLOAD);
for my $p (@pkg) {
    my $file = $p; $file =~ s{::}{/}g;
    my $path;
    for my $dir (@INC) {
        next if ref $dir;
        if (-f "$dir/$file.pm") { $path = "$dir/$file.pm"; last }
    }
    if (!$path) { fail("$p: found on disk"); next }

    open my $fh, '<', $path or do { fail("$p: $path readable"); next };
    my $pod = do { local $/; <$fh> };
    close $fh;

    my %documented;
    while ($pod =~ /^=(?:head[234]|item)\s+(.+)$/mg) {
        my $t = $1;
        $t =~ s/[A-Z]<//g;
        $t =~ s/>//g;
        $documented{$1} = 1 while $t =~ /(\w+)/g;
    }

    my @undocumented;
    {
        no strict 'refs';
        for my $sym (sort keys %{"${p}::"}) {
            next unless defined &{"${p}::$sym"};
            next if $private{$sym} || $sym =~ /^_/;
            push @undocumented, $sym unless $documented{$sym};
        }
    }
    is_deeply(\@undocumented, [], "$p: every function is named in its POD")
        or diag "undocumented: @undocumented";
}

# And no package was added to the XS without being listed above.
{
    my @found;
    my %seen;
    my @todo = ('Punk::Observe::');
    no strict 'refs';
    while (my $stash = shift @todo) {
        for my $k (sort keys %{$stash}) {
            next unless $k =~ /::$/;
            my $child = $stash . $k;
            next if $seen{$child}++ || $child eq $stash;
            push @todo, $child;
        }
        (my $name = $stash) =~ s/::$//;
        push @found, $name
            if grep { defined &{"${stash}$_"} } keys %{$stash};
    }
    my %known = map { $_ => 1 } @pkg;
    my @extra = sort grep { !$known{$_} } @found;
    is_deeply(\@extra, [], 'no undocumented package in the symbol table')
        or diag "not listed in this test: @extra";
}

SKIP: {
    skip 'Test::Pod::Coverage 1.08 and Pod::Coverage 0.18 required', scalar @pkg
        unless $have_pc;
    Test::Pod::Coverage::pod_coverage_ok($_, "$_: POD coverage") for @pkg;
}

done_testing();
