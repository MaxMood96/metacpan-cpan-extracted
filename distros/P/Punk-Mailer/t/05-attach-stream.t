use strict;
use warnings;
use Test::More;
use File::Temp ();
use lib 't/lib';
use MIMERead;
BEGIN { do './t/sibling.pl' }
use Punk::Mailer;

# An attachment named by path is read in chunks as it is encoded and is
# never held whole. Measured, not asserted: the process's resident size
# before and after building a message with a 64 MiB attachment through a
# sink that keeps nothing.

sub rss_kb {
    my $out = `ps -o rss= -p $$ 2>/dev/null`;
    return $out =~ /(\d+)/ ? $1 : undef;
}

plan skip_all => 'ps -o rss is not available here' unless defined rss_kb();

my $dir  = File::Temp->newdir;
my $big  = "$dir/big.bin";
my $MB   = 1024 * 1024;
my $size = 64 * $MB;
{
    open my $fh, '>', $big or die $!;
    binmode $fh;
    my $chunk = join '', map { chr($_ & 255) } 0 .. 65535;   # 64 KiB, all byte values
    print $fh $chunk for 1 .. $size / length $chunk;
    close $fh;
}
is(-s $big, $size, 'a 64 MiB file');

my %spec = (
    from => 'ops@example.com', to => 'a@example.com', subject => 'big',
    text => "see attached\n",
    attachments => [ { path => $big, filename => 'big.bin',
                       type => 'application/octet-stream' } ],
);

# warm everything that allocates once, so the measurement is the build
{
    my $small = { %spec, attachments => [ { content => 'x' x 1000, filename => 's' } ] };
    Punk::Mailer->build_to($small, sub { });
}

my $before = rss_kb();
my $total  = 0;
my $chunks = 0;
Punk::Mailer->build_to(\%spec, sub { $total += length $_[0]; $chunks++ });
my $after  = rss_kb();

my $growth_mb = ($after - $before) / 1024;
diag sprintf 'RSS before %.1f MiB, after %.1f MiB, growth %.1f MiB, %d chunks',
    $before / 1024, $after / 1024, $growth_mb, $chunks;
cmp_ok($growth_mb, '<', 8, 'building a 64 MiB attachment grew RSS by under 8 MiB');
cmp_ok($chunks, '>', 1000, 'the attachment went out in many chunks');

my $encoded = Punk::Mailer::_b64_wrapped_len($size);
cmp_ok($total, '>', $encoded, 'the message is larger than the encoded attachment alone');
cmp_ok($total - $encoded, '<', 2048, 'by only headers and boundaries');

# and the bytes are right: a smaller file, decoded whole through the reader
{
    my $small = "$dir/small.bin";
    my $blob  = join '', map { chr int rand 256 } 1 .. 200_000;
    open my $fh, '>', $small or die $!; binmode $fh; print $fh $blob; close $fh;
    my $m = MIMERead::parse(Punk::Mailer->build({ %spec,
        attachments => [ { path => $small, filename => 'small.bin' } ] }));
    is($m->{parts}[1]{body}, $blob, 'a streamed attachment decodes to the file');
}

done_testing;
