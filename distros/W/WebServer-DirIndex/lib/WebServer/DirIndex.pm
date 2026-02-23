use strict;
use warnings;
use Feature::Compat::Class;
use WebServer::DirIndex::HTML;

class WebServer::DirIndex v0.0.2 {

  use Path::Tiny;
  use HTTP::Date;
  use HTML::Escape qw(escape_html);
  use MIME::Types;
  use URI::Escape;
  use WebServer::DirIndex::CSS;
  use WebServer::DirIndex::File;

  my $mime_types = MIME::Types->new;

  field $dir        :param;
  field $dir_url    :param;
  field $html_class :param = 'WebServer::DirIndex::HTML';
  field $css_class  :param = 'WebServer::DirIndex::CSS';
  field $_html_obj = $html_class->new;
  field @files;

  ADJUST {
    @files = ( WebServer::DirIndex::File->parent_dir(html_class => $html_class) );

    my @children = map { $_->basename } path($dir)->children;

    for my $basename (sort { $a cmp $b } @children) {
      my $file = "$dir/$basename";
      my $url  = $dir_url . $basename;

      my $is_dir = -d $file;
      my @stat   = stat $file;

      $url = join '/', map { uri_escape($_) } split m{/}, $url;

      if ($is_dir) {
        $basename .= '/';
        $url      .= '/';
      }

      my $type_obj  = $is_dir ? undef : $mime_types->mimeTypeOf($file);
      my $mime_type = $is_dir
        ? 'directory'
        : ($type_obj ? $type_obj->type : 'text/plain');

      push @files, WebServer::DirIndex::File->new(
        url        => $url,
        name       => $basename,
        size       => $stat[7],
        mime_type  => $mime_type,
        mtime      => HTTP::Date::time2str($stat[9]),
        html_class => $html_class,
      );
    }
  }

  method files { return @files }

  method to_html ($path_info, $pretty = 0) {
    my $path = escape_html("Index of $path_info");
    my $files_html = join "\n", map { $_->to_html } @files;
    my $css = $css_class->new(pretty => $pretty)->css;
    return sprintf $_html_obj->dir_html,
      $path, $css, $path, $files_html;
  }
}

1;

__END__

=head1 NAME

WebServer::DirIndex - Directory index data for web server listings

=head1 SYNOPSIS

  use WebServer::DirIndex;

  my $di = WebServer::DirIndex->new(
    dir     => '/path/to/dir',
    dir_url => '/some/dir/',
  );

  # Get the list of file entries
  my @files = $di->files;

  # Generate an HTML directory index page
  my $html = $di->to_html('/some/dir/', $pretty);

=head1 DESCRIPTION

This module reads a filesystem directory and builds the data required
to render a directory index page for a web server. It provides access
to the list of file entries and can generate an HTML page via
L<WebServer::DirIndex::HTML>.

=head1 CONSTRUCTOR

=over 4

=item new(%args)

Creates a new C<WebServer::DirIndex> object and reads the directory.
Accepts the following named parameters:

=over 4

=item dir

The filesystem path to the directory to index.

=item dir_url

The URL path corresponding to the directory (e.g. C</some/dir/>).
Used to construct file URLs.

=item html_class

Optional. The class name to use for HTML templates. Defaults to
C<WebServer::DirIndex::HTML>. Must provide C<file_html> and C<dir_html>
methods that return C<sprintf> format strings.

=item css_class

Optional. The class name to use for CSS stylesheets. Defaults to
C<WebServer::DirIndex::CSS>. Must provide a C<new(pretty => $bool)>
constructor and a C<css> method that returns a stylesheet string.

=back

=back

=head1 METHODS

=over 4

=item files

Returns the list of file entries for the directory. Each entry is a
L<WebServer::DirIndex::File> object. The first entry is always the
parent directory (C<../>).

=item to_html($path_info, $pretty)

Generates and returns a complete HTML directory index page using
L<WebServer::DirIndex::HTML> for templates and L<WebServer::DirIndex::CSS>
for styling. C<$path_info> is the request path info used as the page title
and heading. If C<$pretty> is true, an enhanced CSS stylesheet is used.

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

=item L<WebServer::DirIndex::File>

=item L<WebServer::DirIndex::HTML>

=item L<WebServer::DirIndex::CSS>

=item L<Plack::App::DirectoryIndex>

=back

=cut
