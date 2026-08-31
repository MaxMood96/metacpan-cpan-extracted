package Net::DAVTalk::XMLParser;

use base 'Exporter';

=head1 NAME

Net::DAVTalk - Interface to talk to DAV servers

=head1 SYNOPSIS

Net::DAVTalk::XMLParser is a simple wrapper around XML::Fast, returning
a more usable structure like that created by XML::Simple, but running
approximately 10 times faster in testing.

=head1 SUBROUTINES/METHODS

=head2 $hashref = xmlToHash($xmlstring);

Converts an XML string to a hashref of the content.

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2015-2026 Fastmail Pty Ltd.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself; that is, either the GNU General
Public License as published by the Free Software Foundation (version 1,
or at your option any later version), or the Artistic License.

See L<http://dev.perl.org/licenses/> and the LICENSE file included with
this distribution for more information.

=cut


our @EXPORT = qw(xmlToHash);

use XML::Fast;
use Carp qw(confess);

sub _nsexpand {
  my $data = shift;
  my $ns = shift || {};

  if (ref($data) eq 'HASH') {
    my @keys;
    my %res;
    foreach my $key (keys %$data) {
      if ($key eq '@xmlns') {
        $ns->{''} = $data->{$key};
      }
      elsif ($key eq '#text') {
        $res{'content'} = $data->{$key};
      }
      elsif (substr($key, 0, 7) eq '@xmlns:') {
        my $namespace = substr($key, 7);
        $ns->{$namespace} = $data->{$key};
        # this is what XML::Simple does with existing namespaces
        $res{"{http://www.w3.org/2000/xmlns/}$namespace"} = $data->{$key};
      }
      else {
        push @keys, $key;
      }
    }
    foreach my $key (@keys) {
      my %ns = %$ns; # copy, woot
      my $sub = _nsexpand($data->{$key}, \%ns);
      my $pos = index($key, ':');
      if ($pos > 0) {
        my $namespace = substr($key, 0, $pos);
        my $rest = substr($key, $pos+1);
        # move attribute sigil from namespace to value
        $rest = "\@$rest" if $namespace =~ s/^\@//;
        my $expanded = $ns{$namespace};
        confess "Unknown namespace $namespace" unless $expanded;
        $key = "{$expanded}$rest";
      }
      elsif ($key =~ m/^\@/) {
        # Attributes are never subject to the default namespace.
        # An attribute without an explicit namespace prefix is
        # considered not to be in any namespace.
      }
      elsif ($ns{''}) {
        my $expanded = $ns{''};
        $key = "{$expanded}$key";
      }
      $res{$key} = $sub;
    }
    return \%res;
  }
  elsif (ref($data) eq 'ARRAY') {
    return [ map { _nsexpand($_, $ns) } @$data ];
  }
  else {
    # like XML::Simple's ExpandContent option
    return { content => $data };
  }
}

sub xmlToHash {
  my $text = shift;

  my $Raw = XML::Fast::xml2hash($text, attr => '@');
  # like XML::Simple's NSExpand option
  my $Xml = _nsexpand($Raw);

  # XML::Simple returns the content of the top level key
  # (there should only be one)
  my ($key) = keys %$Xml;

  return $Xml->{$key};
}

1;
