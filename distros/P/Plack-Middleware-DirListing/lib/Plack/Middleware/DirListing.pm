package Plack::Middleware::DirListing;
# ABSTRACT: Display a directory listing if no default index html page

use parent qw( Plack::Middleware );
use DirHandle;
use HTML::Entities;
use Plack::Request;
use Plack::MIME;
use Plack::Util::Accessor qw( root );
use URI::Escape;
use Time::Piece;

use strict;
use warnings;
use v5.10;

sub dir_html {

  state $html = do {
    local $/ = undef;
    my $data_string = <DATA>;
    close DATA;

    $data_string =~ s/%(?!s)/%%/g;
    $data_string;
   };

  return $html;
}

sub file_html {
  return <<FILE;
  <tr>
    <td class="%s"></td>
    <td class="name"><a href="%s">%s</a></td>
    <td class="mtime">%s</td>
    <td class="size">%s</td>
    <td class="type">%s</td>
  </tr>
FILE
}

sub last_modified {
  my ($self, $date) = @_;

  return Time::Piece->new( $date )->strftime( "%d-%b-%Y %H:%M" );
 }

sub sort_order {
  my ($self, $env, $page) = @_;

  if (my ($field, $order) = $env->{ QUERY_STRING } =~ /C=(\w);O=(\w)/) {
    my $invert = ($order eq 'A') ? 'D' : 'A';
    $page =~ s/C=$field;O=$order/C=$field;O=$invert/;
   }

  return $page;
 }

my %col_sort = (
	'NA' => sub { $a->[2] cmp $b->[2] },
	'ND' => sub { $b->[2] cmp $a->[2] },
	'MA' => sub { $a->[6] <=> $b->[6] },
	'MD' => sub { $b->[6] <=> $a->[6] },
	'SA' => sub { $a->[4] <=> $b->[4] },
	'SD' => sub { $b->[4] <=> $a->[4] },
	'DA' => sub { $a->[5] cmp $b->[5] },
	'DD' => sub { $b->[5] cmp $a->[5] },
);

sub filetype_class {
  my ($self, $filetype) = @_;

  return 'ft_directory' if ($filetype eq 'directory');
  return 'ft_image' if ($filetype =~ /^image/);
  return 'ft_pdf' if ($filetype =~ /pdf$/);
  return 'ft_html' if ($filetype =~ /html$/);

  return '';
}


sub read_dir {
  my ($self, $env, $dir) = @_;

  my @files;

  my $dh = DirHandle->new($dir);

  while (defined(my $ent = $dh->read)) {
    next if $ent eq '.' or $ent eq '..';

    my $file = "$dir/$ent";
    my $url = $env->{PATH_INFO} . $ent;

    my $is_dir = -d $file;
    my @stat = stat _;

    $url = join '/', map {uri_escape($_)} split m{/}, $url;

    if ($is_dir) {
      $ent .= "/";
      $url .= "/";
    }

    my $mime_type = $is_dir ? 'directory' : ( Plack::MIME->mime_type($file) || 'text/plain' );
    my $filetype_class = $self->filetype_class( $mime_type );
    push @files, [ $filetype_class, $url, $ent, $self->last_modified( $stat[9] ), $stat[7], $mime_type, $stat[9] ];
  }

  my ($field, $order) = $env->{ QUERY_STRING } =~ /C=(\w);O=(\w)/;
  $field ||= 'N';
  $order ||= 'A';

  @files = sort { &{ $col_sort{ "$field$order" } } } @files;

  return [ [ 'ft_parent', "../", "Parent Directory", '', '', '', 0], @files ];
}

sub prepare_app {
    my ($self) = @_;

    $self->root('.')               unless $self->root;
}

# NOTE: Copied from Plack::App::Directory as that module makes it
# impossible to override the HTML.

sub serve_path {
  my $self = shift;
  my ($env, $dir) = @_;

  my $files = $self->read_dir( $env, $dir );

  my $path  = Plack::Util::encode_html("Index of $env->{PATH_INFO}");
  my $files_html = join "\n", map {
    my $f = $_;
    sprintf $self->file_html, map Plack::Util::encode_html($_), @{ $f }[ 0..5 ];
  } @{ $files };
  my $page  = sprintf $self->dir_html, $path, $path, $files_html, $env->{ HTTP_HOST };

  $page = $self->sort_order( $env, $page );

  return [ 200, ['Content-Type' => 'text/html; charset=utf-8'], [ $page ] ];
}

