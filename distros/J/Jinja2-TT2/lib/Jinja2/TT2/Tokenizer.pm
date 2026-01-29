package Jinja2::TT2::Tokenizer;

use strict;
use warnings;
use v5.20;

# Token types
use constant {
    TOK_TEXT       => 'TEXT',
    TOK_VAR_START  => 'VAR_START',
    TOK_VAR_END    => 'VAR_END',
    TOK_STMT_START => 'STMT_START',
    TOK_STMT_END   => 'STMT_END',
    TOK_COMMENT    => 'COMMENT',
    TOK_EXPR       => 'EXPR',
    TOK_NAME       => 'NAME',
    TOK_STRING     => 'STRING',
    TOK_NUMBER     => 'NUMBER',
    TOK_OPERATOR   => 'OPERATOR',
    TOK_PIPE       => 'PIPE',
    TOK_DOT        => 'DOT',
    TOK_COMMA      => 'COMMA',
    TOK_COLON      => 'COLON',
    TOK_LPAREN     => 'LPAREN',
    TOK_RPAREN     => 'RPAREN',
    TOK_LBRACKET   => 'LBRACKET',
    TOK_RBRACKET   => 'RBRACKET',
    TOK_LBRACE     => 'LBRACE',
    TOK_RBRACE     => 'RBRACE',
    TOK_ASSIGN     => 'ASSIGN',
    TOK_TILDE      => 'TILDE',
    TOK_EOF        => 'EOF',
};

# Jinja2 keywords
my %KEYWORDS = map { $_ => 1 } qw(
    if elif else endif
    for in endfor
    block endblock
    extends include import from
    macro endmacro call endcall
    filter endfilter
    set
    raw endraw
    with endwith
    autoescape endautoescape
    and or not
    is
    true false True False none None
    recursive
    as
    ignore missing
    without context
    scoped
);

sub new {
    my ($class, %opts) = @_;
    return bless {
        # Jinja2 delimiters (can be customized)
        block_start    => $opts{block_start}    // '{%',
        block_end      => $opts{block_end}      // '%}',
        variable_start => $opts{variable_start} // '{{',
        variable_end   => $opts{variable_end}   // '}}',
        comment_start  => $opts{comment_start}  // '{#',
        comment_end    => $opts{comment_end}    // '#}',
    }, $class;
}

