package Config::XrmDatabase::Failure;

# ABSTRACT: Exception class

use v5.26;
use warnings;

our $VERSION = '0.08';

use custom::failures::x::alias
  -suffix => '_failure',
  qw(
  key
  components
  file
  parameter
  internal
  query
  );

1;

#
# This file is part of Config-XrmDatabase
#
# This software is Copyright (c) 2021 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

Config::XrmDatabase::Failure - Exception class

=head1 VERSION

version 0.08

=for Pod::Coverage components_failure
file_failure
internal_failure
key_failure
parameter_failure
query_failure

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-config-xrmdatabase@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Config-XrmDatabase>

=head2 Source

Source is available at

  https://gitlab.com/djerius/config-xrmdatabase

and may be cloned from

  https://gitlab.com/djerius/config-xrmdatabase.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Config::XrmDatabase|Config::XrmDatabase>

=back

=head1 AUTHOR

Diab Jerius <djerius@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2021 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
