# ABSTRACT: Automatically generated class for Playwright::Error
# PODNAME: Playwright::Error

# These classes used to be generated at runtime, but are now generated when the module is built.
# Don't send patches against these modules, they will be ignored.
# See generate_perl_modules.pl in the repository for generating this.

use strict;
use warnings;

package Playwright::Error;
$Playwright::Error::VERSION = '1.551';
use parent 'Playwright::Base';

sub new {
    my ( $self, %options ) = @_;
    $options{type} = 'Error';
    return $self->SUPER::new(%options);
}

sub spec {
    return $Playwright::spec->{'Error'}{members};
}

sub name {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'name',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub stack {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'stack',
        object  => $self->{guid},
        type    => $self->{type}
    );
}

sub message {
    my $self = shift;
    return $self->_api_request(
        args    => [@_],
        command => 'message',
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

Playwright::Error - Automatically generated class for Playwright::Error

=head1 VERSION

version 1.551

=head1 CONSTRUCTOR

=head2 new(%options)

You shouldn't have to call this directly.
Instead it should be returned to you as the result of calls on Playwright objects, or objects it returns.

=head1 METHODS

=head2 name(@args)

Execute the Error::name playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-name> for more information.

=head2 stack(@args)

Execute the Error::stack playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-stack> for more information.

=head2 message(@args)

Execute the Error::message playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-message> for more information.

=head2 on(@args)

Execute the Error::on playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-on> for more information.

=head2 evaluate(@args)

Execute the Error::evaluate playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-evaluate> for more information.

=head2 evaluateHandle(@args)

Execute the Error::evaluateHandle playwright routine.

See L<https://playwright.dev/docs/api/class-Error#Error-evaluateHandle> for more information.

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

Copyright (c) 2025 Troglodyne LLC


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
