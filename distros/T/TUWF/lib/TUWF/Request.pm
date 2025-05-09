
package TUWF::Request;

use strict;
use warnings;
use Exporter 'import';
use Carp 'croak';

our $VERSION = '1.6';
our @EXPORT = qw|
  reqInit reqGets reqGet reqPosts reqPost reqParams reqParam reqJSON
  reqUploadMIMEs reqUploadMIME reqUploadRaws reqUploadRaw reqSaveUpload
  reqCookie reqMethod reqHeader reqPath reqQuery reqProtocol reqBaseURI reqURI reqHost reqIP reqFCGI
|;

our $RENV = \%ENV;

sub reqInit {
  my $self = shift;
  $self->{_TUWF}{Req} = {};

  # lighttpd doesn't always split the query string from REQUEST_URI
  if($RENV->{SERVER_SOFTWARE}||'' =~ /lighttpd/) {
    ($RENV->{REQUEST_URI}, $RENV->{QUERY_STRING}) = split /\?/, $RENV->{REQUEST_URI}, 2
      if ($RENV->{REQUEST_URI}||'') =~ /\?/;
  }

  my $ok = eval {
    $self->{_TUWF}{Req}{Cookies} = _parse_cookies($self, $RENV->{HTTP_COOKIE} || $RENV->{COOKIE});
    $self->{_TUWF}{Req}{GET} = _parse_urlencoded($RENV->{QUERY_STRING});
    $self->reqPath(); # let it croak when the path isn't valid UTF-8
    1;
  };
  die $@ if !$ok;

  my $meth = $self->reqMethod;
  die TUWF::Exception->new('method') if $meth !~ /^(GET|POST|HEAD|DELETE|OPTIONS|PUT|PATCH)$/;

  if($meth =~ /^(POST|PUT|PATCH)$/ && $RENV->{CONTENT_LENGTH}) {
    die TUWF::Exception->new('maxpost') if $self->{_TUWF}{max_post_body} && $RENV->{CONTENT_LENGTH} > $self->{_TUWF}{max_post_body};

    my $data;
    die "Couldn't read all request data.\n" if $RENV->{CONTENT_LENGTH} > read STDIN, $data, $RENV->{CONTENT_LENGTH}, 0;

    eval {
      if(($RENV->{'CONTENT_TYPE'}||'') =~ m{^application/json(?:;.*)?$}) {
        $self->{_TUWF}{Req}{JSON} = _parse_json($data);
        die TUWF::Exception->new('json') if !$self->{_TUWF}{Req}{JSON};
      } elsif(($RENV->{'CONTENT_TYPE'}||'') =~ m{^multipart/form-data; boundary=(.+)$}) {
        _parse_multipart($self, $data, $1);
      } else {
        $self->{_TUWF}{Req}{POST} = _parse_urlencoded($data);
      }
      1;
    } || die $@;;
  }
}


sub _check_control {
  # Disallow any control codes, except for x09 (tab), x0a (newline) and x0d (carriage return)
  die TUWF::Exception->new('controlchar') if $_[0] =~ /[\x00-\x08\x0b\x0c\x0e-\x1f]/;
  $_[0]
}


sub _decode_utf8 {
  utf8::decode(my $v = $_[0]) || die TUWF::Exception->new('utf8');
  $v;
}


sub _store {
  return push @{$_[0]}, $_[1] if ref $_[0];
  $_[0] = defined $_[0] ? [$_[0], $_[1]] : $_[1];
}


sub _parse_urlencoded {
  my %dat;
  my $d = shift;
  for (split /[;&]/, _decode_utf8 $d) {
    my($key, $val) = split /=/, $_, 2;
    next if !defined $key or !defined $val;
    for ($key, $val) {
      s/\+/ /gs;
      # assume %XX sequences represent UTF-8 bytes and properly decode it.
      s#((?:%[0-9a-fA-F]{2})+)#
        utf8::downgrade(my $s = $1);
        $s =~ s/%(.{2})/chr hex($1)/eg;
        _decode_utf8 $s;
      #eg;
      s/%u([0-9a-fA-F]{4})/chr hex($1)/eg;
      _check_control($_);
    }
    _store $dat{$key}, $val;
  }
  return \%dat;
}