sub call {
    my ( $self, $env ) = @_;
    my $req = Plack::Request->new( $env );

    my $dir = $self->root . $req->path_info();
    if (-d $dir) {
        if (substr( $dir, -1 ) eq '/') {
          return $self->serve_path( $env, $dir );
         }
        else {
          my $uri = $req->uri();
          $uri->path( $uri->path . '/' );
          my $res = $req->new_response(301); # new Plack::Response
          $res->headers([
			'Location' => $uri,
			'Content-Type' => 'text/html; charset=UTF-8',
			'Cache-Control' => 'must-revalidate, max-age=3600'
			]);

          my $uhe = encode_entities($uri);
          $res->body( <<REDIRECT_BODY );
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN"><html><head><title>301 Moved Permanently</title></head><body><h1>Moved Permanently</h1><p>The document has moved <a href="$uhe">here</a>.</p></body></html>
REDIRECT_BODY

          return $res->finalize;
         }
    }

    return $self->app->($env);
}

=head1 NAME

Plack::Middleware::DirListing - Display a listing of a directory in html

=head1 SYNOPSIS

  use Plack::Builder;
  use Plack::App::File;

  my $app = Plack::App::File->new({ root => '.' })->to_app;

  builder {
        enable "DirListing", root => '.';
        $app;
  }

=head1 DESCRIPTION

This Plack middleware provides the same functionality as L<Plack::App::Directory>, but *only* serves the directory listing if the URL points to a directory. It does not try to serve any files.

It also strives to have a cleaner UI that more closely matches a prettified version of the Apache web server's output.

This modules does not attempt to find a default html file for the directory. If desired, include L<Plack::Middleware::DirIndex::Htaccess> or L<Plack::Middleware::DirIndex> before this module.

=head1 CONFIGURATION

=over 4

=item root

Document root directory. Defaults to the current directory.

=back

=head1 AUTHOR

Keith Carangelo <kcaran@gmail.com>

=cut

1;

__DATA__

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>

<style type="text/css">

/* Reset box-sizing */
*, *::before, *::after {
	box-sizing: border-box;
}

/* Reset default appearance */
textarea,
select,
input,
progress {
	appearance: none;
	-webkit-appearance: none;
	-moz-appearance: none;
}

html {
	font-family: sans-serif;
	scroll-behavior: smooth;
}

body {
	width: 960px;
	padding: 24px 12px;
	margin: 0 auto;
	color: #003651;
}

a {
	text-decoration: none;
	color: #006395;
	border-bottom: 1px dotted #006395;
}

a:hover {
	color: #003651;
	border-bottom: 1px dotted #003651;
}

table {
	width: 100%;
	border-collapse: collapse;
}

table th, table td {
	line-height: 1.6rem;
	padding: 6px 0;
	overflow: hidden;
	white-space: nowrap;
	text-overflow: ellipsis;
	width: 144px;
}

tr td:nth-child(1), tr th:nth-child(1) {
	width: 44px;
	text-align: center;
	vertical-align: middle;
}

tr td:nth-child(2), tr th:nth-child(2) {
	width: auto;
	padding-left: 8px;
}

tr td:nth-child(4), tr th:nth-child(4) {
	width: 120px;
}

tr:first-child th a {
	display: inline-block;
	position: relative;
}

tr th:nth-child(2), tr th:nth-child(5) {
	text-align: left;
}

tr th:nth-child(3), tr td:nth-child(3),
tr th:nth-child(4), tr td:nth-child(4) {
	text-align: right;
	padding-right: 32px;
}

tr:hover td {
	color: #006395;
	background-color: #f9ebb6;
}

.date span {
	display: inline-block;
	text-align: right;
}
.date span:nth-child(1) {
	text-align: left;
	min-width: 2.0rem;
}
.date span:nth-child(2) {
	width: 1.3rem;
	margin-right: .3rem;
}
.date span:nth-child(3) {
	width: 2.7rem;
}

.asc:after {
	content: '';
	width: 0;
	height: 0;
	border-style: solid;
	border-width: 8px 6px 0 6px;
	border-color: #006395 transparent transparent transparent;
	position: relative;
	top: 14px;
	left: 6px;
}

.desc:after {
	content: '';
	width: 0;
	height: 0;
	border-style: solid;
	border-width: 0px 6px 8px 6px;
	border-color: transparent transparent #006395 transparent;
	position: relative;
	top: -14px;
	left: 6px;
}

