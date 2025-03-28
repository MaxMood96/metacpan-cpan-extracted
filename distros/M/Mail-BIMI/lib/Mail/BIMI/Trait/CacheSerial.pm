package Mail::BIMI::Trait::CacheSerial;
# ABSTRACT: Cacheable serial attribute trait
our $VERSION = '3.20250130'; # VERSION
use 5.20.0;
use Moose::Role;
Moose::Util::meta_attribute_alias('CacheSerial');
no Moose::Role;
1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Mail::BIMI::Trait::CacheSerial - Cacheable serial attribute trait

=head1 VERSION

version 3.20250130

=head1 REQUIRES

=over 4

=item * L<Moose::Role|Moose::Role>

=back

=head1 AUTHOR

Marc Bradshaw <marc@marcbradshaw.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by Marc Bradshaw.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
