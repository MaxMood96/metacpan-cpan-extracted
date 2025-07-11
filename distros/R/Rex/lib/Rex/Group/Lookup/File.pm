#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

=head1 NAME

Rex::Group::Lookup::File - read hostnames from a file.

=head1 DESCRIPTION

With this module you can define hostgroups out of a file.

=head1 SYNOPSIS

 use Rex::Group::Lookup::File;
 group "webserver" => lookup_file("./hosts.lst");


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Group::Lookup::File;

use v5.14.4;
use warnings;

our $VERSION = '1.16.1'; # VERSION

require Exporter;
use base qw(Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(lookup_file);

=head2 lookup_file($file)

With this function you can read hostnames from a file. Every hostname in one line.

 group "webserver"  => lookup_file("./webserver.lst");
 group "mailserver" => lookup_file("./mailserver.lst");

=cut

sub lookup_file {
  my ($file) = @_;

  open( my $fh, "<", $file ) or die($!);
  my @content = grep { !/^\s*$|^#/ } <$fh>;
  close($fh);

  chomp @content;

  return @content;
}

1;
