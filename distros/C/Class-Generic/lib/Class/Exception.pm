##----------------------------------------------------------------------------
## Class Generic - ~/lib/Class/Exception.pm
## Version v0.1.2
## Copyright(c) 2022 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2022/02/27
## Modified 2022/03/07
## All rights reserved
## 
## This program is free software; you can redistribute  it  and/or  modify  it
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
package Class::Exception;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Module::Generic::Exception );
    our $VERSION = 'v0.1.2';
};

1;

__END__

=encoding utf8

=head1 NAME

Class::Exception - An Exception Object Class

=head1 SYNOPSIS

    use Class::Exception;
    my $ex = Class::Exception->new;

=head1 VERSION

    v0.1.2

=head1 DESCRIPTION

This package provides a versatile exception class object for the manipulation and chaining of exceptions.

See L<Module::Generic::Exception> for more information.

=head1 SEE ALSO

L<Class::Generic>, L<Class::Array>, L<Class::Scalar>, L<Class::Number>, L<Class::Boolean>, L<Class::Assoc>, L<Class::File>, L<Class::DateTime>, L<Class::Exception>, L<Class::Finfo>, L<Class::NullChain>, L<Class::DateTime>

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2022 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
