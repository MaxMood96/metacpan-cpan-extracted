package Pod::Elemental::Element::Pod5::Command 0.103006;
# ABSTRACT: a Pod5 =command element

use Moose;

extends 'Pod::Elemental::Element::Generic::Command';
with    'Pod::Elemental::Autoblank';
with    'Pod::Elemental::Autochomp';

use Pod::Elemental::Types qw(ChompedString);
has '+content' => (
  coerce => 1,
  isa    => ChompedString,
);

#pod =head1 OVERVIEW
#pod
#pod Pod5::Command elements are identical to
#pod L<Generic::Command|Pod::Elemental::Element::Generic::Command> elements, except
#pod that they incorporate L<Pod::Elemental::Autoblank>.  They represent command
#pod paragraphs in a Pod5 document.
#pod
#pod =cut

use namespace::autoclean;

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Pod::Elemental::Element::Pod5::Command - a Pod5 =command element

=head1 VERSION

version 0.103006

=head1 OVERVIEW

Pod5::Command elements are identical to
L<Generic::Command|Pod::Elemental::Element::Generic::Command> elements, except
that they incorporate L<Pod::Elemental::Autoblank>.  They represent command
paragraphs in a Pod5 document.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 AUTHOR

Ricardo SIGNES <cpan@semiotic.systems>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Ricardo SIGNES.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
