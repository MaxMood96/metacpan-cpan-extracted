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

my ($parent) = grep { $_->name eq 'Parent Directory' } @files;
ok defined $parent, 'files() includes Parent Directory entry';
is $parent->url, '../', 'Parent Directory has correct URL';

my ($file) = grep { $_->name eq 'file.txt' } @files;
ok defined $file, 'files() includes file.txt';
like $file->url, qr{file\.txt}, 'file.txt has correct URL';
is $file->mime_type, 'text/plain', 'file.txt has correct MIME type';

my ($subdir) = grep { $_->name eq 'subdir/' } @files;
ok defined $subdir, 'files() includes subdir/';
is $subdir->mime_type, 'directory', 'subdir has correct MIME type';

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

# Custom html_class and css_class
{
  package My::DirHTML;
  use strict;
  use warnings;
  use Feature::Compat::Class;
  class My::DirHTML v0.0.1 {
    field $file_html :reader = "FILE:%s|%s|%s|%s|%s\n";
    field $dir_html  :reader = "DIR:%s|%s|%s|%s\n";
  }
}

{
  package My::DirCSS;
  use strict;
  use warnings;
  use Feature::Compat::Class;
  class My::DirCSS v0.0.1 {
    field $pretty :param = 0;
    method css { return 'CUSTOM_CSS' }
  }
}

my $di_custom = WebServer::DirIndex->new(
  dir        => $dir,
  dir_url    => '/test/',
  html_class => 'My::DirHTML',
  css_class  => 'My::DirCSS',
);
ok defined $di_custom, 'WebServer::DirIndex->new accepts html_class and css_class';

my $html_custom = $di_custom->to_html('/test/', 0);
like $html_custom, qr{^DIR:},        'to_html() uses custom html_class dir_html';
like $html_custom, qr{CUSTOM_CSS},   'to_html() uses custom css_class';
like $html_custom, qr{^FILE:}m,      'to_html() uses custom html_class file_html for rows';

done_testing;
