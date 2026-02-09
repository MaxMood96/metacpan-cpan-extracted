use strict;
use warnings;

use Test::More;

use File::Temp qw(tempdir);
use File::Spec;

use Flat::Profile;

my $dir  = tempdir(CLEANUP => 1);
my $file = File::Spec->catfile($dir, "meta.csv");

open my $fh, ">:encoding(UTF-8)", $file or die "open write: $!";
print {$fh} "a\n";
print {$fh} "x\n";
close $fh or die "close: $!";

my $profiler = Flat::Profile->new();

my $r = $profiler->profile_file(
    path       => $file,
    has_header => 1,
);

is($r->{report_version}, 1, "report_version is 1");
ok(defined $r->{generated_at}, "generated_at present");
like($r->{generated_at}, qr/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/, "generated_at format");

ok(defined $r->{perl_version}, "perl_version present");
ok($r->{perl_version} > 0, "perl_version looks sane");

ok(defined $r->{module_version}, "module_version present");

done_testing;
