##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/File.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
## https://stripe.com/docs/api/files/object
package Net::API::Stripe::File;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Net::API::Stripe::Generic );
    use vars qw( $VERSION );
    our( $VERSION ) = 'v0.100.0';
};

use strict;
use warnings;

sub id { return( shift->_set_get_scalar( 'id', @_ ) ); }

sub object { return( shift->_set_get_scalar( 'object', @_ ) ); }

sub created { return( shift->_set_get_datetime( 'created', @_ ) ); }

sub expires_at { return( shift->_set_get_datetime( 'expires_at', @_ ) ); }

sub filename { return( shift->_set_get_scalar( 'filename', @_ ) ); }

sub links { return( shift->_set_get_object( 'links', 'Net::API::Stripe::File::Links', @_ ) ); }

sub purpose { return( shift->_set_get_scalar( 'purpose', @_ ) ); }

sub size { return( shift->_set_get_number( 'size', @_ ) ); }

sub title { return( shift->_set_get_scalar( 'title', @_ ) ); }

sub type { return( shift->_set_get_scalar( 'type', @_ ) ); }

sub url { return( shift->_set_get_uri( 'url', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::File - A file in Stripe API

=head1 SYNOPSIS

    my $file = $stripe->file({
        filename => 'some_file.jpg',
        links => $file_links_object,
        purpose => 'business_logo',
        size => 40069,
        title => 'Big Corp, Inc Logo',
        type => 'jpg',
        url => 'https://files.stripe.com/v1/files/file_fake123456789/contents',
    });

See documentation in L<Net::API::Stripe> for example to make api calls to Stripe to create those objects.

=head1 VERSION

    v0.100.0

=head1 DESCRIPTION

This is an object representing a file hosted on Stripe's servers. The file may have been uploaded by yourself using the create file request (for example, when uploading dispute evidence) or it may have been created by Stripe (for example, the results of a Sigma scheduled query L<https://stripe.com/docs/api/files#scheduled_queries>).

=head1 CONSTRUCTOR

=head2 new( %ARG )

Creates a new L<Net::API::Stripe::File> object.
It may also take an hash like arguments, that also are method of the same name.

=head1 METHODS

=head2 id string

Unique identifier for the object.

=head2 object string, value is "file"

String representing the object’s type. Objects of the same type share the same value.

=head2 created timestamp

Time at which the object was created. Measured in seconds since the Unix epoch.

=head2 expires_at timestamp

The time at which the file expires and is no longer available in epoch seconds.

=head2 filename string

A filename for the file, suitable for saving to a filesystem.

=head2 links list

This is a L<Net::API::Stripe::File::Links> object.

=head2 purpose string

The purpose of the file. Possible values are business_icon, business_logo, customer_signature, dispute_evidence, finance_report_run, identity_document, pci_document, sigma_scheduled_query, or tax_document_user_upload.

=head2 size integer

The size in bytes of the file object.

=head2 title string

A user friendly title for the document.

=head2 type string

The type of the file returned (e.g., csv, pdf, jpg, or png).

=head2 url string

The URL from which the file can be downloaded using your live secret API key.

=head1 API SAMPLE

    {
      "id": "file_fake123456789",
      "object": "file",
      "created": 1540111053,
      "filename": "file_fake123456789",
      "links": {
        "object": "list",
        "data": [
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571229407,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571225071,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571223490,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_1FUA14CeyNCl6fY2s3gFUjmP",
            "object": "file_link",
            "created": 1571222766,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571197169,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571176460,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1571099998,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1551509650,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1551509211,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          },
          {
            "id": "link_fake123456789",
            "object": "file_link",
            "created": 1547559540,
            "expired": false,
            "expires_at": null,
            "file": "file_fake123456789",
            "livemode": false,
            "metadata": {},
            "url": "https://files.stripe.com/links/fl_test_fake123456789"
          }
        ],
        "has_more": true,
        "url": "/v1/file_links?file=file_fake123456789"
      },
      "purpose": "dispute_evidence",
      "size": 9863,
      "title": null,
      "type": "png",
      "url": "https://files.stripe.com/v1/files/file_fake123456789/contents"
    }

=head1 HISTORY

=head2 v0.1

Initial version

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/files>, L<https://stripe.com/docs/file-upload>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
