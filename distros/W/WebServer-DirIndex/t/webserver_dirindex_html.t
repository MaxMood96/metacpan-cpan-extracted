use strict;
use warnings;
use Test::More;
use WebServer::DirIndex::HTML;

my $html = WebServer::DirIndex::HTML->new;

my $file_tmpl = $html->file_html;
ok defined $file_tmpl,      'file_html() returns a value';
like $file_tmpl, qr{%s},    'file_html() contains sprintf placeholders';
like $file_tmpl, qr{<tr>},  'file_html() contains a table row';
like $file_tmpl, qr{class='name'}, 'file_html() contains name cell';

my $dir_tmpl = $html->dir_html;
ok defined $dir_tmpl,             'dir_html() returns a value';
like $dir_tmpl, qr{%s},           'dir_html() contains sprintf placeholders';
like $dir_tmpl, qr{<html>},       'dir_html() contains html tag';
like $dir_tmpl, qr{<table>},      'dir_html() contains table tag';
like $dir_tmpl, qr{Last Modified},'dir_html() contains Last Modified header';

done_testing;
