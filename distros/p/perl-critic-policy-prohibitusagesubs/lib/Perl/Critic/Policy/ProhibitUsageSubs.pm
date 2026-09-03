package Perl::Critic::Policy::ProhibitUsageSubs;
$Perl::Critic::Policy::ProhibitUsageSubs::VERSION = '1.000';
# ABSTRACT: Document the interface once, in POD, and let Pod::Usage print it.

use strict;
use warnings;

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};


Readonly::Scalar my $DESC => q{usage() subs duplicate documentation that belongs in POD};
Readonly::Scalar my $EXPL => q{Document the interface in POD and print it with Pod::Usage::pod2usage()};


sub supported_parameters {
    return ({
        name           => 'sub_names',
        description    => 'Subroutine names that should be POD instead.',
        default_string => 'usage _usage print_usage usage_message help',
        behavior       => 'string list',
    });
}

sub default_severity { return $SEVERITY_MEDIUM }
sub default_themes   { return qw(maintenance documentation) }
sub applies_to       { return 'PPI::Statement::Sub' }


sub violates {
    my ( $self, $elem, undef ) = @_;

    # A forward declaration has no body, so it isn't a duplicate of the POD yet.
    return if $elem->forward();

    my $name = $elem->name();
    return if !defined $name;

    # Fully qualified names count too; it is the last segment that matters.
    $name =~ s/\A .* :://xms;
    return if !$self->{_sub_names}{$name};

    return $self->violation( $DESC, $EXPL, $elem );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::ProhibitUsageSubs - Document the interface once, in POD, and let Pod::Usage print it.

=head1 VERSION

version 1.000

=head1 Perl::Critic::Policy::ProhibitUsageSubs

A hand-rolled C<usage()> is a second copy of the script's interface, kept in
step with the POD and with C<GetOptions> by faith alone:

    sub usage {
        return "Usage: $0 [--arg NAME] ...\n";
    }
    die usage() unless $condition;

Whichever the reader finds first is the one they believe, and it is reliably
the one that stopped being true two commits ago.

Write it in POD, where C<perldoc> and the man page find it too, and let
L<Pod::Usage> print that:

    =head1 SYNOPSIS

        myscript [--name NAME] DOMAIN

    =cut

    pod2usage( -exitval => 2, -verbose => 1, -input => __FILE__,
               -message => q{There's a snake in my boot} ) unless $condition;

=head2 PROHIBITED

    sub usage         { ... }
    sub _usage        { ... }
    sub print_usage   { ... }
    sub usage_message { ... }
    sub help          { ... }

=head2 ALLOWED

Anything else, including calls to C<pod2usage> and to a C<usage> imported from
elsewhere.  It is writing your own that this is about.

=head2 CONFIGURATION

=over 4

=item C<sub_names>

Space separated list of subroutine names to complain about.  Defaults to
C<usage _usage print_usage usage_message help>.

    [ProhibitUsageSubs]
    sub_names = halp what huh kerblammo

=back

=head2 CAVEATS

This goes by the name.  A C<sub help_text> that does the same job under another
name goes unnoticed, and a C<sub usage> that computes something unrelated to
the command line gets flagged anyway.  The name is the only evidence available
in the source.

=head2 METHODS

=head3 supported_parameters

C<sub_names>, the list of subroutine names to flag.

=head3 default_severity

SEVERITY_MEDIUM

=head3 default_themes

maintenance, documentation

=head3 applies_to

PPI::Statement::Sub

=head3 violates

Standard L<Perl::Critic::Policy> interface.  Returns a violation for a
declaration of one of the configured names, and nothing for a forward
declaration, which promises no second copy of anything.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/perl-critic-policy-prohibitusagesubs/issues>

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
