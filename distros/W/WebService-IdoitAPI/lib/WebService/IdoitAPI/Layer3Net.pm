package WebService::IdoitAPI::Layer3Net;

use warnings;
use strict;
use Carp;

use WebService::IdoitAPI;

use version; our $VERSION = qv('v0.3.1');

sub new {
    my ($class, $api) = @_;
    my $self = {
        api => $api,
    };
    
    bless $self, $class;

    return $self;
} # new()

1; # Magic true value required at end of module
__END__

=head1 NAME

WebService::IdoitAPI::Layer3Net - handle layer 3 networks


=head1 VERSION

This document describes WebService::IdoitAPI::Layer3Net version v0.3.1


=head1 SYNOPSIS

    use WebService::IdoitAPI::Layer3Net;

    my $api = WebService::IdoitAPI->new( $config );
    my $l3n = WebService::IdoitAPI::Layer3Net->new( $api );

    my $nets = $l3n->list();

    for my $net ( @$nets ) {
        my $details = $l3n->get( $net->{id} );

        # do something
    }


=head1 DESCRIPTION


=head1 INTERFACE 

=head2 Methods

=head3 new( $api );

    my $api = WebService::IdoitAPI->new( $config );
    my $l3n = WebService::IdoitAPI::Layer3Net->new( $api );

The constructor takes a fully configured C<WebService::IdoitAPI> object
which is used to perform all necessary API calls.

=head1 DIAGNOSTICS

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=back


=head1 CONFIGURATION AND ENVIRONMENT

WebService::IdoitAPI::Layer3Net requires no configuration files or environment variables.

=head1 DEPENDENCIES

None.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-app-new@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Mathias Weidner  C<< <mamawe@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 123, Mathias Weidner C<< <mamawe@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
