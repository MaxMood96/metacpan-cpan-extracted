use strict;
use warnings;
use Feature::Compat::Class;

class WebServer::DirIndex v0.0.1 {

  use Path::Tiny;
  use HTTP::Date;
  use Plack::MIME;
  use URI::Escape;
  use WebServer::DirIndex::HTML;

  field $dir     :param;
  field $dir_url :param;
  field @files;

  ADJUST {
    @files = ( [ '../', 'Parent Directory', '', '', '' ] );

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

      my $mime_type = $is_dir
        ? 'directory'
        : (Plack::MIME->mime_type($file) || 'text/plain');

      push @files, [ $url, $basename, $stat[7], $mime_type,
                     HTTP::Date::time2str($stat[9]) ];
    }
  }

  method files { return @files }

  method to_html ($path_info, $pretty = 0) {
    return WebServer::DirIndex::HTML->new(
      path_info => $path_info,
      files     => \@files,
      pretty    => $pretty,
    )->render;
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

=back

=back

=head1 METHODS

=over 4

=item files

Returns the list of file entries for the directory. Each entry is an
arrayref of C<[$url, $name, $size, $mime_type, $mtime]>. The first
entry is always the parent directory (C<../>).

=item to_html($path_info, $pretty)

Generates and returns a complete HTML directory index page by delegating
to L<WebServer::DirIndex::HTML>. C<$path_info> is the request path info
used as the page title and heading. If C<$pretty> is true, an enhanced
CSS stylesheet is used.

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

=item L<WebServer::DirIndex::HTML>

=item L<WebServer::DirIndex::CSS>

=item L<Plack::App::DirectoryIndex>

=back

=cut
