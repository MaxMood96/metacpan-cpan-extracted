use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib';
require_ok('EV::WebKit') or BAIL_OUT('cannot load EV::WebKit');
ok(defined &EV::WebKit::available, 'available() defined');
like($EV::WebKit::VERSION, qr/\A\d+\.\d+\z/, 'version set');

# Every module ships in one tarball, so every module must carry the tarball's
# version. A sibling left one release behind still gets INDEXED at that higher
# number, and the next real release of it then fails to index at all -- silent
# on the author's machine, permanent on PAUSE.
{
    my @mods = qw(EV::WebKit::Element EV::WebKit::Fingerprint EV::WebKit::Protocol
                  EV::WebKit::Control EV::WebKit::Client EV::WebKit::Client::Element);
    require_ok($_) for @mods;
    my %seen;
    no strict 'refs';
    push @{ $seen{ ${"${_}::VERSION"} // '(undef)' } }, $_ for @mods;
    push @{ $seen{$EV::WebKit::VERSION} }, 'EV::WebKit';
    is(scalar keys %seen, 1, 'every module in the dist carries the same version')
        or diag explain \%seen;
}

# The cpanfile is what `cpanm --installdeps .` reads -- it takes precedence over
# Makefile.PL -- so the two drifting apart means CI installs a different set of
# prerequisites than a CPAN client does. File::ShareDir was missing from the
# cpanfile for exactly that reason and only CI's hand-written bootstrap hid it.
SKIP: {
    skip 'not a source checkout', 3 unless -f 'cpanfile' && -f 'Makefile.PL';
    my $slurp = sub { open my $h, '<', $_[0] or return ''; local $/; <$h> };
    my $mk = $slurp->('Makefile.PL');
    my %want;
    for my $blk (qw(PREREQ_PM CONFIGURE_REQUIRES TEST_REQUIRES)) {
        next unless $mk =~ /\Q$blk\E\s*=>\s*\{(.*?)\}/s;
        my $body = $1;
        $want{$1} = 1 while $body =~ /'([A-Za-z][\w:]*)'\s*=>/g;
    }
    $want{'Proxy::Impersonate'} = 1 if $mk =~ /'Proxy::Impersonate'/;
    my $cp = $slurp->('cpanfile');
    my %have;
    $have{$1} = 1 while $cp =~ /'([A-Za-z][\w:]*)'/g;
    # Anchored: the extraction is a regex over Makefile.PL's source, so a
    # reformat that broke it would leave %want empty and this passing with
    # nothing checked at all.
    cmp_ok(scalar keys %want, '>=', 9, 'the Makefile.PL prerequisite scan found something');
    my @missing = sort grep { !$have{$_} } keys %want;
    is("@missing", '', 'every Makefile.PL prerequisite is also in the cpanfile');

    # ...and at the same VERSION. Comparing names alone let a bumped floor in
    # one file sit against an unbumped one in the other -- which is the drift
    # this guard exists to catch, and it went undetected once already.
    my %mkver;
    for my $blk (qw(PREREQ_PM CONFIGURE_REQUIRES TEST_REQUIRES)) {
        next unless $mk =~ /\Q$blk\E\s*=>\s*\{(.*?)\}/s;
        my $body = $1;
        $mkver{$1} = $2 while $body =~ /'([A-Za-z][\w:]*)'\s*=>\s*'?([\d.]+)'?/g;
    }
    $mkver{$1} = $2 if $mk =~ /'(Proxy::Impersonate)'\s*=>\s*'([\d.]+)'/;
    # perl itself is spelled MIN_PERL_VERSION in Makefile.PL and `requires
    # 'perl'` in the cpanfile -- the same floor under two names.
    $mkver{perl} = $1 if $mk =~ /MIN_PERL_VERSION\s*=>\s*'?([\d._]+)'?/;
    my %cpver;
    $cpver{$1} = $2 while $cp =~ /^\s*(?:requires|recommends)\s+'([A-Za-z][\w:]*)'\s*,\s*'([\d.]+)'/mg;
    $cpver{$1} = $2 while $cp =~ /requires\s+'([A-Za-z][\w:]*)'\s*,\s*'([\d.]+)'\s*;/g;
    # Compared over the UNION, and treating "absent" as 0: a floor bumped on one
    # side and not the other is exactly the drift this exists to catch, and
    # filtering to modules that carry a version in both files dropped it.
    my @drift = sort grep { ($mkver{$_} // 0) + 0 != ($cpver{$_} // 0) + 0 }
                     do { my %u = (%mkver, %cpver, %want); keys %u };
    is("@drift", '', 'and at the same version floor')
        or diag join ', ', map { "$_: Makefile.PL=" . ($mkver{$_} // '(none)')
                               . " cpanfile=" . ($cpver{$_} // '(none)') } @drift;
}

done_testing;
