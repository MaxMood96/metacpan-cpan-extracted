use Modern::Perl;
package Intertangle::Jacquard::Error;
# ABSTRACT: Exceptions
$Intertangle::Jacquard::Error::VERSION = '0.002';
use custom::failures qw/
	Layout::MaximumNumberOfActors
	/;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Intertangle::Jacquard::Error - Exceptions

=head1 VERSION

version 0.002

=head1 EXTENDS

=over 4

=item * L<failure>

=back

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2017 by Zakariyya Mughal.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
