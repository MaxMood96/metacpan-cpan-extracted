use v5.10; use strict; use warnings;
use Test::More;

subtest 'pod syntax' => sub {
    eval { require Test::Pod; Test::Pod->import; 1 }
        or plan skip_all => 'Test::Pod not installed';
    # The modules ACTUALLY LOADED, exactly as the drift subtest below does --
    # all_pod_files_ok() defaults to blib/ whenever one exists, so a stale blib,
    # or a run under -I pointing somewhere else, had this checking a different
    # copy from the one under test.
    require EV::WebKit;
    require EV::WebKit::Element;
    require EV::WebKit::Fingerprint;
    require EV::WebKit::Protocol;
    require EV::WebKit::Control;
    require EV::WebKit::Client;
    require EV::WebKit::Client::Element;
    my @files = sort grep { defined && -f }
                map { $INC{$_} }
                grep { m{^EV/WebKit(?:/|\.pm$)} } keys %INC;
    cmp_ok(scalar @files, '>=', 7, 'found the loaded modules to check');
    pod_file_ok($_) for @files;
};

# EV::WebKit::Client and its Element document their methods as a PROSE LIST
# rather than one =head3 apiece, because both generate almost all of them from
# a table. A generated method is therefore invisible to the documentation: add
# one and nothing complains that the list no longer names it. Both lists had in
# fact drifted -- Client's was missing status/press/scroll/download/wait_for_js
# and Element's box/check/uncheck/hover/select_option/send_keys/scroll_into_view,
# every one of them a method the control protocol already carried. So check the
# prose against the symbol table.
subtest 'documented method lists match what is generated' => sub {
    require EV::WebKit::Client;
    require EV::WebKit::Client::Element;

    for my $pkg ('EV::WebKit::Client', 'EV::WebKit::Client::Element') {
        # Read the POD out of the very file the symbols came from, so a stale
        # blib cannot be compared against a freshly edited lib/ (or vice versa).
        (my $inc = "$pkg.pm") =~ s{::}{/}g;
        my $file = $INC{$inc} or die "$pkg not loaded?";
        open my $fh, '<', $file or die "$file: $!";
        my $src = do { local $/; <$fh> };
        my ($pod) = $src =~ /^(=head1 NAME.*)/ms;
        my %named = map { $_ => 1 } ($pod // '') =~ /C<(\w+)>/g;   # C<name> anywhere in its POD counts

        no strict 'refs';
        # SCREAMING_CASE is a `use constant`, not a method: constants are subs in
        # the symbol table too, and this guard is about the generated METHOD
        # lists the POD writes out by hand.
        my @public = sort grep { !/^_/ && !/^[A-Z0-9_]+$/ && $_ ne 'DESTROY'
                                 && defined &{"${pkg}::$_"} }
                     keys %{"${pkg}::"};
        cmp_ok(scalar @public, '>', 10, "$pkg: found its methods to check");
        my @undocumented = grep { !$named{$_} } @public;
        is_deeply(\@undocumented, [], "$pkg: every method it defines is named in its POD")
            or diag("undocumented: @undocumented");
    }
};

done_testing;
