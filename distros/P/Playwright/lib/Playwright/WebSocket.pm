# ABSTRACT: Automatically generated class for Playwright::WebSocket
# PODNAME: Playwright::WebSocket

# These classes used to be generated at runtime, but are now generated when the module is built.
# Don't send patches against these modules, they will be ignored.
# See generate_perl_modules.pl in the repository for generating this.

use strict;
use warnings;

package Playwright::WebSocket;
$Playwright::WebSocket::VERSION = '1.532';
use parent 'Playwright::Base';

sub new {
    my ( $self, %options ) = @_;
    $options{type} = 'WebSocket';
    return $self->SUPER::new(%options);
}

sub spec {
    return $Playwright::spec->{'WebSocket'}{members};
}

sub waitForEvent {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'waitForEvent',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub url {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'url',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub waitForFrameReceived {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'waitForFrameReceived',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub isClosed {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'isClosed',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub frameReceived {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'frameReceived',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub waitForFrameSent {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'waitForFrameSent',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub frameSent {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'frameSent',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub socketError {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'socketError',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub waitForEvent2 {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'waitForEvent2',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub close {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'close',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub on {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'on',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub evaluate {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'evaluate',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub evaluateHandle {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'evaluateHandle',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Playwright::WebSocket - Automatically generated class for Playwright::WebSocket

=head1 VERSION

version 1.532

=head1 CONSTRUCTOR

=head2 new(%options)

You shouldn't have to call this directly.
Instead it should be returned to you as the result of calls on Playwright objects, or objects it returns.

=head1 METHODS

=head2 waitForEvent(@args)

Execute the WebSocket::waitForEvent playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-waitForEvent> for more information.

=head2 url(@args)

Execute the WebSocket::url playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-url> for more information.

=head2 waitForFrameReceived(@args)

Execute the WebSocket::waitForFrameReceived playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-waitForFrameReceived> for more information.

=head2 isClosed(@args)

Execute the WebSocket::isClosed playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-isClosed> for more information.

=head2 frameReceived(@args)

Execute the WebSocket::frameReceived playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-frameReceived> for more information.

=head2 waitForFrameSent(@args)

Execute the WebSocket::waitForFrameSent playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-waitForFrameSent> for more information.

=head2 frameSent(@args)

Execute the WebSocket::frameSent playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-frameSent> for more information.

=head2 socketError(@args)

Execute the WebSocket::socketError playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-socketError> for more information.

=head2 waitForEvent2(@args)

Execute the WebSocket::waitForEvent2 playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-waitForEvent2> for more information.

=head2 close(@args)

Execute the WebSocket::close playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-close> for more information.

=head2 on(@args)

Execute the WebSocket::on playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-on> for more information.

=head2 evaluate(@args)

Execute the WebSocket::evaluate playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-evaluate> for more information.

=head2 evaluateHandle(@args)

Execute the WebSocket::evaluateHandle playwright routine.

See L<https://playwright.dev/docs/api/class-WebSocket#WebSocket-evaluateHandle> for more information.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Playwright|Playwright>

=back

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/playwright-perl/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHORS

Current Maintainers:

=over 4

=item *

George S. Baugh <teodesian@gmail.com>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2020 Troglodyne LLC


Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

=cut
