# -*- perl -*-
##----------------------------------------------------------------------------
## Net/API/Telegram/InlineQueryResultCachedSticker.pm
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
package Net::API::Telegram::InlineQueryResultCachedSticker;
BEGIN
{
	use strict;
	use parent qw( Net::API::Telegram::Generic );
    our( $VERSION ) = '0.1';
};

sub download { return( shift->_download( @_ ) ); }

sub id { return( shift->_set_get_scalar( 'id', @_ ) ); }

sub input_message_content { return( shift->_set_get_object( 'input_message_content', 'Net::API::Telegram::InputMessageContent', @_ ) ); }

sub reply_markup { return( shift->_set_get_object( 'reply_markup', 'Net::API::Telegram::InlineKeyboardMarkup', @_ ) ); }

sub sticker_file_id { return( shift->_set_get_scalar( 'sticker_file_id', @_ ) ); }

sub type { return( shift->_set_get_scalar( 'type', @_ ) ); }

1;

__END__

=encoding utf-8

=head1 NAME

Net::API::Telegram::InlineQueryResultCachedSticker - A link to a sticker stored on the Telegram servers

=head1 SYNOPSIS

	my $msg = Net::API::Telegram::InlineQueryResultCachedSticker->new( %data ) || 
	die( Net::API::Telegram::InlineQueryResultCachedSticker->error, "\n" );

=head1 DESCRIPTION

L<Net::API::Telegram::InlineQueryResultCachedSticker> is a Telegram Message Object as defined here L<https://core.telegram.org/bots/api#inlinequeryresultcachedsticker>

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

=item B<download>( file_id, [ file extension ] )

Given a file id like sticker_file_id, this will call the B<getFile>() method from the parent L<Net::API::Telegram> package and receive a L<Net::API::Telegram::File> object in return, which contains a file path valid for only one hour according to Telegram api here L<https://core.telegram.org/bots/api#getfile>. With this file path, this B<download> method will issue a http get request and retrieve the file and save it locally in a temproary file generated by L<File::Temp>. If an extension is provided, it will be appended to the temproary file name such as C<myfile.jpg> otherwise the extension will be gussed from the mime type returned by the Telegram http server, if any.

This method returns undef() on error and sets a L<Net::API::Telegram::Error> or, on success, returns a hash reference with the following properties:

=over 8

=item I<filepath>

The full path to the temporary file

=item I<mime>

The mime type returned by the server.

=item I<response>

The L<HTTP::Response>

=item I<size>

The size in bytes of the file fetched

=back

=item B<download>(  )



=item B<id>( String )

Unique identifier for this result, 1-64 bytes

=item B<input_message_content>( L<Net::API::Telegram::InputMessageContent> )

Optional. Content of the message to be sent instead of the sticker

=item B<reply_markup>( L<Net::API::Telegram::InlineKeyboardMarkup> )

Optional. Inline keyboard attached to the message

=item B<sticker_file_id>( String )

A valid file identifier of the sticker

=item B<type>( String )

Type of the result, must be sticker

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

