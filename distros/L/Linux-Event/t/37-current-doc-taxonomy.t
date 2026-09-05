use v5.36;
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use File::Spec;

my $root = File::Spec->catdir($Bin, '..');

my @current_docs = qw(
    README.md
    docs/ARCHITECTURE.md
    docs/CHOOSING-A-FRAMER.md
    docs/CORE.md
    docs/DGRAM-DESIGN.md
    docs/EVENT-DESIGN.md
    docs/FRAMING.md
    docs/INTROSPECTION.md
    docs/IO-KERNEL-ARCHITECTURE.md
    docs/LISTENER-DESIGN.md
    docs/OBJECT-LIFECYCLE.md
    docs/ORDERED-BYTE-CONSUMER-ABI.md
    docs/ORDERED-BYTE-DEADLINES.md
    docs/ORDERED-BYTE-IO-DESIGN.md
    docs/PROCESS-DESIGN.md
    docs/SIGNAL-DESIGN.md
    docs/SOCKET-CONFIGURATION.md
    docs/SOCKET-CONNECTIONS.md
    docs/TIMER-DESIGN.md
    docs/TRANSPORT-BOUNDARY.md
    bench/README.md
    bench/STREAM-COMPETITOR-PLAN.md
);

my @stale_release_state = (
    qr/before the next public release/i,
    qr/while the public API (?:moves|is moving)\b/i,
    qr/during (?:the )?(?:public )?(?:architecture|namespace) migration/i,
    qr/while the implementation migration is completed/i,
    qr/private migration (?:machinery|implementation)/i,
    qr/^## Internal migration\s*$/mi,
    qr/\bThe current migration\b/i,
    qr/\bThis namespace migration\b/i,
    qr/\bThis migration deliberately\b/i,
    qr/during this architecture migration/i,
    qr/current release work is moving/i,
);

my $retired_parent = qr{
    use\s+parent\s+['"]Linux::Event::
    (?:Stream|Socket|Listener|Datagram|Timer|Signal|Wakeup|Process)['"]
}x;

sub pod_text ($text) {
    return $1 if $text =~ /^__END__\s*\R(.*)\z/ms;
    return $1 if $text =~ /(^=head1\b.*)\z/ms;
    return '';
}

for my $relative (@current_docs) {
    my $path = File::Spec->catfile($root, split m{/}, $relative);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $text = <$fh>;
    close $fh;

    for my $pattern (@stale_release_state) {
        unlike($text, $pattern,
            "$relative does not describe the released architecture as an unfinished migration");
    }

    unlike($text, $retired_parent,
        "$relative does not subclass a retired top-level resource class in current guidance");
}

for my $relative (glob(File::Spec->catfile($root, 'examples', '*.pl'))) {
    open my $fh, '<', $relative or die "open $relative: $!";
    local $/;
    my $text = <$fh>;
    close $fh;
    unlike($text, $retired_parent,
        "$relative uses the current IO/Kernel subclassing surface");
}

my $makefile_pl = File::Spec->catfile($root, 'Makefile.PL');
open my $makefile_fh, '<', $makefile_pl or die "open $makefile_pl: $!";
local $/;
my $makefile_src = <$makefile_fh>;
close $makefile_fh;

my ($public_module_block) = $makefile_src =~
    /my \@public_modules = qw\(\s*(.*?)\s*\);/s;
ok(defined $public_module_block,
    'Makefile.PL declares the public module source of truth');

my @public_modules = grep { length }
    split /\s+/, ($public_module_block // '');
my %public_module = map { $_ => 1 } @public_modules;

for my $private (qw(
    Linux::Event::Stream
    Linux::Event::Socket
    Linux::Event::Listener
    Linux::Event::Datagram
    Linux::Event::Timer
    Linux::Event::Signal
    Linux::Event::Wakeup
    Linux::Event::Process
)) {
    ok(!$public_module{$private},
        "$private is not in the public module/manpage source list");
}

like($makefile_src, qr/my \%man3pods = map \{.*?\} \@public_modules;/s,
    'manpage mapping is derived from the public module source of truth');
like($makefile_src, qr/MAN3PODS\s*=>\s*\\%man3pods/,
    'MakeMaker receives the public-only MAN3PODS mapping');

for my $module (@public_modules) {
    (my $relative = "lib/$module.pm") =~ s{::}{/}g;
    my $path = File::Spec->catfile($root, split m{/}, $relative);
    open my $fh, '<', $path or die "open $path: $!";
    local $/;
    my $text = <$fh>;
    close $fh;
    my $pod = pod_text($text);
    unlike($pod, $retired_parent,
        "$module public POD does not teach retired top-level inheritance");
}

done_testing;
