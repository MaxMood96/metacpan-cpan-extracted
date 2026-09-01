package Perl::Critic::Policy::ProhibitPipeOpen;
$Perl::Critic::Policy::ProhibitPipeOpen::VERSION = '1.000';
# ABSTRACT: Don't let a pipe open be the quiet way to shell out.

use strict;
use warnings;

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};


# The mode argument of a three-or-more-arg open that makes it spawn something
# rather than open a file.
Readonly::Scalar my $PIPE_MODE_RX => qr/\A (?: -[|] | [|]- ) \z/xms;

# The same thing said the old way, with the pipe buried in a two-arg string:
# "cmd |" to read from it, "| cmd" to write to it.
Readonly::Scalar my $TWO_ARG_PIPE_RX => qr/ (?: \A \s* [|] | [|] \s* \z ) /xms;

Readonly::Scalar my $DESC => q{Pipe "open" used};
Readonly::Scalar my $EXPL => q{Shelling out needs signing off on -- use system/exec/qx with a '## no critic' saying why};


sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_HIGHEST }
sub default_themes       { return qw(security performance) }
sub applies_to           { return 'PPI::Token::Word' }


sub violates {
    my ( $self, $elem, undef ) = @_;

    return if $elem->content() ne 'open';
    return if !is_function_call($elem);

    my @args = parse_arg_list($elem);
    return if @args < 2;

    my $mode = $args[1]->[0];
    return if !$mode->isa('PPI::Token::Quote');

    # open($fh, '-|', @cmd) and friends, including the bare two-arg fork form.
    return $self->violation( $DESC, $EXPL, $elem ) if $mode->string() =~ $PIPE_MODE_RX;

    # open($fh, "cmd |").  Only ever a pipe when there is no third argument --
    # with one, the second argument is a mode and a stray '|' is not our business.
    return $self->violation( $DESC, $EXPL, $elem )
      if @args == 2 && $mode->string() =~ $TWO_ARG_PIPE_RX;

    return;    # ok!
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::ProhibitPipeOpen - Don't let a pipe open be the quiet way to shell out.

=head1 VERSION

version 1.000

=head1 Perl::Critic::Policy::ProhibitPipeOpen

L<Perl::Critic::Policy::logicLAB::ProhibitShellDispatch> flags C<system>,
C<exec>, C<qx> and backticks, which is every obvious way to run an external
command -- and not the pipe open, which does the same thing and reads the
command's output besides:

    open( my $fh, '-|', $bin, '--version' );   # not flagged by that policy
    my $version = qx{$bin --version};          # flagged

Having one of those be quietly acceptable turns the linter into an argument for
writing the shell-out in whichever spelling it happens not to look at, rather
than a decision somebody made.  This policy closes that off, so that every way
of starting a process needs the same explicit C<## no critic> and the comment
that ought to go with it.

It is not that a pipe open is worse.  In the list form it is the better of the
two -- no shell, so no quoting to get wrong.  It is that either one should be
on the record.

Modelled on L<Perl::Critic::Policy::InputOutput::ProhibitTwoArgOpen>, which has
the inverse job: it I<exempts> the fork handles this policy exists to find.

=head2 PROHIBITED

    open( my $fh, '-|', 'ls', '-l' );   # three-arg, read from a command
    open( my $fh, '|-', 'mail', $to );  # three-arg, write to a command
    open( my $fh, '-|' );               # two-arg fork
    open( FH, 'ls -l |' );              # two-arg, the old spelling
    open( FH, '| mail bob' );

=head2 ALLOWED

Ordinary file opens, which is every other thing C<open> does:

    open( my $fh, '<',  $path );
    open( my $fh, '>>', $path );
    open( my $fh, '<',  \$scalar );

=head2 CONFIGURATION

This policy is not configurable except for the standard options.

=head2 CAVEATS

The mode has to be a literal for this to see it.  A pipe open assembled at
runtime, C<< open( $fh, $mode, $cmd ) >> with C<$mode> computed, goes
unnoticed: the policy reads source, not intent.

=head2 METHODS

=head3 supported_parameters

None.

=head3 default_severity

SEVERITY_HIGHEST

=head3 default_themes

security, performance

=head3 applies_to

PPI::Token::Word

=head3 violates

Standard L<Perl::Critic::Policy> interface.  Returns a violation for an C<open>
whose mode says to spawn a process, and nothing for one that opens a file.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/perl-critic-policy-prohibitpipeopen/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHORS

Current Maintainers:

=over 4

=item *

George S. Baugh <teodesian@gmail.com>

=back

=head1 CONTRIBUTOR

=for stopwords George Baugh

George Baugh <andy@troglodyne.net>

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
