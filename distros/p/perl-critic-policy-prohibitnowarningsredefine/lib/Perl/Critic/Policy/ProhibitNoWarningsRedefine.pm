package Perl::Critic::Policy::ProhibitNoWarningsRedefine;
$Perl::Critic::Policy::ProhibitNoWarningsRedefine::VERSION = '1.000';
# ABSTRACT: Mock with Test::MockModule, don't clobber the symbol table by hand.

use strict;
use warnings;

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};


Readonly::Scalar my $DESC => q{Switching off a 'redefine' warning to patch the symbol table};
Readonly::Scalar my $EXPL => q{Use Test::MockModule in strict mode, which checks the sub exists and unmocks itself};


sub supported_parameters {
    return ({
        name           => 'categories',
        description    => 'Warning categories that may not be switched off.',
        default_string => 'redefine',
        behavior       => 'string list',
    });
}

sub default_severity { return $SEVERITY_HIGH }
sub default_themes   { return qw(maintenance tests) }
sub applies_to       { return 'PPI::Statement::Include' }


sub violates {
    my ( $self, $elem, undef ) = @_;

    return if $elem->type() ne 'no';

    my $module = $elem->module();
    return if !defined $module || $module ne 'warnings';

    # A bare `no warnings;` takes every category with it, ours included.
    my @named = _named_categories($elem);
    return $self->violation( $DESC, $EXPL, $elem ) if !@named;

    foreach my $category (@named) {
        return $self->violation( $DESC, $EXPL, $elem ) if $self->{_categories}{$category};
    }

    return;    # ok!
}

# Every literal category named in the statement, from a qw() list or a run of
# quoted strings alike.
sub _named_categories {
    my ($elem) = @_;

    my @names;
    foreach my $token ( $elem->schildren() ) {
        if ( $token->isa('PPI::Token::QuoteLike::Words') ) {
            push @names, $token->literal();
        }
        elsif ( $token->isa('PPI::Token::Quote') ) {
            push @names, $token->string();
        }
    }

    return grep { defined $_ && length $_ } @names;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::ProhibitNoWarningsRedefine - Mock with Test::MockModule, don't clobber the symbol table by hand.

=head1 VERSION

version 1.000

=head1 Perl::Critic::Policy::ProhibitNoWarningsRedefine

Switching off the C<redefine> warning has exactly one purpose: assigning over
somebody else's subroutine, usually in a test.

    no warnings 'redefine';
    local *Some::Module::thing = sub { 1 };

The warning is the only thing standing between you and a typo.  Misspell the
package or the sub and that line silently installs a brand new symbol nobody
calls, the test passes, and it goes on passing after the real code is deleted.

L<Test::MockModule> in strict mode does the same job and checks the sub exists
first, unmocks itself at scope exit, and does not need the warning switched off:

    my $mock = Test::MockModule->new('Some::Module');
    $mock->redefine( thing => sub { 1 } );

For a package with no F<.pm> of its own -- a modulino loaded out of F<bin/> --
pass C<< no_auto => 1 >> so it doesn't go looking for the file.

=head2 PROHIBITED

    no warnings 'redefine';
    no warnings qw{redefine once};
    no warnings;                    # this switches off redefine too

=head2 ALLOWED

    no warnings 'once';
    no warnings qw{uninitialized numeric};

=head2 CONFIGURATION

=over 4

=item C<categories>

Space separated list of warning categories that may not be switched off.
Defaults to C<redefine>.

    [ProhibitNoWarningsRedefine]
    categories = redefine prototype

=back

=head2 CAVEATS

A bare C<no warnings;> is flagged because it takes the guarded category with it,
which may not be why it was written.  That is the point: say which categories
you mean.

=head2 METHODS

=head3 supported_parameters

C<categories>, the warning categories that may not be switched off.

=head3 default_severity

SEVERITY_HIGH

=head3 default_themes

maintenance, tests

=head3 applies_to

PPI::Statement::Include

=head3 violates

Standard L<Perl::Critic::Policy> interface.  Returns a violation for a C<no
warnings> that switches off one of the guarded categories, whether it names it
or takes it along with everything else.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/perl-critic-policy-prohibitnowarningsredefine/issues>

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

Copyright (c) 2026 Troglodyne LLC


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