tr td:nth-child(1) {
  --svg: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' shape-rendering='geometricPrecision' text-rendering='geometricPrecision' image-rendering='optimizeQuality' fill-rule='evenodd' clip-rule='evenodd' viewBox='0 0 412 511.56'%3E%3Cpath fill-rule='nonzero' d='M32.24 0h229.59a9.06 9.06 0 016.77 3.04l140.63 136.27a8.971 8.971 0 012.74 6.48h.03V479.32c0 8.83-3.63 16.88-9.47 22.74l-.05.05c-5.86 5.83-13.9 9.45-22.72 9.45H32.24c-8.87 0-16.94-3.63-22.78-9.47C3.63 496.26 0 488.19 0 479.32V32.24C0 23.37 3.63 15.3 9.46 9.46 15.3 3.63 23.37 0 32.24 0zm56.24 414.35c-5.01 0-9.08-4.06-9.08-9.07 0-5.01 4.07-9.08 9.08-9.08h235.04c5.01 0 9.07 4.07 9.07 9.08s-4.06 9.07-9.07 9.07H88.48zm0-74.22c-5.01 0-9.08-4.06-9.08-9.07 0-5.01 4.07-9.08 9.08-9.08h231.38c5.01 0 9.08 4.07 9.08 9.08s-4.07 9.07-9.08 9.07H88.48zm0-74.22c-5.01 0-9.08-4.07-9.08-9.08s4.07-9.07 9.08-9.07H275.7c5.01 0 9.08 4.06 9.08 9.07 0 5.01-4.07 9.08-9.08 9.08H88.48zm0-74.23c-5.01 0-9.08-4.06-9.08-9.07 0-5.01 4.07-9.08 9.08-9.08h114.45c5.01 0 9.07 4.07 9.07 9.08s-4.06 9.07-9.07 9.07H88.48zm0-74.22c-5.01 0-9.08-4.06-9.08-9.07a9.08 9.08 0 019.08-9.08h56.29a9.08 9.08 0 019.08 9.08c0 5.01-4.07 9.07-9.08 9.07H88.48zm176.37-92.85v114.4h118.07L264.85 24.61zm129 132.55H255.78c-5.01 0-9.08-4.07-9.08-9.08V18.15H32.24c-3.86 0-7.39 1.59-9.95 4.15-2.55 2.55-4.14 6.08-4.14 9.94v447.08c0 3.86 1.59 7.39 4.14 9.94 2.56 2.56 6.09 4.15 9.95 4.15h347.52c3.89 0 7.41-1.58 9.94-4.11l.04-.04c2.53-2.53 4.11-6.05 4.11-9.94V157.16z'/%3E%3C/svg%3E");
  background-image: var(--svg);
  background-repeat: no-repeat;
  background-size: 24px 30px;
  background-position: center center;
}

tr td.ft_directory {
  --svg: url("data:image/svg+xml,%3C%3Fxml version='1.0' encoding='utf-8'%3F%3E%3Csvg version='1.1' id='Layer_1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' viewBox='0 0 122.88 95.21' style='enable-background:new 0 0 122.88 95.21' xml:space='preserve'%3E%3Cg%3E%3Cpath d='M2.48,20.74h4.5v-9.86c0-1.37,1.11-2.48,2.48-2.48h4.41V2.48c0-1.37,1.11-2.48,2.48-2.48h40.26c1.37,0,2.48,1.11,2.48,2.48 V8.4h54.3c1.37,0,2.48,1.11,2.48,2.48v9.86h4.53c1.37,0,2.48,1.11,2.48,2.48c0,0.18-0.02,0.36-0.06,0.52l-8.68,63.81 c-0.28,2.08-1.19,4.01-2.59,5.41c-1.38,1.38-3.21,2.24-5.36,2.24H14.7c-2.16,0-4.03-0.87-5.43-2.26c-1.41-1.41-2.31-3.35-2.54-5.46 l-6.72-64c-0.14-1.36,0.85-2.58,2.21-2.72C2.31,20.75,2.39,20.75,2.48,20.74L2.48,20.74L2.48,20.74z M9.46,25.71H5.23l6.43,61.27 c0.1,0.98,0.5,1.85,1.1,2.46c0.5,0.5,1.17,0.81,1.93,0.81h91.5c0.75,0,1.38-0.3,1.87-0.79c0.62-0.62,1.03-1.53,1.17-2.55 l8.32-61.19H9.46L9.46,25.71z M11.94,13.37v7.36l98.97-1.05v-6.31h-54.3c-1.37,0-2.48-1.11-2.48-2.48V4.97h-35.3v5.92 c0,1.37-1.11,2.48-2.48,2.48H11.94L11.94,13.37z'/%3E%3C/g%3E%3C/svg%3E");
}

