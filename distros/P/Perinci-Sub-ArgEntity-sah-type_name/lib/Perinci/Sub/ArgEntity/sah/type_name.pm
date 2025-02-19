package Perinci::Sub::ArgEntity::sah::type_name;

our $DATE = '2016-06-12'; # DATE
our $VERSION = '0.001'; # VERSION

use 5.010001;
use strict;
use warnings;

use Complete::Module ();

sub complete_arg_val {
    Complete::Module::complete_module(
        @_,
        ns_prefix => 'Data::Sah::Type',
    );
}

1;
# ABSTRACT: Data and code related to function arguments of entity type 'sah::type_name'

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::Sub::ArgEntity::sah::type_name - Data and code related to function arguments of entity type 'sah::type_name'

=head1 VERSION

This document describes version 0.001 of Perinci::Sub::ArgEntity::sah::type_name (from Perl distribution Perinci-Sub-ArgEntity-sah-type_name), released on 2016-06-12.

=for Pod::Coverage ^(.+)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-Sub-ArgEntity-sah-type_name>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-Sub-ArgEntity-sah-type_name>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-Sub-ArgEntity-sah-type_name>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Perinci::Sub::ArgEntity>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
