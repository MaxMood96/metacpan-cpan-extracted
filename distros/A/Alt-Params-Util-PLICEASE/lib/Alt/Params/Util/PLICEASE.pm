package Alt::Params::Util::PLICEASE;

# ABSTRACT: Simple, compact and correct param-checking functions
our $VERSION = '0.01'; # VERSION

use 5.020;
use warnings;
use true;

__END__

=pod

=encoding UTF-8

=head1 NAME

Alt::Params::Util::PLICEASE - Simple, compact and correct param-checking functions

=head1 VERSION

version 0.01

=head1 SYNOPSIS

env PERL_ALT_INSTALL=OVERWRITE cpanm Alt::Params::Util::PLICEASE

=head1 DESCRIPTION

This module provides an alternate implementation for L<Params::Util>.
It will only be installed if you explicitly set C<PERL_ALT_INSTALL>
to C<OVERWRITE>.  L<Params::SomeUtil> has details on how the two
implementations differ.

=head1 SEE ALSO

=over 4

=item L<Alt>

=item L<Params::SomeUtil>

=back

=cut

=head1 AUTHOR

Graham Ollis <plicease@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Graham Ollis.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
