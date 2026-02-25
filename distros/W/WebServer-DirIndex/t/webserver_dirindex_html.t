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
unlike $file_tmpl, qr{class='icon'}, 'file_html() without icons has no icon cell';

my $dir_tmpl = $html->dir_html;
ok defined $dir_tmpl,             'dir_html() returns a value';
like $dir_tmpl, qr{%s},           'dir_html() contains sprintf placeholders';
like $dir_tmpl, qr{<html>},       'dir_html() contains html tag';
like $dir_tmpl, qr{<table>},      'dir_html() contains table tag';
like $dir_tmpl, qr{Last Modified},'dir_html() contains Last Modified header';
unlike $dir_tmpl, qr{font-awesome}, 'dir_html() without icons omits Font Awesome';

my $html_icons = WebServer::DirIndex::HTML->new(icons => 1);

my $file_tmpl_icons = $html_icons->file_html;
ok defined $file_tmpl_icons,               'file_html() with icons returns a value';
like $file_tmpl_icons, qr{class='icon'},   'file_html() with icons contains icon cell';
like $file_tmpl_icons, qr{class='name'},   'file_html() with icons contains name cell';
my $icon_count_method = () = $file_tmpl_icons =~ /%s/g;
is $icon_count_method, 6, 'file_html() with icons has 6 sprintf placeholders';

my $dir_tmpl_icons = $html_icons->dir_html;
ok defined $dir_tmpl_icons,                'dir_html() with icons returns a value';
like $dir_tmpl_icons, qr{font-awesome},    'dir_html() with icons links to Font Awesome';
like $dir_tmpl_icons, qr{class='icon'},    'dir_html() with icons contains icon column header';

my $file_icons_tmpl = $html->file_html_icons;
ok defined $file_icons_tmpl,                   'file_html_icons() returns a value';
like $file_icons_tmpl, qr{%s},                 'file_html_icons() contains sprintf placeholders';
like $file_icons_tmpl, qr{<tr>},               'file_html_icons() contains a table row';
like $file_icons_tmpl, qr{class='icon'},        'file_html_icons() contains icon cell';
like $file_icons_tmpl, qr{class='name'},        'file_html_icons() contains name cell';

my $icon_count = () = $file_icons_tmpl =~ /%s/g;
is $icon_count, 6, 'file_html_icons() has 6 sprintf placeholders';

my $dir_icons_tmpl = $html->dir_html_icons;
ok defined $dir_icons_tmpl,                     'dir_html_icons() returns a value';
like $dir_icons_tmpl, qr{%s},                   'dir_html_icons() contains sprintf placeholders';
like $dir_icons_tmpl, qr{<html>},               'dir_html_icons() contains html tag';
like $dir_icons_tmpl, qr{<table>},              'dir_html_icons() contains table tag';
like $dir_icons_tmpl, qr{Last Modified},        'dir_html_icons() contains Last Modified header';
like $dir_icons_tmpl, qr{font-awesome},         'dir_html_icons() links to Font Awesome';
like $dir_icons_tmpl, qr{class='icon'},         'dir_html_icons() contains icon column header';

done_testing;
