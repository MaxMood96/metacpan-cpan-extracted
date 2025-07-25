package Dist::Zilla::MintingProfile::Author::YANICK;
our $AUTHORITY = 'cpan:YANICK';
# ABSTRACT: create distributions like YANICK
$Dist::Zilla::MintingProfile::Author::YANICK::VERSION = '0.32.0';
use strict;
use warnings;

use Moose;

with 'Dist::Zilla::Role::MintingProfile::ShareDir';

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::MintingProfile::Author::YANICK - create distributions like YANICK

=head1 VERSION

version 0.32.0

=head1 AUTHOR

Yanick Champoux <yanick@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2025 by Yanick Champoux.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
