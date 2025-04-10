package Regex::Common::URI::gopher;
use strict;
use warnings;
use Regex::Common               qw /pattern clean no_defaults/;
use Regex::Common::URI          qw /register_uri/;
use Regex::Common::URI::RFC1738 qw /$host $port $uchars/;
use Regex::Common::URI::RFC1808 qw /$pchars $pchar_range/;

our $VERSION = 'v1.0.0'; # VERSION

my $pchars_notab =
  "(?:(?:[$pchar_range]+|" . "%(?:[1-9a-fA-F][0-9a-fA-F]|0[0-8a-fA-F]))*)";

my $gopherplus_string = $pchars;
my $search            = $pchars;
my $search_notab      = $pchars_notab;
my $selector          = $pchars;
my $selector_notab    = $pchars_notab;
my $gopher_type       = "(?:[0-9+IgT])";

my $scheme = "gopher";
my $uri    = "(?k:(?k:$scheme)://(?k:$host)(?::(?k:$port))?"
  . "/(?k:(?k:$gopher_type)(?k:$selector)))";
my $uri_notab =
    "(?k:(?k:$scheme)://(?k:$host)(?::(?k:$port))?"
  . "/(?k:(?k:$gopher_type)(?k:$selector_notab)"
  . "(?:%09(?k:$search_notab)(?:%09(?k:$gopherplus_string))?)?))";

register_uri $scheme => $uri;

pattern
  name   => [qw (URI gopher -notab=)],
  create => sub {
    exists $_[1]{-notab}
      && !defined $_[1]{-notab} ? $uri_notab : $uri;
  },
  ;

1;

__END__

=pod

=head1 NAME

Regex::Common::URI::gopher -- Returns a pattern for gopher URIs.

=head1 SYNOPSIS

    use Regex::Common qw /URI/;

    while (<>) {
        /$RE{URI}{gopher}/       and  print "Contains a gopher URI.\n";
    }

=head1 DESCRIPTION

=head2 $RE{URI}{gopher}{-notab}

Gopher URIs are poorly defined. Originally, RFC 1738 defined gopher URIs,
but they were later redefined in an internet draft. One that was expired
in June 1997.

The internet draft for gopher URIs defines them as follows:

    "gopher:" "//" host [ ":" port ] "/" gopher-type selector
                        [ "%09" search [ "%09" gopherplus_string ]]

Unfortunally, a I<selector> is defined in such a way that characters
may be escaped using the URI escape mechanism. This includes tabs,
which escaped are C<%09>. Hence, the syntax cannot distinguish between
a URI that has both a I<selector> and a I<search> part, and an URI
where the I<selector> includes an escaped tab. (The text of the draft
forbids tabs to be present in the I<selector> though).

C<$RE{URI}{gopher}> follows the defined syntax. To disallow escaped
tabs in the I<selector> and I<search> parts, use C<$RE{URI}{gopher}{-notab}>.

There are other differences between the text and the given syntax.
According to the text, selector strings cannot have tabs, linefeeds
or carriage returns in them. The text also allows the entire I<gopher-path>,
(the part after the slash following the hostport) to be empty; if this
is empty the slash may be omitted as well. However, this isn't reflected
in the syntax.

Under C<{-keep}>, the following are returned:

=over 4

=item $1

The entire URI.

=item $2

The scheme.

=item $3

The host (name or address).

=item $4

The port (if any).

=item $5

The "gopher-path", the part after the / following the host and port.

=item $6

The gopher-type.

=item $7

The selector. (When no C<{-notab}> is used, this includes the search
and gopherplus_string, including the separating escaped tabs).

=item $8

The search, if given. (Only when C<{-notab}> is given).

=item $9

The gopherplus_string, if given. (Only when C<{-notab}> is given).

=back

head1 REFERENCES

=over 4

=item B<[RFC 1738]>

Berners-Lee, Tim, Masinter, L., McCahill, M.: I<Uniform Resource
Locators (URL)>. December 1994.

=item B<[RFC 1808]>

Fielding, R.: I<Relative Uniform Resource Locators (URL)>. June 1995.

=item B<[GOPHER URL]>

Krishnan, Murali R., Casey, James: "A Gopher URL Format". Expired
Internet draft I<draft-murali-url-gopher>. December 1996.

=back

=head1 SEE ALSO

L<Regex::Common::URI> for other supported URIs.

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior <glasswalk3r@yahoo.com.br>

=head1 LICENSE and COPYRIGHT

This software is copyright (c) 2024 of Alceu Rodrigues de Freitas Junior,
glasswalk3r at yahoo.com.br

This file is part of regex-common project.

regex-commonis free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

regex-common is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
regex-common. If not, see (http://www.gnu.org/licenses/).

The original project [Regex::Common](https://metacpan.org/pod/Regex::Common)
is licensed through the MIT License, copyright (c) Damian Conway
(damian@cs.monash.edu.au) and Abigail (regexp-common@abigail.be).

=cut
