##----------------------------------------------------------------------------
## Stripe API - ~/lib/Net/API/Stripe/Payment/Card/List.pm
## Version v0.100.0
## Copyright(c) 2019 DEGUEST Pte. Ltd.
## Author: Jacques Deguest <jack@deguest.jp>
## Created 2019/11/02
## Modified 2020/05/15
## 
##----------------------------------------------------------------------------
package Net::API::Stripe::Payment::Card::List;
BEGIN
{
    use strict;
    use warnings;
    use parent qw( Net::API::Stripe::List );
    use vars qw( $VERSION );
    our( $VERSION ) = 'v0.100.0';
};

use strict;
use warnings;

# sub data { return( shift->_set_get_object_array( 'data', 'Net::API::Stripe::Payment::Card', @_ ) ); }

1;

__END__

=encoding utf8

=head1 NAME

Net::API::Stripe::Payment::Card::List - A Stripe Payment Cards List Object

=head1 DESCRIPTION

This module inherits completely from L<Net::API::Stripe::List> and may be removed in the future.

=head1 AUTHOR

Jacques Deguest E<lt>F<jack@deguest.jp>E<gt>

=head1 SEE ALSO

Stripe API documentation:

L<https://stripe.com/docs/api/invoices/line_item>

=head1 COPYRIGHT & LICENSE

Copyright (c) 2019-2020 DEGUEST Pte. Ltd.

You can use, copy, modify and redistribute this package and associated
files under the same terms as Perl itself.

=cut
