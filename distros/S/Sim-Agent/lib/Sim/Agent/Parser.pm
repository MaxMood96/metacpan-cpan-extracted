package Sim::Agent::Parser;

use strict;
use warnings;

sub new 
{
    bless {}, shift;
}

sub parse_file 
{
    my ($self, $file) = @_;

    open my $fh, '<', $file or die "Cannot open $file";
    local $/;
    my $text = <$fh>;
    close $fh;

    my $tokens = tokenize($text);
    my $ast    = parse($tokens);

    return $ast;
}

####################################


sub tokenize 
{

    my ($text) = @_;

    my @tokens;
    my $i = 0;
    my $len = length($text);

    while ($i < $len) 
    {

        my $char = substr($text, $i, 1);

        # skip whitespace
        if ($char =~ /\s/) 
        {
            $i++;
            next;
        }

        # comment
        if ($char eq ';') 
        {
            $i++;
            $i++ while $i < $len && substr($text,$i,1) ne "\n";
            next;
        }

        # left paren
        if ($char eq '(') 
        {
            push @tokens, { type => 'LPAREN' };
            $i++;
            next;
        }

        # right paren
        if ($char eq ')') 
        {
            push @tokens, { type => 'RPAREN' };
            $i++;
            next;
        }

        # string
        if ($char eq '"') 
        {
            $i++;
            my $str = '';
            while ($i < $len) 
            {
                my $c = substr($text,$i,1);

                if ($c eq '\\') 
                {
                    $i++;
                    my $next = substr($text,$i,1);
                    $str .= $next;
                    $i++;
                    next;
                }

                last if $c eq '"';

                $str .= $c;
                $i++;
            }

            die "Unterminated string" if $i >= $len;

            $i++;  # skip closing quote

            push @tokens, { type => 'STRING', value => $str };
            next;
        }

        # symbol
        my $symbol = '';
        while ($i < $len) 
        {
            my $c = substr($text,$i,1);
            last if $c =~ /\s/ || $c eq '(' || $c eq ')';
            $symbol .= $c;
            $i++;
        }

        push @tokens, { type => 'SYMBOL', value => $symbol };
    }

    return \@tokens;
}


sub parse 
{

    my ($tokens) = @_;

    my $pos = 0;

    my $ast = parse_expr($tokens, \$pos);

    die "Extra tokens after root" if $pos < @$tokens;

    return $ast;
}


sub parse_expr 
{

    my ($tokens, $pos_ref) = @_;

    my $token = $tokens->[$$pos_ref]
        or die "Unexpected end of input";

    # list
    if ($token->{type} eq 'LPAREN') 
    {

        $$pos_ref++;

        my @list;

        while (1) {

            my $next = $tokens->[$$pos_ref]
                or die "Unclosed parenthesis";

            last if $next->{type} eq 'RPAREN';

            push @list, parse_expr($tokens, $pos_ref);
        }

        $$pos_ref++;  # skip RPAREN

        return \@list;
    }

    # atom
    if ($token->{type} eq 'STRING') 
    {
        $$pos_ref++;
        return $token->{value};
    }

    if ($token->{type} eq 'SYMBOL') 
    {
        $$pos_ref++;
        return $token->{value};
    }

    die "Unexpected token type: $token->{type}";
}


1;


=pod

=head1 NAME

Sim::Agent::Parser - Tokenizes and parses the S-expression plan into an AST

=head1 DESCRIPTION

Implements a strict S-expression parser with support for parentheses, symbols, double-quoted strings, whitespace, and semicolon comments.

See L<Sim::Agent>.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=head1 LICENSE

The GNU General Public License v3.0

=cut