tr td.ft_html {
  --svg: url("data:image/svg+xml,%3C%3Fxml version='1.0' encoding='utf-8'%3F%3E%3Csvg version='1.1' id='Layer_1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' viewBox='0 0 89.33 122.88' style='enable-background:new 0 0 89.33 122.88' xml:space='preserve'%3E%3Cg%3E%3Cpath d='M86.89,9.73c0.23,0,0.46,0.03,0.67,0.1c1.01,0.26,1.76,1.19,1.76,2.28v108.41c0,1.3-1.06,2.36-2.36,2.36H6.76 c-1.86,0-3.55-0.76-4.78-1.99C0.76,119.67,0,117.98,0,116.11V6.4c0-0.39,0.09-0.75,0.26-1.07C0.59,4.1,1.25,3,2.12,2.12 C3.43,0.81,5.24,0,7.23,0h79.67c1.3,0,2.36,1.06,2.36,2.36s-1.06,2.36-2.36,2.36H7.23C6.54,4.72,5.91,5,5.46,5.46 C5,5.91,4.72,6.54,4.72,7.23S5,8.54,5.46,9c0.46,0.46,1.08,0.74,1.77,0.74H86.89L86.89,9.73z M64.9,64.34 c0.2-0.36,0.39-0.72,0.58-1.1c0.22-0.44,0.42-0.88,0.62-1.33l0.02-0.03l0,0c0,0,0,0,0,0l0,0c0.01-0.01,0.01-0.02,0.02-0.04 c0.28-0.68,0.54-1.37,0.75-2.07c0.22-0.71,0.41-1.43,0.55-2.18v0c0.11-0.57,0.21-1.15,0.28-1.74c0.06-0.51,0.11-1.02,0.13-1.53 h-6.51c-0.08,1.72-0.38,3.43-0.89,5.12c-0.5,1.64-1.19,3.28-2.09,4.9h6.44H64.9L64.9,64.34z M66.12,61.88L66.12,61.88L66.12,61.88 L66.12,61.88L66.12,61.88L66.12,61.88z M66.12,61.88L66.12,61.88L66.12,61.88L66.12,61.88L66.12,61.88z M63.11,67.08h-6.44 c-1.06,1.53-2.3,3.04-3.71,4.54c-1.27,1.35-2.68,2.69-4.23,4.02l0,0c0.27-0.04,0.54-0.09,0.82-0.15v0c0.75-0.15,1.48-0.34,2.2-0.56 c0.72-0.22,1.42-0.48,2.12-0.78l0,0c0.71-0.3,1.39-0.63,2.04-0.99c0.66-0.36,1.29-0.74,1.9-1.14l0,0c0.61-0.41,1.2-0.84,1.76-1.3 c0.56-0.46,1.1-0.95,1.62-1.48v0c0.4-0.4,0.79-0.82,1.16-1.24C62.62,67.7,62.87,67.4,63.11,67.08L63.11,67.08z M41.09,75.64 c-1.55-1.33-2.96-2.67-4.23-4.02c-1.41-1.5-2.65-3.02-3.71-4.54h-6.42c0.24,0.32,0.5,0.62,0.76,0.92c0.36,0.42,0.75,0.83,1.16,1.24 v0c0.52,0.52,1.06,1.01,1.62,1.48c0.56,0.46,1.15,0.89,1.76,1.3l0,0c0.61,0.41,1.24,0.79,1.89,1.14c0.66,0.36,1.34,0.69,2.05,0.99 l0.03,0.02l0,0c0.01,0.01,0.02,0.01,0.04,0.02c0.68,0.28,1.37,0.54,2.07,0.75c0.71,0.22,1.43,0.41,2.18,0.55 C40.56,75.55,40.83,75.6,41.09,75.64L41.09,75.64z M36.01,74.18L36.01,74.18L36.01,74.18L36.01,74.18L36.01,74.18z M24.91,64.36 h6.53c-0.9-1.63-1.6-3.27-2.1-4.92c-0.51-1.69-0.8-3.39-0.88-5.1h-6.5c0.03,0.51,0.08,1.02,0.14,1.53 c0.07,0.59,0.16,1.16,0.27,1.74h0c0.15,0.75,0.34,1.48,0.56,2.2c0.22,0.72,0.48,1.42,0.78,2.12l0,0c0.18,0.44,0.39,0.87,0.6,1.31 C24.51,63.62,24.71,64,24.91,64.36L24.91,64.36z M21.95,51.62h6.56c0.14-1.68,0.5-3.37,1.06-5.07c0.55-1.65,1.29-3.3,2.22-4.95 h-6.89c-0.21,0.37-0.41,0.74-0.6,1.13c-0.22,0.43-0.42,0.87-0.6,1.31l-0.02,0.03l0,0c0,0,0,0,0,0l0,0 c-0.01,0.01-0.01,0.02-0.02,0.04c-0.28,0.68-0.54,1.37-0.75,2.07c-0.22,0.71-0.41,1.43-0.55,2.18v0c-0.11,0.57-0.21,1.15-0.28,1.74 C22.03,50.6,21.98,51.1,21.95,51.62L21.95,51.62z M23.69,44.06L23.69,44.06L23.69,44.06L23.69,44.06L23.69,44.06L23.69,44.06z M23.69,44.07L23.69,44.07L23.69,44.07L23.69,44.07L23.69,44.07z M26.7,38.88h6.83c1.05-1.5,2.26-3.01,3.64-4.51 c1.24-1.36,2.62-2.73,4.13-4.1l-0.13,0.02c-0.3,0.05-0.6,0.1-0.89,0.16h0c-0.75,0.15-1.48,0.34-2.2,0.56 c-0.72,0.22-1.42,0.48-2.12,0.78l0,0c-0.71,0.3-1.39,0.63-2.04,0.99c-0.66,0.36-1.29,0.74-1.91,1.15c-0.61,0.41-1.2,0.84-1.76,1.3 c-0.56,0.46-1.1,0.95-1.62,1.48h0c-0.4,0.4-0.79,0.81-1.15,1.24C27.2,38.24,26.95,38.55,26.7,38.88L26.7,38.88z M48.53,30.28 c1.51,1.36,2.88,2.72,4.12,4.08c1.37,1.51,2.58,3.01,3.63,4.51h6.82c-0.24-0.32-0.5-0.62-0.76-0.92c-0.36-0.42-0.75-0.83-1.16-1.24 c-0.53-0.53-1.07-1.02-1.62-1.48c-0.56-0.46-1.15-0.89-1.76-1.3l0,0c-0.61-0.41-1.24-0.79-1.89-1.14 c-0.66-0.36-1.34-0.69-2.05-0.99l-0.03-0.02l0,0l0,0l0,0c-0.01-0.01-0.02-0.01-0.04-0.02c-0.68-0.28-1.37-0.54-2.07-0.75 c-0.71-0.22-1.43-0.41-2.18-0.55h0c-0.32-0.06-0.62-0.12-0.91-0.16L48.53,30.28L48.53,30.28z M53.82,31.78L53.82,31.78L53.82,31.78 L53.82,31.78L53.82,31.78z M64.9,41.6h-6.89c0.94,1.65,1.68,3.3,2.22,4.95c0.56,1.7,0.92,3.38,1.06,5.07h6.56 c-0.03-0.51-0.08-1.02-0.14-1.53c-0.07-0.58-0.16-1.16-0.27-1.74h0c-0.15-0.75-0.34-1.48-0.56-2.2c-0.22-0.72-0.48-1.42-0.78-2.12 l0,0c-0.19-0.44-0.39-0.87-0.6-1.31C65.31,42.34,65.11,41.97,64.9,41.6L64.9,41.6z M39.74,27.77c0.83-0.17,1.68-0.3,2.54-0.38 c0.87-0.09,1.74-0.13,2.62-0.13c1.77,0,3.48,0.17,5.16,0.51l0,0c0.82,0.16,1.63,0.37,2.43,0.61c0.79,0.24,1.57,0.53,2.34,0.86 c0.02,0.01,0.04,0.01,0.06,0.02l0,0c0.02,0.01,0.03,0.02,0.05,0.03c0.75,0.33,1.49,0.68,2.2,1.07c0.74,0.4,1.45,0.83,2.15,1.29 c0.68,0.45,1.33,0.93,1.96,1.45c0.65,0.53,1.26,1.09,1.84,1.67l0,0c0.59,0.58,1.14,1.18,1.66,1.82c0.52,0.63,1.01,1.29,1.46,1.98 l0,0c0.46,0.68,0.89,1.4,1.29,2.13c0.4,0.73,0.76,1.48,1.09,2.25c0.34,0.78,0.63,1.58,0.88,2.4c0.25,0.81,0.46,1.63,0.63,2.46 c0.17,0.83,0.3,1.68,0.38,2.54c0.09,0.87,0.13,1.74,0.13,2.62c0,1.77-0.17,3.48-0.51,5.16h0c-0.16,0.82-0.37,1.63-0.61,2.43 c-0.24,0.79-0.53,1.57-0.86,2.34c-0.01,0.02-0.01,0.04-0.02,0.06c-0.01,0.02-0.02,0.03-0.03,0.05c-0.33,0.77-0.69,1.51-1.08,2.23 c-0.4,0.73-0.83,1.44-1.28,2.12c-0.45,0.68-0.93,1.33-1.45,1.96c-0.53,0.64-1.08,1.25-1.67,1.84c-0.58,0.59-1.18,1.14-1.82,1.66 c-0.63,0.52-1.29,1.01-1.98,1.46l0,0c-0.68,0.46-1.39,0.89-2.13,1.29c-0.73,0.4-1.48,0.76-2.25,1.09c-0.78,0.34-1.58,0.63-2.4,0.88 c-0.81,0.25-1.63,0.46-2.46,0.63c-0.83,0.17-1.68,0.3-2.54,0.38c-0.87,0.09-1.74,0.13-2.63,0.13c-0.88,0-1.75-0.04-2.62-0.13 c-0.86-0.08-1.71-0.21-2.55-0.38v0c-0.82-0.16-1.63-0.37-2.43-0.61c-0.79-0.24-1.57-0.53-2.34-0.86c-0.02-0.01-0.04-0.02-0.06-0.02 c-0.02-0.01-0.03-0.02-0.04-0.03c-0.75-0.33-1.49-0.68-2.2-1.07c-0.74-0.4-1.45-0.83-2.15-1.29c-0.68-0.45-1.33-0.93-1.96-1.45 c-0.65-0.53-1.26-1.09-1.84-1.67l0,0c-0.59-0.58-1.14-1.18-1.66-1.82c-0.52-0.63-1.01-1.29-1.46-1.98h0 c-0.46-0.68-0.89-1.4-1.29-2.13c-0.4-0.73-0.76-1.48-1.09-2.25c-0.34-0.78-0.63-1.58-0.88-2.4c-0.25-0.81-0.46-1.63-0.63-2.46 c-0.17-0.83-0.3-1.68-0.38-2.54c-0.09-0.87-0.13-1.74-0.13-2.62c0-1.77,0.17-3.48,0.51-5.17h0c0.16-0.82,0.37-1.63,0.61-2.43 c0.24-0.79,0.53-1.57,0.86-2.34c0.01-0.02,0.01-0.04,0.02-0.06c0.01-0.01,0.02-0.03,0.03-0.05c0.33-0.77,0.69-1.51,1.08-2.23 c0.4-0.73,0.83-1.44,1.28-2.12c0.45-0.68,0.93-1.33,1.45-1.96c0.53-0.64,1.08-1.25,1.67-1.84c0.58-0.59,1.18-1.14,1.82-1.66 c0.63-0.52,1.29-1.01,1.98-1.46v0c0.68-0.46,1.39-0.89,2.13-1.29c0.73-0.4,1.48-0.76,2.25-1.09c0.78-0.34,1.58-0.63,2.4-0.88 C38.08,28.15,38.9,27.94,39.74,27.77L39.74,27.77z M46.27,31.9v6.97h6.65c-0.89-1.15-1.88-2.29-2.98-3.45 C48.82,34.26,47.6,33.08,46.27,31.9L46.27,31.9z M46.27,41.6v10.02h12.3c-0.16-1.62-0.54-3.24-1.14-4.88 c-0.62-1.7-1.49-3.41-2.59-5.13H46.27L46.27,41.6z M46.27,54.34v10.02h8.95c1.06-1.69,1.88-3.38,2.45-5.07 c0.55-1.64,0.87-3.29,0.96-4.95H46.27L46.27,54.34z M46.27,67.08v7.08c1.41-1.18,2.71-2.37,3.89-3.56 c1.16-1.17,2.21-2.35,3.14-3.53H46.27L46.27,67.08z M43.54,74.17v-7.08h-7.03c0.92,1.18,1.97,2.35,3.13,3.53 C40.82,71.8,42.12,72.98,43.54,74.17L43.54,74.17z M43.54,64.36V54.34H31.18c0.09,1.65,0.41,3.3,0.97,4.95 c0.57,1.69,1.39,3.38,2.44,5.07H43.54L43.54,64.36z M43.54,51.62V41.6h-8.57c-1.1,1.73-1.96,3.44-2.59,5.13 c-0.6,1.64-0.98,3.27-1.14,4.88H43.54L43.54,51.62z M43.54,38.88V31.9c-1.33,1.18-2.55,2.35-3.67,3.52 c-1.1,1.15-2.09,2.3-2.98,3.45H43.54L43.54,38.88z M18.59,94.47c-1.3,0-2.36-1.06-2.36-2.36c0-1.3,1.06-2.36,2.36-2.36h52.08 c1.3,0,2.36,1.06,2.36,2.36c0,1.3-1.06,2.36-2.36,2.36H18.59L18.59,94.47z M28.19,106.83c-1.3,0-2.36-1.06-2.36-2.36 s1.06-2.36,2.36-2.36h32.87c1.3,0,2.36,1.06,2.36,2.36s-1.06,2.36-2.36,2.36H28.19L28.19,106.83z M84.61,14.45H7.23 c-0.88,0-1.73-0.16-2.51-0.45v102.12c0,0.56,0.23,1.07,0.6,1.45c0.37,0.37,0.88,0.6,1.45,0.6h77.85V14.45L84.61,14.45z'/%3E%3C/g%3E%3C/svg%3E");
}

