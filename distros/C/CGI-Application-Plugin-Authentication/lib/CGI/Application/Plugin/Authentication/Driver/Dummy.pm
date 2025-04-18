package CGI::Application::Plugin::Authentication::Driver::Dummy;
$CGI::Application::Plugin::Authentication::Driver::Dummy::VERSION = '0.25';
use strict;
use warnings;

use base qw(CGI::Application::Plugin::Authentication::Driver);

=head1 NAME

CGI::Application::Plugin::Authentication::Driver::Dummy - Dummy Authentication driver which
lets anyone authenticate regardless of the password they provide

=head1 SYNOPSIS

 use base qw(CGI::Application);
 use CGI::Application::Plugin::Authentication;

  __PACKAGE__->authen->config(
        DRIVER => 'Dummy',
  );

=head1 DESCRIPTION

This Driver is the anti-authentication driver, since it doesn't check the
credentials at all, and just accepts whatever the user has entered.
It can be useful in development, or if you want a guest based system without
passwords.


=head1 EXAMPLE

  __PACKAGE__->authen->config(
        DRIVER => 'Dummy',
  );


=head1 METHODS

=head2 verify_credentials

This method will automatically return the first credential as the username without checking
anything else.

=cut

sub verify_credentials {
    my $self = shift;
    return shift;
}


=head1 SEE ALSO

L<CGI::Application::Plugin::Authentication::Driver>, L<CGI::Application::Plugin::Authentication>, perl(1)


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, SiteSuite. All rights reserved.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

=cut

1;
