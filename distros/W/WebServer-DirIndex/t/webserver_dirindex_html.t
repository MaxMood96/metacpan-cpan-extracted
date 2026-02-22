use strict;
use warnings;
use Test::More;
use WebServer::DirIndex::HTML;

my @files = (
  [ '../',     'Parent Directory', '',    '',          ''                    ],
  [ 'file.txt','file.txt',         1234,  'text/plain','Thu, 01 Jan 2026 00:00:00 GMT'],
  [ 'subdir/', 'subdir/',          0,     'directory', 'Thu, 01 Jan 2026 00:00:00 GMT'],
);

my $html_obj = WebServer::DirIndex::HTML->new(
  path_info => '/some/dir/',
  files     => \@files,
);

ok defined $html_obj, 'WebServer::DirIndex::HTML->new returns an object';

my $file_tmpl = $html_obj->file_html;
ok defined $file_tmpl,      'file_html() returns a value';
like $file_tmpl, qr{%s},    'file_html() contains sprintf placeholders';
like $file_tmpl, qr{<tr>},  'file_html() contains a table row';
like $file_tmpl, qr{class='name'}, 'file_html() contains name cell';

my $dir_tmpl = $html_obj->dir_html;
ok defined $dir_tmpl,             'dir_html() returns a value';
like $dir_tmpl, qr{%s},           'dir_html() contains sprintf placeholders';
like $dir_tmpl, qr{<html>},       'dir_html() contains html tag';
like $dir_tmpl, qr{<table>},      'dir_html() contains table tag';
like $dir_tmpl, qr{Last Modified},'dir_html() contains Last Modified header';

my $page = $html_obj->render;
ok defined $page,                    'render() returns a value';
like $page, qr{Index of /some/dir/}, 'render() contains correct heading';
like $page, qr{file\.txt},           'render() contains file.txt';
like $page, qr{subdir/},             'render() contains subdir/';
unlike $page, qr{a:link},            'render() without pretty uses standard CSS';

my $pretty_obj = WebServer::DirIndex::HTML->new(
  path_info => '/some/dir/',
  files     => \@files,
  pretty    => 1,
);

my $pretty_page = $pretty_obj->render;
ok defined $pretty_page,        'render() with pretty returns a value';
like $pretty_page, qr{a:link},  'render() with pretty uses pretty CSS';
isnt $page, $pretty_page,       'pretty and non-pretty pages differ';

done_testing;