tr td.ft_image {
  --svg: url("data:image/svg+xml,%3C%3Fxml version='1.0' encoding='utf-8'%3F%3E%3Csvg version='1.1' id='Layer_1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' viewBox='0 0 122.88 122.14' style='enable-background:new 0 0 122.88 122.14' xml:space='preserve'%3E%3Cg%3E%3Cpath d='M8.69,0h105.5c2.39,0,4.57,0.98,6.14,2.55c1.57,1.57,2.55,3.75,2.55,6.14v104.76c0,2.39-0.98,4.57-2.55,6.14 c-1.57,1.57-3.75,2.55-6.14,2.55H8.69c-2.39,0-4.57-0.98-6.14-2.55C0.98,118.02,0,115.84,0,113.45V8.69C0,6.3,0.98,4.12,2.55,2.55 C4.12,0.98,6.3,0,8.69,0L8.69,0z M7.02,88.3l37.51-33.89c1.43-1.29,3.64-1.18,4.93,0.25c0.03,0.03,0.05,0.06,0.08,0.09l0.01-0.01 l31.45,37.22l4.82-29.59c0.31-1.91,2.11-3.2,4.02-2.89c0.75,0.12,1.4,0.47,1.9,0.96l24.15,23.18V8.69c0-0.46-0.19-0.87-0.49-1.18 c-0.3-0.3-0.72-0.49-1.18-0.49H8.69c-0.46,0-0.87,0.19-1.18,0.49c-0.3,0.3-0.49,0.72-0.49,1.18V88.3L7.02,88.3z M115.86,93.32 L91.64,70.07l-4.95,30.41c-0.11,0.83-0.52,1.63-1.21,2.22c-1.48,1.25-3.68,1.06-4.93-0.41L46.52,62.02L7.02,97.72v15.73 c0,0.46,0.19,0.87,0.49,1.18c0.31,0.31,0.72,0.49,1.18,0.49h105.5c0.46,0,0.87-0.19,1.18-0.49c0.3-0.3,0.49-0.72,0.49-1.18V93.32 L115.86,93.32z M92.6,19.86c3.48,0,6.62,1.41,8.9,3.69c2.28,2.28,3.69,5.43,3.69,8.9s-1.41,6.62-3.69,8.9 c-2.28,2.28-5.43,3.69-8.9,3.69c-3.48,0-6.62-1.41-8.9-3.69c-2.28-2.28-3.69-5.43-3.69-8.9s1.41-6.62,3.69-8.9 C85.98,21.27,89.12,19.86,92.6,19.86L92.6,19.86z M97.58,27.47c-1.27-1.27-3.03-2.06-4.98-2.06c-1.94,0-3.7,0.79-4.98,2.06 c-1.27,1.27-2.06,3.03-2.06,4.98c0,1.94,0.79,3.7,2.06,4.98c1.27,1.27,3.03,2.06,4.98,2.06c1.94,0,3.7-0.79,4.98-2.06 c1.27-1.27,2.06-3.03,2.06-4.98C99.64,30.51,98.85,28.75,97.58,27.47L97.58,27.47z'/%3E%3C/g%3E%3C/svg%3E");
}

