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

done_testing;
