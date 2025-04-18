# -*- perl -*-
##----------------------------------------------------------------------------
## Net/API/Telegram/InlineQueryResultMpeg4Gif.pm
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
package Net::API::Telegram::InlineQueryResultMpeg4Gif;
BEGIN
{
	use strict;
	use parent qw( Net::API::Telegram::Generic );
    our( $VERSION ) = '0.1';
};

sub caption { return( shift->_set_get_scalar( 'caption', @_ ) ); }

sub id { return( shift->_set_get_scalar( 'id', @_ ) ); }

sub input_message_content { return( shift->_set_get_object( 'input_message_content', 'Net::API::Telegram::InputMessageContent', @_ ) ); }

sub mpeg4_duration { return( shift->_set_get_number( 'mpeg4_duration', @_ ) ); }

sub mpeg4_height { return( shift->_set_get_number( 'mpeg4_height', @_ ) ); }

sub mpeg4_url { return( shift->_set_get_scalar( 'mpeg4_url', @_ ) ); }

sub mpeg4_width { return( shift->_set_get_number( 'mpeg4_width', @_ ) ); }

sub parse_mode { return( shift->_set_get_scalar( 'parse_mode', @_ ) ); }

sub reply_markup { return( shift->_set_get_object( 'reply_markup', 'Net::API::Telegram::InlineKeyboardMarkup', @_ ) ); }

sub thumb_url { return( shift->_set_get_scalar( 'thumb_url', @_ ) ); }

sub title { return( shift->_set_get_scalar( 'title', @_ ) ); }

sub type { return( shift->_set_get_scalar( 'type', @_ ) ); }

1;

__END__

=encoding utf-8

=head1 NAME

Net::API::Telegram::InlineQueryResultMpeg4Gif - A link to a video animation (H.264/MPEG-4 AVC video without sound)

=head1 SYNOPSIS

	my $msg = Net::API::Telegram::InlineQueryResultMpeg4Gif->new( %data ) || 
	die( Net::API::Telegram::InlineQueryResultMpeg4Gif->error, "\n" );

=head1 DESCRIPTION

L<Net::API::Telegram::InlineQueryResultMpeg4Gif> is a Telegram Message Object as defined here L<https://core.telegram.org/bots/api#inlinequeryresultmpeg4gif>

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

=item B<caption>( String )

Optional. Caption of the MPEG-4 file to be sent, 0-1024 characters

=item B<id>( String )

Unique identifier for this result, 1-64 bytes

=item B<input_message_content>( L<Net::API::Telegram::InputMessageContent> )

Optional. Content of the message to be sent instead of the video animation

=item B<mpeg4_duration>( Integer )

Optional. Video duration

=item B<mpeg4_height>( Integer )

Optional. Video height

=item B<mpeg4_url>( String )

A valid URL for the MP4 file. File size must not exceed 1MB

=item B<mpeg4_width>( Integer )

Optional. Video width

=item B<parse_mode>( String )

Optional. Send Markdown or HTML, if you want Telegram apps to show bold, italic, fixed-width text or inline URLs in the media caption.

=item B<reply_markup>( L<Net::API::Telegram::InlineKeyboardMarkup> )

Optional. Inline keyboard attached to the message

=item B<thumb_url>( String )

URL of the static thumbnail (jpeg or gif) for the result

=item B<title>( String )

Optional. Title for the result

=item B<type>( String )

Type of the result, must be mpeg4_gif

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

