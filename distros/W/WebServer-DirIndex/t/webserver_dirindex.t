use strict;
use warnings;
use Test::More;
use File::Temp qw[tempdir];
use WebServer::DirIndex;

my $dir = tempdir(CLEANUP => 1);

# Create some test files
open my $fh, '>', "$dir/file.txt" or die $!;
print $fh "hello";
close $fh;

mkdir "$dir/subdir" or die $!;

my $di = WebServer::DirIndex->new(dir => $dir, dir_url => '/test/');

ok defined $di, 'WebServer::DirIndex->new returns an object';

my @files = $di->files;
ok @files > 0, 'files() returns entries';

my ($parent) = grep { $_->[1] eq 'Parent Directory' } @files;
ok defined $parent, 'files() includes Parent Directory entry';
is $parent->[0], '../', 'Parent Directory has correct URL';

my ($file) = grep { $_->[1] eq 'file.txt' } @files;
ok defined $file, 'files() includes file.txt';
like $file->[0], qr{file\.txt}, 'file.txt has correct URL';
is $file->[3], 'text/plain', 'file.txt has correct MIME type';

my ($subdir) = grep { $_->[1] eq 'subdir/' } @files;
ok defined $subdir, 'files() includes subdir/';
is $subdir->[3], 'directory', 'subdir has correct MIME type';

my $html = $di->to_html('/test/', 0);
ok defined $html, 'to_html() returns a value';
like $html, qr{Index of /test/}, 'to_html() contains correct heading';
like $html, qr{file\.txt},       'to_html() contains file.txt';
like $html, qr{subdir/},         'to_html() contains subdir/';
unlike $html, qr{a:link},        'to_html() without pretty uses standard CSS';

my $html_pretty = $di->to_html('/test/', 1);
ok defined $html_pretty, 'to_html(pretty) returns a value';
like $html_pretty, qr{a:link}, 'to_html(pretty) uses pretty CSS';
isnt $html, $html_pretty, 'pretty and non-pretty HTML differ';

done_testing;
