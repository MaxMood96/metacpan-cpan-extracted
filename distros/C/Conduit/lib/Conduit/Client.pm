#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2026 -- leonerd@leonerd.org.uk

use v5.36;

use feature 'try';
use Future::AsyncAwait;
use Object::Pad 0.807 ':experimental(inherit_field)';

class Conduit::Client 0.03
   :strict(params);

no if $^V lt v5.40, warnings => "experimental::try", "experimental::builtin";

field $socket :param;

use Future::Buffer;
use Future::IO;
use HTTP::Request;
use HTTP::Response;

use Conduit::Metrics;

field $readbuf;
ADJUST {
   $readbuf = Future::Buffer->new(
      fill => sub () { Future::IO->sysread( $socket, 8192 ); },
   );
}

field $server :param :inheritable;
ADJUST { builtin::weaken( $server ); }

async method read_request ()
{
   defined( my $header = await $readbuf->read_until( qr/\x0D\x0A\x0D\x0A/ ) )
      or return undef;

   my $req = HTTP::Request->parse( $header );

   my $content_length = $req->content_length // 0;

   if( $content_length ) {
      my $body = await $readbuf->read_exactly( $content_length );

      $req->add_content( $body );
   }

   Conduit::Metrics->received_request( $req );
   return $req;
}

field $bytes_written :inheritable;

async method write ( $str )
{
   await Future::IO->write_exactly( $socket, $str );
   $bytes_written += length $str;
}

class Conduit::Client::_ForHTTP
   :strict(params);
inherit Conduit::Client qw( $server $bytes_written );

no if $^V lt v5.40, warnings => "experimental::try", "experimental::builtin";

field $responder :param;

async method run ()
{
   while( defined( my $req = await $self->read_request ) ) {
      my $resp;
      try {
         $resp = await $responder->( $req );
      }
      catch( $e ) {
         chomp $e;
         $resp = HTTP::Response->new( 500, undef,
            [ "Content-Type" => "text/plain" ],
            $e,
         );
      }
      $resp->request( $req );

      $resp->protocol or $resp->protocol( $req->protocol );
      $resp->content_length or $resp->content_length( length $resp->content );

      $bytes_written = 0;

      $server->on_response_header( $req, $resp )
         if $server->can( "on_response_header" );

      await $self->write( $resp->as_string( "\x0D\x0A" ) );
      Conduit::Metrics->sent_response( $resp, $bytes_written );
   }
}

class Conduit::Client::_ForPSGI
   :strict(params);
inherit Conduit::Client qw( $server $bytes_written );

no if $^V lt v5.40, warnings => "experimental::try", "experimental::builtin";

field $psgi_app :param;

async method run ()
{
   while( defined( my $req = await $self->read_request ) ) {
      my $uri = $req->uri;

      my $path_info = $uri->path;
      $path_info = "" if $path_info eq "/";

      open my $stdin, "<", \$req->content;

      my %env = (
         SERVER_PROTOCOL     => $req->protocol,
         SCRIPT_NAME         => '',
         PATH_INFO           => $path_info,
         QUERY_STRING        => $uri->query // "",
         REQUEST_METHOD      => $req->method,
         REQUEST_URI         => $uri->path,
         'psgi.version'      => [1,0],
         'psgi.url_scheme'   => "http",
         'psgi.input'        => $stdin,
         'psgi.errors'       => \*STDERR,
         'psgi.multithread'  => 0,
         'psgi.multiprocess' => 0,
         'psgi.run_once'     => 0,
         'psgi.nonblocking'  => 1,
         'psgi.streaming'    => 1,
      );

      # TODO: socket info

      $req->scan( sub ( $name, $value ) {
         $name =~ s/-/_/g;
         $name = uc $name;

         # Content-Length and Content-Type don't get an HTTP_ prefix
         $name = "HTTP_$name" unless $name =~ m/^CONTENT_(?:LENGTH|TYPE)$/;

         $env{$name} = $value;
      } );

      my $psgiresp;
      try {
         $psgiresp = $psgi_app->( \%env );
      }
      catch( $e ) {
         chomp $e;
         $psgiresp = [ 500, [ "Content-Type" => "text/plain" ], [ $e ] ];
      }

      $bytes_written = 0;

      my $aresponder = async sub ( $v ) {
         my ( $status, $headers, $body ) = @$v;

         my $resp = HTTP::Response->new( $status );

         $resp->request( $req );
         $resp->protocol( $req->protocol );

         my $has_content_length = 0;
         my $use_chunked_transfer = 0;
         while( my ( $key, $value ) = splice @$headers, 0, 2 ) {
            $resp->push_header( $key, $value );

            $has_content_length = 1 if $key eq "Content-Length";
            $use_chunked_transfer = 1 if $key eq "Transfer-Encoding" and $value eq "chunked";
         }

         if( !defined $body ) {
            die "TODO: no body yet; use deferred writer";
         }
         elsif( ref $body eq "ARRAY" ) {
            unless( $has_content_length ) {
               my $len = 0;
               $len += length( $_ ) for @$body;

               $resp->content_length( $len );
            }

            $server->on_response_header( $req, $resp )
               if $server->can( "on_response_header" );

            await $self->write( $resp->as_string( "\x0D\x0A" ) );

            foreach my $chunk ( @$body ) {
               await $self->write( $chunk );
            }
         }
         else {
            unless( $has_content_length ) {
               $resp->header( "Transfer-Encoding" => "chunked" );
               $use_chunked_transfer = 1;
            }

            $server->on_response_header( $req, $resp )
               if $server->can( "on_response_header" );

            await $self->write( $resp->as_string( "\x0D\x0A" ) );

            # PSGI says we must call the synchronous ->getline method
            while(1) {
               my $buffer = do { local $/ = \8192; $body->getline; };
               defined $buffer or last;

               $buffer = sprintf( "%X\x0D\x0A", length $buffer )
                  . $buffer if $use_chunked_transfer;

               await $self->write( $buffer );
            }

            await $self->write( "0\x0D\x0A\x0D\x0A" ) if $use_chunked_transfer;
         }

         Conduit::Metrics->sent_response( $resp, $bytes_written );
      };

      if( ref $psgiresp eq "ARRAY" ) {
         await $aresponder->( $psgiresp );
      }
      elsif( ref $psgiresp eq "CODE" ) {
         $psgiresp->( sub ( @args ){
            # PSGI app is expecting a *synchronous* responder.
            # We have no choice here
            $aresponder->( @args )->get;
         } );
      }
      else {
         die "ARGH PSGI app returned neither ARRAY nor CODE";
      }
   }
}

0x55AA;
