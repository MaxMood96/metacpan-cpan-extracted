package Perl::Critic::Policy::ProhibitUseLib;
$Perl::Critic::Policy::ProhibitUseLib::VERSION = '1.000';
# ABSTRACT: Let the script find its own lib dir instead of spelling out a path.

use strict;
use warnings;

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};


Readonly::Scalar my $DESC => q{'use lib' hardcodes a path};
Readonly::Scalar my $EXPL => q{Use FindBin::libs (or other means to push to @INC) instead};


sub supported_parameters {
    return ({
        name           => 'modules',
        description    => 'Module names that hardcode a path onto @INC.',
        default_string => 'lib lib::relative',
        behavior       => 'string list',
    });
}

sub default_severity { return $SEVERITY_MEDIUM }
sub default_themes   { return qw(maintenance portability) }
sub applies_to       { return 'PPI::Statement::Include' }


sub violates {
    my ( $self, $elem, undef ) = @_;

    # 'no lib' takes a directory back off @INC, which is not our business.
    return if $elem->type() ne 'use';

    my $module = $elem->module();
    return if !defined $module;
    return if !$self->{_modules}{$module};

    return $self->violation( $DESC, $EXPL, $elem );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::ProhibitUseLib - Let the script find its own lib dir instead of spelling out a path.

=head1 VERSION

version 1.000

=head1 Perl::Critic::Policy::ProhibitUseLib

C<use lib "$FindBin::Bin/../lib"> is a path written out by hand, relative to a
script that may not stay where it is, repeated in every script that needs it:

    use FindBin;
    use lib "$FindBin::Bin/../lib";     # every script has this line
    use lib "$FindBin::Bin/../../lib";  # ...and this is the one that moved

Nothing checks it.  Move a script one directory deeper and it keeps compiling
right up until it loads the wrong copy of a module, or a stale one somebody
left in the parent of the parent.

L<FindBin::libs> walks up from the script and finds the C<lib> directory
itself, which is both shorter and correct after the move:

    use FindBin::libs;

=head2 PROHIBITED

    use lib "$FindBin::Bin/../lib";
    use lib '/opt/myapp/lib';
    use lib::relative '../lib';

=head2 ALLOWED

    use FindBin::libs;
    use lib::abs '../lib';    # if you have told the policy to allow it

C<no lib '...'> is left alone: taking a directory back off C<@INC> is not the
thing this policy is about.

=head2 CONFIGURATION

=over 4

=item C<modules>

Space separated list of module names to complain about.  Defaults to
C<lib lib::relative>.

    [ProhibitUseLib]
    modules = lib lib::relative lib::abs

=back

=head2 CAVEATS

This finds the pragma, not the practice.  A script that pushes onto C<@INC>
directly, or that shells out to something with C<PERL5LIB> set, is doing the
same thing by other means and goes unnoticed.

=head2 METHODS

=head3 supported_parameters

C<modules>, the list of pragma names to flag.

=head3 default_severity

SEVERITY_MEDIUM

=head3 default_themes

maintenance, portability

=head3 applies_to

PPI::Statement::Include

=head3 violates

Standard L<Perl::Critic::Policy> interface.  Returns a violation for a C<use>
of one of the configured pragmas, and nothing for anything else -- including
C<no lib>, which removes a directory rather than adding one.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/perl-critic-policy-prohibituselib/issues>

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