tr td.ft_parent {
  --svg: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' shape-rendering='geometricPrecision' text-rendering='geometricPrecision' image-rendering='optimizeQuality' fill-rule='evenodd' clip-rule='evenodd' viewBox='0 0 512 500.38'%3E%3Cpath fill-rule='nonzero' d='M363.5 234.21 262.15 218.7c4.53 45.55 15.78 96.13 45.93 138.82 33.7 47.76 91.77 86.4 191.94 98.33 7.44.88 12.76 7.64 11.88 15.07-.68 5.75-4.86 10.22-10.14 11.57-32.64 10.88-63.47 16.47-92.42 17.65-79.46 3.26-144.32-26.42-193.76-70.24-48.96-43.39-82.71-100.76-100.41-153.44-6.79-20.21-11.26-39.85-13.36-57.82l-85.9 15.46c-7.34 1.31-14.39-3.58-15.7-10.92-.72-4.08.46-8.05 2.9-11.01L174.55 4.91c4.77-5.76 13.33-6.57 19.09-1.8l1.58 1.54 180.54 207.22c4.92 5.65 4.32 14.23-1.33 19.16-3.12 2.72-7.13 3.75-10.93 3.18z'/%3E%3C/svg%3E");
}

tr td.ft_pdf {
  --svg: url("data:image/svg+xml,%3C%3Fxml version='1.0' encoding='utf-8'%3F%3E%3Csvg version='1.1' id='Layer_1' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' viewBox='0 0 102.55 122.88' style='enable-background:new 0 0 102.55 122.88' xml:space='preserve'%3E%3Cstyle type='text/css'%3E.st0%7Bfill-rule:evenodd;clip-rule:evenodd;%7D%3C/style%3E%3Cg%3E%3Cpath class='st0' d='M102.55,122.88H0V0h77.66l24.89,26.43V122.88L102.55,122.88z M87.01,69.83c-1.48-1.46-4.75-2.22-9.74-2.29 c-3.37-0.03-7.43,0.27-11.7,0.86c-1.91-1.1-3.88-2.31-5.43-3.75c-4.16-3.89-7.64-9.28-9.8-15.22c0.14-0.56,0.26-1.04,0.37-1.54 c0,0,2.35-13.32,1.73-17.82c-0.08-0.61-0.14-0.8-0.3-1.27l-0.2-0.53c-0.64-1.47-1.89-3.03-3.85-2.94l-1.18-0.03 c-2.19,0-3.97,1.12-4.43,2.79c-1.42,5.24,0.05,13.08,2.7,23.24l-0.68,1.65c-1.9,4.64-4.29,9.32-6.39,13.44l-0.28,0.53 c-2.22,4.34-4.23,8.01-6.05,11.13l-1.88,1c-0.14,0.07-3.36,1.78-4.12,2.24c-6.41,3.83-10.66,8.17-11.37,11.62 c-0.22,1.1-0.05,2.51,1.08,3.16L17.32,97c0.79,0.4,1.62,0.6,2.47,0.6c4.56,0,9.87-5.69,17.18-18.44 c8.44-2.74,18.04-5.03,26.45-6.29c6.42,3.61,14.3,6.12,19.28,6.12c0.89,0,1.65-0.08,2.27-0.25c0.95-0.26,1.76-0.8,2.25-1.54 c0.96-1.46,1.16-3.46,0.9-5.51c-0.08-0.61-0.56-1.36-1.09-1.88L87.01,69.83L87.01,69.83z M18.79,94.13 c0.83-2.28,4.13-6.78,9.01-10.78c0.3-0.25,1.06-0.95,1.75-1.61C24.46,89.87,21.04,93.11,18.79,94.13L18.79,94.13L18.79,94.13z M47.67,27.64c1.47,0,2.31,3.7,2.38,7.17c0.07,3.47-0.74,5.91-1.75,7.71c-0.83-2.67-1.24-6.87-1.24-9.62 C47.06,32.89,47,27.64,47.67,27.64L47.67,27.64L47.67,27.64z M39.05,75.02c1.03-1.83,2.08-3.76,3.17-5.81 c2.65-5.02,4.32-8.93,5.57-12.15c2.48,4.51,5.57,8.35,9.2,11.42c0.45,0.38,0.93,0.77,1.44,1.15 C51.05,71.09,44.67,72.86,39.05,75.02L39.05,75.02L39.05,75.02L39.05,75.02z M85.6,74.61c-0.45,0.28-1.74,0.44-2.56,0.44 c-2.67,0-5.98-1.22-10.62-3.22c1.78-0.13,3.41-0.2,4.88-0.2c2.68,0,3.48-0.01,6.09,0.66C86.01,72.96,86.05,74.32,85.6,74.61 L85.6,74.61L85.6,74.61L85.6,74.61z M96.12,115.98V30.45H73.44V5.91H6.51v110.07H96.12L96.12,115.98z'/%3E%3C/g%3E%3C/svg%3E");
}

