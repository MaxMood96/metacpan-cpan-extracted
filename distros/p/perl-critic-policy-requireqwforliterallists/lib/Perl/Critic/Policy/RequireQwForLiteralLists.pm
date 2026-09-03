package Perl::Critic::Policy::RequireQwForLiteralLists;
$Perl::Critic::Policy::RequireQwForLiteralLists::VERSION = '1.000';
# ABSTRACT: A row of quoted words is a qw() list written the long way.

use strict;
use warnings;

use 5.014;

use re '/aa';

use Readonly;

use Perl::Critic::Utils qw{ :severities :classification :ppi };
use parent              qw{Perl::Critic::Policy};


Readonly::Scalar my $DESC => q{Run of quoted literals should be a qw() list};
Readonly::Scalar my $EXPL => q{Write qw{a b c} instead of 'a', 'b', 'c'};

# Anything qw{} could not hold without changing what it means: whitespace to
# split on, a quote or backslash to re-interpret, or an empty string to lose.
Readonly::Scalar my $NOT_QW_ABLE_RX => qr/[\s\\'"]/xms;

# Interpolation, which qw{} does not do.
Readonly::Scalar my $INTERPOLATES_RX => qr/[\$\@]/xms;


sub supported_parameters {
    return ({
        name            => 'min_run_length',
        description     => 'How many adjacent literals before this is a qw() list.',
        default_string  => '3',
        behavior        => 'integer',
        integer_minimum => 2,
    });
}

sub default_severity { return $SEVERITY_LOW }
sub default_themes   { return qw(cosmetic maintenance) }

sub applies_to {
    return qw{
      PPI::Token::Quote::Single
      PPI::Token::Quote::Double
      PPI::Token::Quote::Literal
    };
}

# A literal qw{} could hold without changing its meaning: a bare word, no
# whitespace, no interpolation, no escapes.
sub _is_qw_able {
    my ($elem) = @_;

    return 0 if !$elem;
    return 0 if !$elem->isa('PPI::Token::Quote');

    my $string = $elem->string();
    return 0 if !defined $string || !length $string;
    return 0 if $string =~ $NOT_QW_ABLE_RX;
    return 0 if $elem->isa('PPI::Token::Quote::Double') && $string =~ $INTERPOLATES_RX;

    return 1;
}

# A plain comma, not a fat one: 'a' => 'b' is a pair, not a list to collapse.
sub _is_plain_comma {
    my ($elem) = @_;

    return 0 if !$elem;
    return 0 if !$elem->isa('PPI::Token::Operator');

    return $elem->content() eq q{,} ? 1 : 0;
}


sub violates {
    my ( $self, $elem, undef ) = @_;

    return if !_is_qw_able($elem);

    # Only report from the head of a run, or this fires once per element in it.
    my $comma = $elem->sprevious_sibling();
    return if _is_plain_comma($comma) && _is_qw_able( $comma->sprevious_sibling() );

    my $length = 1;
    my $cursor = $elem;
    while (1) {
        my $next = $cursor->snext_sibling();
        last if !_is_plain_comma($next);

        my $after = $next->snext_sibling();
        last if !_is_qw_able($after);

        $length++;
        $cursor = $after;
    }

    return if $length < $self->{_min_run_length};

    return $self->violation( $DESC, $EXPL, $elem );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Perl::Critic::Policy::RequireQwForLiteralLists - A row of quoted words is a qw() list written the long way.

=head1 VERSION

version 1.000

=head1 Perl::Critic::Policy::RequireQwForLiteralLists

A run of plain quoted words handed to something that takes a list is a C<qw()>
list spelled out one character at a time:

    $hv->system_hv( 'sudo', 'rm', '-f', $conf );
    return ( 'virsh', '-c', $uri, @args );

The quotes and commas carry no information here.  What they do is give you more
places to leave one out, and they bury the fact that the whole run is a single
command line under punctuation:

    $hv->system_hv( qw{sudo rm -f}, $conf );

=head2 PROHIBITED

    my @cmd = ( 'sudo', 'rm', '-f' );
    system( 'git', 'rev-parse', 'HEAD' );
    push @args, '--connect', '--verbose', '--force';

=head2 ALLOWED

Runs too short to be worth it, and anything C<qw> would change the meaning of:

    my @two = ( 'a', 'b' );                       # under the threshold
    my %h   = ( a => 'b', c => 'd' );             # fat commas, not a list
    my @s   = ( 'a b', 'c d', 'e f' );            # whitespace inside
    my @i   = ( "$dir", "$file", "$other" );      # interpolation
    my @e   = ( 'it\'s', 'a "quote"', 'a\\b' );   # quotes and escapes

=head2 CONFIGURATION

=over 4

=item C<min_run_length>

How many literals have to be adjacent before this is worth saying anything
about.  Defaults to 3.

    [RequireQwForLiteralLists]
    min_run_length = 4

=back

=head2 CAVEATS

A run split across a C<qw> and some literals -- C<< qw{sudo rm}, '-f' >> -- is
not detected, since the C<qw> breaks the run.  Only the literals on either side
of it are counted.

=head2 METHODS

=head3 supported_parameters

C<min_run_length>, how many adjacent literals make a run.

=head3 default_severity

SEVERITY_LOW

=head3 default_themes

cosmetic, maintenance

=head3 applies_to

PPI::Token::Quote::Single, PPI::Token::Quote::Double, PPI::Token::Quote::Literal

=head3 violates

Standard L<Perl::Critic::Policy> interface.  Returns one violation per run,
anchored on the literal that starts it, so a list of ten does not produce ten
complaints about itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/teodesian/perl-critic-policy-requireqwforliterallists/issues>

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
