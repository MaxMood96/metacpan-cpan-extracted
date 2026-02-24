use strict;
use warnings;
use Test::More;
use WebServer::DirIndex::File;

my $file = WebServer::DirIndex::File->new(
  url       => '/test/file.txt',
  name      => 'file.txt',
  size      => 1234,
  mime_type => 'text/plain',
  mtime     => 'Thu, 01 Jan 2026 00:00:00 GMT',
);

ok defined $file, 'WebServer::DirIndex::File->new returns an object';
is $file->url,       '/test/file.txt',              'url() returns correct value';
is $file->name,      'file.txt',                    'name() returns correct value';
is $file->size,      1234,                          'size() returns correct value';
is $file->mime_type, 'text/plain',                  'mime_type() returns correct value';
is $file->mtime,     'Thu, 01 Jan 2026 00:00:00 GMT', 'mtime() returns correct value';
is $file->icon,      undef,                         'icon() defaults to undef';

my $parent = WebServer::DirIndex::File->parent_dir;
ok defined $parent, 'parent_dir() returns an object';
is $parent->url,       '../',             'parent_dir() has correct URL';
is $parent->name,      'Parent Directory','parent_dir() has correct name';
is $parent->size,      '',               'parent_dir() has empty size';
is $parent->mime_type, '',               'parent_dir() has empty mime_type';
is $parent->mtime,     '',               'parent_dir() has empty mtime';

my $row = $file->to_html;
ok defined $row,                       'to_html() returns a value';
like $row, qr{<tr>},                   'to_html() contains a table row';
like $row, qr{/test/file\.txt},        'to_html() contains the URL';
like $row, qr{file\.txt},              'to_html() contains the name';
like $row, qr{1234},                   'to_html() contains the size';
like $row, qr{text/plain},             'to_html() contains the mime type';
like $row, qr{Thu, 01 Jan 2026},       'to_html() contains the mtime';

my $special = WebServer::DirIndex::File->new(
  url       => '/test/a&b.txt',
  name      => '<bold>',
  size      => 0,
  mime_type => 'text/plain',
  mtime     => '',
);
my $special_row = $special->to_html;
like $special_row, qr{&amp;},  'to_html() HTML-escapes & in URL';
like $special_row, qr{&lt;},   'to_html() HTML-escapes < in name';

# Custom html_class
{
  package My::HTML;
  use strict;
  use warnings;
  use Feature::Compat::Class;
  class My::HTML v0.0.1 {
    field $file_html :reader = "CUSTOM:%s|%s|%s|%s|%s\n";
  }
}

my $custom_file = WebServer::DirIndex::File->new(
  url       => '/test/file.txt',
  name      => 'file.txt',
  size      => 1234,
  mime_type => 'text/plain',
  mtime     => 'Thu, 01 Jan 2026 00:00:00 GMT',
  html_class => 'My::HTML',
);
my $custom_row = $custom_file->to_html;
like $custom_row, qr{^CUSTOM:}, 'to_html() uses custom html_class template';
like $custom_row, qr{file\.txt}, 'custom html_class template contains file name';

my $custom_parent = WebServer::DirIndex::File->parent_dir(html_class => 'My::HTML');
is $custom_parent->url,  '../',             'parent_dir() with html_class has correct URL';
like $custom_parent->to_html, qr{^CUSTOM:}, 'parent_dir() uses custom html_class in to_html';

# File with icon set uses file_html_icons template
my $icon_file = WebServer::DirIndex::File->new(
  url       => '/test/file.pdf',
  name      => 'file.pdf',
  size      => 5678,
  mime_type => 'application/pdf',
  mtime     => 'Thu, 01 Jan 2026 00:00:00 GMT',
  icon      => 'fa-solid fa-file-pdf',
);
is $icon_file->icon, 'fa-solid fa-file-pdf', 'icon() returns correct value';
my $icon_row = $icon_file->to_html;
like $icon_row, qr{fa-solid fa-file-pdf}, 'to_html() includes icon class when icon is set';
like $icon_row, qr{class='icon'},          'to_html() includes icon cell when icon is set';
like $icon_row, qr{file\.pdf},             'to_html() includes file name with icon';

# Without icon, to_html falls back to file_html (no icon column)
my $no_icon_row = $file->to_html;
unlike $no_icon_row, qr{class='icon'}, 'to_html() with no icon uses icon-less template';

# icons => 1 auto-derives icon from mime_type
my $auto_icon_file = WebServer::DirIndex::File->new(
  url       => '/test/file.pdf',
  name      => 'file.pdf',
  size      => 5678,
  mime_type => 'application/pdf',
  mtime     => 'Thu, 01 Jan 2026 00:00:00 GMT',
  icons     => 1,
);
is $auto_icon_file->icon, 'fa-solid fa-file-pdf',
  'icons => 1 auto-derives PDF icon from mime_type';
like $auto_icon_file->to_html, qr{fa-solid fa-file-pdf},
  'to_html() with icons => 1 includes auto-derived icon';

my $auto_icon_dir = WebServer::DirIndex::File->new(
  url       => 'subdir/',
  name      => 'subdir/',
  size      => '',
  mime_type => 'directory',
  mtime     => '',
  icons     => 1,
);
is $auto_icon_dir->icon, 'fa-solid fa-folder',
  'icons => 1 auto-derives folder icon for directories';

my $auto_icon_parent = WebServer::DirIndex::File->parent_dir(icons => 1);
is $auto_icon_parent->icon, 'fa-solid fa-arrow-up',
  'parent_dir(icons => 1) auto-derives arrow-up icon';

my $auto_icon_image = WebServer::DirIndex::File->new(
  url       => '/test/photo.jpg',
  name      => 'photo.jpg',
  size      => 9999,
  mime_type => 'image/jpeg',
  mtime     => '',
  icons     => 1,
);
is $auto_icon_image->icon, 'fa-solid fa-file-image',
  'icons => 1 auto-derives image icon for image/* MIME type';

# Explicit icon takes precedence over icons => 1
my $explicit_icon_file = WebServer::DirIndex::File->new(
  url       => '/test/file.txt',
  name      => 'file.txt',
  size      => 0,
  mime_type => 'text/plain',
  mtime     => '',
  icon      => 'fa-solid fa-custom',
  icons     => 1,
);
is $explicit_icon_file->icon, 'fa-solid fa-custom',
  'explicit icon takes precedence over icons => 1 auto-derivation';

done_testing;
