use strict;
use warnings;
use Feature::Compat::Class;

class WebServer::DirIndex::HTML v0.0.1 {

  use Plack::Util;
  use WebServer::DirIndex::CSS;

  field $path_info :param;
  field $files     :param;
  field $pretty    :param = 0;

  method file_html {
    return <<'FILE';
  <tr>
    <td class='name'><a href='%s'>%s</a></td>
    <td class='size'>%s</td>
    <td class='type'>%s</td>
    <td class='mtime'>%s</td>
  </tr>
FILE
  }

  method dir_html {
    return <<'DIR';
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

  method render {
    my $path = Plack::Util::encode_html("Index of $path_info");
    my $files_html = join "\n", map {
      my $f = $_;
      sprintf $self->file_html, map { Plack::Util::encode_html($_) } @$f;
    } @$files;
    my $css = WebServer::DirIndex::CSS->new(pretty => $pretty)->css;
    return sprintf $self->dir_html, $path, $css, $path, $files_html;
  }
}

1;

__END__

=head1 NAME

WebServer::DirIndex::HTML - HTML rendering for directory index pages

=head1 SYNOPSIS

  use WebServer::DirIndex::HTML;

  my $html = WebServer::DirIndex::HTML->new(
    path_info => '/some/dir/',
    files     => \@files,
    pretty    => 0,
  );

  my $page = $html->render;

=head1 DESCRIPTION

This module renders an HTML directory index page from a list of file
entries. It provides the HTML templates used to generate the page.

=head1 CONSTRUCTOR

=over 4

=item new(%args)

Creates a new C<WebServer::DirIndex::HTML> object. Accepts the following
named parameters:

=over 4

=item path_info

The request path info (e.g. C</some/dir/>). Used as the page title and heading.

=item files

An arrayref of file entries. Each entry is an arrayref of
C<[$url, $name, $size, $type, $mtime]>.

=item pretty

If true, uses an enhanced CSS stylesheet for a more attractive appearance.
Defaults to false.

=back

=back

=head1 METHODS

=over 4

=item file_html

Returns a C<sprintf> format string used to render a single file row.

=item dir_html

Returns a C<sprintf> format string used to render the full directory
index page.

=item render

Generates and returns the complete HTML directory index page.

=back

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
