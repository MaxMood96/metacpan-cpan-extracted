#!/usr/bin/perl -w

# Copyright 2008, 2016, 2024 Kevin Ryde

# This file is part of Chart.
#
# Chart is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3, or (at your option) any later version.
#
# Chart is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along
# with Chart.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use File::Slurp;
use HTTP::Message;

# uncomment this to run the ### lines
use Smart::Comments;

{
  require LWP::Protocol::http;
  my $socket_class = LWP::Protocol::http->socket_class;
  ### $socket_class
  # LWP::Protocol::http::Socket
  # subclass of Net::HTTP

  # Net::HTTP::Methods
  # $max_line_length = 32*1024 unless defined $max_line_length;
  # now 8*1024

  # cf  https://github.com/Qarj/WebImblaze/raw/master/wi.pl
  # push @LWP::Protocol::http::EXTRA_SOCK_OPTS, MaxLineLength => 0; # to prevent: Header line too long (limit is 8192)

  exit 0;
}

my $file = File::Slurp::slurp ('foo.gz');
print length($file),"\n";
my $chunk = substr ($file, 0, length($file)/2);

my $resp = HTTP::Message->new;
$resp->add_content($chunk);
$resp->push_header('Content-Encoding' => 'gzip');
print $resp->headers->as_string;

my $image = $resp->decoded_content(charset=>'none');
print length ($image);