sub tokenize {
    my ($self, $template) = @_;

    my @tokens;
    my $pos = 0;
    my $len = length($template);

    while ($pos < $len) {
        my $remaining = substr($template, $pos);

        # Check for comment {# ... #}
        if ($remaining =~ /^\{#-?\s*(.*?)\s*-?#\}/s) {
            my $comment = $1;
            push @tokens, { type => TOK_COMMENT, value => $comment, pos => $pos };
            $pos += length($&);
            next;
        }

        # Check for variable {{ ... }}
        if ($remaining =~ /^\{\{-?\s*/) {
            my $match_start = $&;
            my $strip_before = ($match_start =~ /-/) ? 1 : 0;
            $pos += length($match_start);

            push @tokens, {
                type => TOK_VAR_START,
                value => '{{',
                strip_before => $strip_before,
                pos => $pos - length($match_start)
            };

            # Tokenize the expression inside
            my ($expr_tokens, $new_pos) = $self->_tokenize_expression(
                $template, $pos, '}}'
            );
            push @tokens, @$expr_tokens;
            $pos = $new_pos;

            # Match closing }}
            $remaining = substr($template, $pos);
            if ($remaining =~ /^\s*(-?)\}\}/) {
                my $strip_after = $1 ? 1 : 0;
                push @tokens, {
                    type => TOK_VAR_END,
                    value => '}}',
                    strip_after => $strip_after,
                    pos => $pos
                };
                $pos += length($&);
            } else {
                die "Unclosed variable tag at position $pos";
            }
            next;
        }

        # Check for statement {% ... %}
        if ($remaining =~ /^\{%-?\s*/) {
            my $match_start = $&;
            my $strip_before = ($match_start =~ /-/) ? 1 : 0;
            $pos += length($match_start);

            push @tokens, {
                type => TOK_STMT_START,
                value => '{%',
                strip_before => $strip_before,
                pos => $pos - length($match_start)
            };

            # Tokenize the statement inside
            my ($stmt_tokens, $new_pos) = $self->_tokenize_expression(
                $template, $pos, '%}'
            );
            push @tokens, @$stmt_tokens;
            $pos = $new_pos;

            # Match closing %}
            $remaining = substr($template, $pos);
            if ($remaining =~ /^\s*(-?)%\}/) {
                my $strip_after = $1 ? 1 : 0;
                push @tokens, {
                    type => TOK_STMT_END,
                    value => '%}',
                    strip_after => $strip_after,
                    pos => $pos
                };
                $pos += length($&);
            } else {
                die "Unclosed statement tag at position $pos";
            }
            next;
        }

        # Plain text - find the next tag or end
        my $text_end = length($remaining);

        # Find position of next tag
        for my $pattern ('{{', '{%', '{#') {
            my $idx = index($remaining, $pattern);
            if ($idx >= 0 && $idx < $text_end) {
                $text_end = $idx;
            }
        }

        if ($text_end > 0) {
            my $text = substr($remaining, 0, $text_end);
            push @tokens, { type => TOK_TEXT, value => $text, pos => $pos };
            $pos += $text_end;
            next;
        }

        # Fallback - shouldn't happen normally
        $pos++;
    }

    push @tokens, { type => TOK_EOF, value => '', pos => $pos };
    return @tokens;
}

sub _tokenize_expression {
    my ($self, $template, $pos, $end_marker) = @_;

    my @tokens;
    my $len = length($template);
    my $end_re = quotemeta($end_marker);
    $end_re =~ s/\\\}/-?\\\}/;  # Allow whitespace control -

    while ($pos < $len) {
        my $remaining = substr($template, $pos);

        # Check for end marker (with optional whitespace control)
        last if $remaining =~ /^\s*-?$end_re/ || $remaining =~ /^\s*$end_re/;

        # Skip whitespace
        if ($remaining =~ /^(\s+)/) {
            $pos += length($1);
            next;
        }

        # String literals (single or double quoted)
        if ($remaining =~ /^("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')/) {
            push @tokens, { type => TOK_STRING, value => $1, pos => $pos };
            $pos += length($1);
            next;
        }

        # Numbers (integer or float)
        if ($remaining =~ /^(\d+(?:_\d+)*(?:\.\d+)?(?:[eE][+-]?\d+)?)/) {
            push @tokens, { type => TOK_NUMBER, value => $1, pos => $pos };
            $pos += length($1);
            next;
        }

        # Multi-character operators
        if ($remaining =~ /^(==|!=|<=|>=|<|>|\*\*|\/\/|and\b|or\b|not\b|in\b|is\b)/) {
            push @tokens, { type => TOK_OPERATOR, value => $1, pos => $pos };
            $pos += length($1);
            next;
        }

        # Single character operators
        if ($remaining =~ /^([+\-*\/%])/) {
            push @tokens, { type => TOK_OPERATOR, value => $1, pos => $pos };
            $pos += length($1);
            next;
        }

        # Pipe (filter separator)
        if ($remaining =~ /^\|/) {
            push @tokens, { type => TOK_PIPE, value => '|', pos => $pos };
            $pos++;
            next;
        }

        # Tilde (string concatenation)
        if ($remaining =~ /^~/) {
            push @tokens, { type => TOK_TILDE, value => '~', pos => $pos };
            $pos++;
            next;
        }

        # Dot
        if ($remaining =~ /^\./) {
            push @tokens, { type => TOK_DOT, value => '.', pos => $pos };
            $pos++;
            next;
        }

        # Comma
        if ($remaining =~ /^,/) {
            push @tokens, { type => TOK_COMMA, value => ',', pos => $pos };
            $pos++;
            next;
        }

        # Colon
        if ($remaining =~ /^:/) {
            push @tokens, { type => TOK_COLON, value => ':', pos => $pos };
            $pos++;
            next;
        }

        # Assignment
        if ($remaining =~ /^=(?!=)/) {
            push @tokens, { type => TOK_ASSIGN, value => '=', pos => $pos };
            $pos++;
            next;
        }

        # Parentheses
        if ($remaining =~ /^\(/) {
            push @tokens, { type => TOK_LPAREN, value => '(', pos => $pos };
            $pos++;
            next;
        }
        if ($remaining =~ /^\)/) {
            push @tokens, { type => TOK_RPAREN, value => ')', pos => $pos };
            $pos++;
            next;
        }

        # Brackets
        if ($remaining =~ /^\[/) {
            push @tokens, { type => TOK_LBRACKET, value => '[', pos => $pos };
            $pos++;
            next;
        }
        if ($remaining =~ /^\]/) {
            push @tokens, { type => TOK_RBRACKET, value => ']', pos => $pos };
            $pos++;
            next;
        }

        # Braces (for dict literals)
        if ($remaining =~ /^\{/) {
            push @tokens, { type => TOK_LBRACE, value => '{', pos => $pos };
            $pos++;
            next;
        }
        if ($remaining =~ /^\}/) {
            push @tokens, { type => TOK_RBRACE, value => '}', pos => $pos };
            $pos++;
            next;
        }

        # Names/identifiers/keywords
        if ($remaining =~ /^([a-zA-Z_][a-zA-Z0-9_]*)/) {
            my $name = $1;
            push @tokens, { type => TOK_NAME, value => $name, pos => $pos };
            $pos += length($name);
            next;
        }

        # Unknown character - skip
        $pos++;
    }

    return (\@tokens, $pos);
}

1;

__END__

=head1 NAME

Jinja2::TT2::Tokenizer - Tokenize Jinja2 templates

=head1 DESCRIPTION

Breaks Jinja2 template source into a stream of tokens for parsing.

=cut
