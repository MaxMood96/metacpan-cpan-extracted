package Plack::Middleware::DirIndex::Htaccess;
$Plack::Middleware::DirIndex::Htaccess::VERSION = '1.00';

# ABSTRACT: Check .htaccess file for DirectoryIndex

use parent qw( Plack::Middleware );
use Plack::Util::Accessor qw(dir_index root);
use strict;
use warnings;
use 5.006;

sub check_htaccess {
    my ($self, $dir) = @_;

    my $htaccess_file = "${dir}.htaccess";
    return unless (-f $htaccess_file);

    open my $fh, '<:encoding(UTF-8)', $htaccess_file
		or die "Cannot open $htaccess_file $!";

     local $/;
     my $content = <$fh>;
     close $fh;

     my $dir_index;
     if ($content =~ /^DirectoryIndex\s(.*?)$/) {
       $dir_index = $1;
      }

    return $dir_index;
}

sub prepare_app {
    my ($self) = @_;

    $self->root('.')               unless $self->root;
    $self->dir_index('index.html') unless $self->dir_index;
}

sub call {
    my ( $self, $env ) = @_;

    my $index;
    if ( $env->{PATH_INFO} =~ m{/$} ) {
      my $dir = $self->root . $env->{PATH_INFO};
      $index = $self->check_htaccess( $dir );
      if (!$index && -f $dir . $self->dir_index()) {
        $index = $self->dir_index();
       }
    }

    if ($index) {
      $env->{PATH_INFO} .= $index;
    }

    return $self->app->($env);
}

1;

=head1 NAME

Plack::Middleware::DirIndex::Htaccess - Serve default html files for directory URLS. Includes checking of .htaccess file for DirectoryIndex.

=head1 SYNOPSIS

  use Plack::Builder;
  use Plack::App::Directory;

  my $app = Plack::App::Directory->new()->to_app;

  builder {
      enable "DirIndex::Htaccess", root => '.', dir_index => 'index.html';
      $app;
  };

=head1 DESCRIPTION

The Apache web server uses the C<DirectoryIndex> directive within
C<.htaccess> files to automatically serve a default page
(e.g., C<about.html> when a user requests a directory URL like C</about/>).

This Plack middleware provides a lightweight simulation of
Apache's DirectoryIndex functionality for your local Plack environment.
By reading the C<DirectoryIndex> from your existing C<.htaccess> files,
it ensures that requests to directories resolve to the correct default
file, just as they would on the live server.

If there is no c<DirectoryIndex> directive (or C<.htaccess> file), the module will append the value of <dir_index> (defaults to C<index.html>) if the file exists, like Plack::Middleware::DirIndex.

=head1 AUTHOR

Keith Carangelo <kcaran@gmail.com>

=cut