</style>
</head>

<body>
<main role="main">
    <h1>%s</h1>
    <hr />
    <table>
      <thead>
        <tr>
          <th></th>
          <th class="name"><a href="?C=N;O=D">Name</a></th>
          <th class="mtime"><a href="?C=M;O=A">Last Modified</a></th>
          <th class="size"><a href="?C=S;O=A">Size</a></th>
          <th class="type"><a href="?C=D;O=A">Type</a></th>
        </tr>
      </thead>
      <tbody>
%s
      </tbody>
    </table>
    <p>%s</p>
</main>

<script>
'use strict';

const today = Date.now();
const recent = (180 * 24 * 60 * 60 * 1000);
const old_date = new Intl.DateTimeFormat( 'en-us', { month: 'short',
	day: '2-digit', year: 'numeric' } );
const new_date = new Intl.DateTimeFormat( 'en-us', { month: 'short',
	day: '2-digit', hour: '2-digit', minute: 'numeric', hour12: false } );
const fields = { N : 2, M : 3, S : 4, D : 5 };

function convert_date( timestamp ) {
  var ts = Date.parse( timestamp );
  if (!ts) {
    return timestamp;
   }
  var date = new Date( ts );
  var date_parts;
  if (today - ts > recent) {
    date_parts = old_date.formatToParts( date );
   }
  else {
    date_parts = new_date.formatToParts( date );
    // Combine hour and minute
    date_parts[4].value = date_parts[4].value + ':' + date_parts[6].value;
   }
  var formatted = '<div class="date"><span>' + date_parts[0].value + '</span><span>' + date_parts[2].value + '</span><span>' + date_parts[4].value + '</span></div>';

  return formatted;
 }

document.addEventListener('DOMContentLoaded', function () {

// Convert date to Linux dir listing format
document.querySelectorAll( 'td:nth-child(3)' ).forEach( (item) => {
  item.innerHTML = convert_date( item.textContent );
});

// Add additional descriptions
document.querySelectorAll( 'td:nth-child(5)' ).forEach( (item) => {
  if (item.textContent.match( /^\s*$/ )) {
    let filename = item.parentElement.childNodes[1].textContent;
    let suffix = filename.match( /\.([^\.\/]+)$/ );
    if (suffix) {
      item.innerHTML = suffix[1].toUpperCase() + ' file';
    }
  }
});

// Make entire row a link to the file
document.querySelectorAll( 'tr' ).forEach( (item) => {
  item.addEventListener('click', (event) => {
	window.location = event.currentTarget.innerHTML.match( /href="([^"]+)"/ )[1];
  });
});

// Add sorting caret
var sort = window.location.search.match( /C=(\w).O=(\w)/ );
if (sort) {
  let sortclass = (sort[2] === 'A') ? 'asc' : 'desc';
  document.querySelector( 'table tr:first-child th:nth-child(' + fields[ sort[1] ] + ') a' ).classList.add( sortclass );
 }

}, false );
</script>

</body>
</html>

