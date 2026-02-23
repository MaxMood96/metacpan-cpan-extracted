use strict;
use warnings;
use Feature::Compat::Class;

class WebServer::DirIndex::HTML v0.0.2 {

  field $file_html :reader = <<'FILE';
  <tr>
    <td class='name'><a href='%s'>%s</a></td>
    <td class='size'>%s</td>
    <td class='type'>%s</td>
    <td class='mtime'>%s</td>
  </tr>
FILE

  field $dir_html :reader = <<'DIR';
<html>
  <head>
    <title>%s</title>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
    <style type='text/css'>
%s
    </style>
  </head>
  <body>
    <h1>%s</h1>
    <hr />
    <table>
      <thead>
        <tr>
          <th class='name'>Name</th>
          <th class='size'>Size</th>
          <th class='type'>Type</th>
          <th class='mtime'>Last Modified</th>
        </tr>
      </thead>
      <tbody>
%s
      </tbody>
    </table>
    <hr />
  </body>
</html>
DIR
}

1;

__END__

=head1 NAME

WebServer::DirIndex::HTML - HTML rendering for directory index pages

=head1 SYNOPSIS

  use WebServer::DirIndex::HTML;

  my $html      = WebServer::DirIndex::HTML->new;
  my $file_tmpl = $html->file_html;
  my $dir_tmpl  = $html->dir_html;

=head1 DESCRIPTION

This module provides HTML template strings used to render a directory
index page. The actual rendering is performed by L<WebServer::DirIndex>.

=head1 METHODS

=over 4

=item file_html

Returns a C<sprintf> format string used to render a single file row.

=item dir_html

Returns a C<sprintf> format string used to render the full directory
index page.

=back

=head1 SUBCLASSING

You can subclass this module to provide custom HTML templates. Override
C<file_html> and/or C<dir_html> in your subclass by declaring new fields
with the C<:reader> attribute.

Both templates are C<sprintf> format strings. The placeholders (C<%s>) are
positional and must be preserved in the correct order:

=over 4

=item file_html placeholders (5 total, in order)

C<url>, C<name>, C<size>, C<mime_type>, C<mtime>.

=item dir_html placeholders (4 total, in order)

Page C<title>, inline C<css>, page C<heading>, C<file rows>.

=back

Pass your subclass name as the C<html_class> parameter when constructing
L<WebServer::DirIndex> or L<WebServer::DirIndex::File>.

=head1 AUTHOR

Dave Cross E<lt>dave@perlhacks.comE<gt>

=head1 COPYRIGHT

Copyright (c) 2026 Magnum Solutions Limited. All rights reserved.

=head1 LICENCE

This code is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item L<WebServer::DirIndex>

=item L<WebServer::DirIndex::CSS>

=item L<Plack::App::DirectoryIndex>

=back

=cut