my $_json_codec;
sub _parse_json {
  my $d = shift;
  $_json_codec ||= TUWF::Misc::_JSON()->new->utf8;

  my $res = eval { $_json_codec->decode($d) };
  return undef if !$res || ref $res ne 'HASH'; # We always expect to receive a JSON object.
  return $res;
}


# Heavily inspired by CGI::Minimal::Multipart::_burst_multipart_buffer()
sub _parse_multipart {
  my($self, $data, $boundary) = @_;
  my $nfo = $self->{_TUWF}{Req};
  my $CRLF = "\015\012";

  $nfo->{POST} = {};
  $nfo->{FILES} = {};
  $nfo->{MIMES} = {};

  for my $p (split /--\Q$boundary\E(?:--)?$CRLF/, $data) {
    next if !defined $p;
    $p =~ s/$CRLF$//;
    last if $p eq '--';
    next if !$p;
    my($header, $value) = split /$CRLF$CRLF/, $p, 2;

    my($name, $mime, $filename) = ('', '', '');
    for my $h (split /$CRLF/, $header) {
      my($hn, $hv) = split /: /, $h, 2;
      # Does not handle multipart/mixed, but those don't appear to be used in practice.
      if($hn =~ /^Content-Type$/i) {
        $mime = $hv;
      }
      if($hn =~ /^Content-Disposition$/i) {
        for my $dis (split /; /, $hv) {
          $name     = $2 if $dis =~ /^name=("?)(.*)\1$/;
          $filename = $2 if $dis =~ /^filename=("?)(.*)\1$/;
        }
      }
    }

    $name = _check_control _decode_utf8 $name;

    # In the case of a file upload, use the filename as value instead of the
    # data. This is to ensure that reqPOST() always returns decoded data.

    # Note that I use the presence of a filename attribute for determining
    # whether this parameters comes from an <input type="file"> rather than a
    # regular form element. The standards do not require the filename to be
    # present, but I am not aware of any browser that does not send it.
    if($filename) {
      _store $nfo->{POST}{$name}, _check_control _decode_utf8 $filename;
      _store $nfo->{MIMES}{$name}, _check_control _decode_utf8 $mime;
      _store $nfo->{FILES}{$name}, $value; # not decoded, can be binary
    } else {
      _store $nfo->{POST}{$name}, _check_control _decode_utf8 $value;
    }
  }
}


sub _parse_cookies {
  my($self, $str) = @_;
  return {} if !$str;

  my %dat;
  # The format of the Cookie: header is hardly standardized and the widely used
  # implementations all differ in how they interpret the data. This (rather)
  # lazy implementation assumes the cookie values are not escaped and don't
  # contain any characters that are used within the header format.
  for (split /[;,]/, _decode_utf8 $str) {
    s/^ +//;
    s/ +$//;
    next if !$_ || !m{^([^\(\)<>@,;:\\"/\[\]\?=\{\}\t\s]+)=("?)(.*)\2$};
    my($n, $v) = ($1, $3);
    next if $self->{_TUWF}{cookie_prefix} && !($n =~ s/^\Q$self->{_TUWF}{cookie_prefix}\E//);
    _check_control $n;
    _check_control $v;
    $dat{$n} = $v if !exists $dat{$n};
  }
  return \%dat;
}


sub _tablegets {
  my($k, $s, $n) = @_;
  my $lst = $s->{_TUWF}{Req}{$k};
  return keys %$lst if @_ == 2;
  my $v = $lst->{$n};
  ref $v ? @$v : defined $v ? ($v) : ();
}


sub _tableget {
  my($k, $s, $n) = @_;
  my $v = $s->{_TUWF}{Req}{$k}{$n};
  ref $v ? $v->[0] : $v;
}


sub reqGets        { _tablegets(GET => @_) }
sub reqGet         { _tableget (GET => @_) }
sub reqPosts       { _tablegets(POST => @_) }
sub reqPost        { _tableget (POST => @_) }
sub reqUploadMIMEs { _tablegets(MIMES => @_) }
sub reqUploadMIME  { _tableget (MIMES => @_) }
sub reqUploadRaws  { _tablegets(FILES => @_) }
sub reqUploadRaw   { _tableget (FILES => @_) }


# get parameters from either or both POST and GET
# (POST has priority over GET in scalar context)
sub reqParams {
  my($s, $n) = @_;
  my $nfo = $s->{_TUWF}{Req};
  if(!$n) {
    my %keys = map +($_,1), keys(%{$nfo->{GET}}), keys(%{$nfo->{POST}});
    return keys %keys;
  }
  my $p = $nfo->{POST}{$n};
  my $g = $nfo->{GET}{$n};
  return (
    ref $p ? @$p : defined $p ? ($p) : (),
    ref $g ? @$g : defined $g ? ($g) : (),
  );
}


# (POST has priority over GET in scalar context)
sub reqParam {
  my($s, $n) = @_;
  my $nfo = $s->{_TUWF}{Req};
  my $v = $nfo->{POST}{$n} || $nfo->{GET}{$n};
  ref $v ? $v->[0] : $v;
}


sub reqJSON {
  return shift->{_TUWF}{Req}{JSON};
}


# saves file contents identified by the form name to the specified file
# (doesn't support multiple file upload using the same form name yet)
sub reqSaveUpload {
  my($s, $n, $f) = @_;
  open my $F, '>', $f or croak "Unable to write to $f: $!";
  print $F $s->reqUploadRaw($n);
  close $F;
}


sub reqCookie {
  my($self, $n) = @_;
  my $nfo = $self->{_TUWF}{Req}{Cookies};
  return keys %$nfo if @_ == 1;
  return $nfo->{$n};
}


sub reqMethod {
  return $RENV->{REQUEST_METHOD}||'GET';
}


# Returns list of header names when no argument is passed
#   (may be in a different order and can have different casing than
#    the original headers - CGI doesn't preserve that information)
# Returns value of the specified header otherwise, header name is
#   case-insensitive
sub reqHeader {
  my($self, $name) = @_;
  if(@_ == 2) {
    (my $v = uc $_[1]) =~ tr/-/_/;
    $v = $RENV->{"HTTP_$v"}||'';
    return _check_control _decode_utf8 $v;
  } else {
    return (map {
      if(/^HTTP_/) { 
        (my $h = lc $_) =~ s/_([a-z])/-\U$1/g;
        $h =~ s/^http-//;
        _check_control _decode_utf8 $h;
      } else { () }
    } sort keys %$RENV);
  }
}


# returns the path part of the current URI, including the leading slash
sub reqPath {
  (my $u = ($RENV->{REQUEST_URI}||'')) =~ s{\?.*$}{};
  return _check_control _decode_utf8 $u;
}


sub reqProtocol {
  return $RENV->{HTTPS} ? 'https' : 'http';
}


# returns base URI, excluding trailing slash
sub reqBaseURI {
  my $s = shift;
  return $s->reqProtocol().'://'.$s->reqHost();
}


sub reqQuery {
  my $u = $RENV->{QUERY_STRING} ? '?'.$RENV->{QUERY_STRING} : '';
  return _check_control _decode_utf8 $u;
}


sub reqURI {
  my $s = shift;
  return $s->reqBaseURI().$s->reqPath().$s->reqQuery();
}


sub reqHost {
  return $RENV->{HTTP_HOST}||'localhost';
}


sub reqIP {
  return $RENV->{REMOTE_ADDR}||'0.0.0.0';
}


sub reqFCGI {
  return shift->{_TUWF}{fcgi_req};
}

1;
