# -*- perl -*-
##----------------------------------------------------------------------------
## Net/API/Telegram/MaskPosition.pm
## Version 0.1
## Copyright(c) 2019 Jacques Deguest
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/05/29
## Modified 2020/06/13
## All rights reserved.
## 
## This program is free software; you can redistribute it and/or modify it 
## under the same terms as Perl itself.
##----------------------------------------------------------------------------
package Net::API::Telegram::MaskPosition;
BEGIN
{
	use strict;
	use parent qw( Net::API::Telegram::Generic );
    our( $VERSION ) = '0.1';
};

sub point { return( shift->_set_get_scalar( 'point', @_ ) ); }

sub scale { return( shift->_set_get_number( 'scale', @_ ) ); }

sub x_shift { return( shift->_set_get_number( 'x_shift', @_ ) ); }

sub y_shift { return( shift->_set_get_number( 'y_shift', @_ ) ); }

1;

__END__

=encoding utf-8

=head1 NAME

Net::API::Telegram::MaskPosition - The position on faces where a mask should be placed by default

=head1 SYNOPSIS

	my $msg = Net::API::Telegram::MaskPosition->new( %data ) || 
	die( Net::API::Telegram::MaskPosition->error, "\n" );

=head1 DESCRIPTION

L<Net::API::Telegram::MaskPosition> is a Telegram Message Object as defined here L<https://core.telegram.org/bots/api#maskposition>

This module has been automatically generated from Telegram API documentation by the script scripts/telegram-doc2perl-methods.pl.

=head1 METHODS

=over 4

=item B<new>( {INIT HASH REF}, %PARAMETERS )

B<new>() will create a new object for the package, pass any argument it might receive
to the special standard routine B<init> that I<must> exist. 
Then it returns what returns B<init>().

The valid parameters are as follow. Methods available here are also parameters to the B<new> method.

=over 8

=item * I<verbose>

=item * I<debug>

=back

=item B<point>( String )

The part of the face relative to which the mask should be placed. One of I<forehead>, I<eyes>, I<mouth>, or I<chin>.

=item B<scale>( Float number )

Mask scaling coefficient. For example, 2.0 means double size.

=item B<x_shift>( Float number )

Shift by X-axis measured in widths of the mask scaled to the face size, from left to right. For example, choosing -1.0 will place mask just to the left of the default mask position.

=item B<y_shift>( Float number )

Shift by Y-axis measured in heights of the mask scaled to the face size, from top to bottom. For example, 1.0 will place the mask just below the default mask position.

=back

=head1 COPYRIGHT

Copyright (c) 2000-2019 DEGUEST Pte. Ltd.

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

L<Net::API::Telegram>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2018-2019 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut

