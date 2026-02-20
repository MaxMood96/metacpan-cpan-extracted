package Sumi::CSS::Util;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(_walk _parse_rules _remove_comments);

my $stmt_at_rule_re  = qr/^\s*(\@(?:charset|import|namespace))\b([^;]*);(.*)$/ms;
my $block_at_rule_re = qr/^\s*\@(media|supports|layer|scope)\b(.*)$/;

use Text::Balanced qw(extract_bracketed);
use Mojo::Util qw/trim/;

sub _walk {
    my $rules = shift;
    my ($cb, $cb_s, $cb_f) = map { $_ ? $_ : sub {} } @_[0..2];

    for ($rules->@*) {
	if (ref $_->{style} eq "ARRAY") {
	    $cb_s->($_);
	    _walk($_->{style}, $cb, $cb_s, $cb_f);
	    $cb_f->($_);
	} else {
	    $cb->($_)
	}
    }
}


sub _remove_comments {
    my $css = shift;
    my $out = '';
    while (length $css) {
        # Match strings (single or double quoted)
        if ($css =~ s/^("([^"\\]|\\.)*"|'([^'\\]|\\.)*')//s) {
            $out .= $1;  # keep strings intact
        }
        # Match comments
        elsif ($css =~ s{^/\*[^*]*\*+([^/*][^*]*\*+)*/}{}s) {
            # drop comment
        }
        else {
            # copy one char if nothing matches
            $out .= substr($css, 0, 1, '');
        }
    }
    return $out;
}


sub _parse_rules {
    my $rest = _remove_comments(shift);
    my $opts = shift || {};

    my ($selector, $style, $type);
    my $rules;
    while ($rest =~ /\S/) {
	($rest, $selector, $style, $type) = _parse_one_rule($rest);
	push $rules->@*,
	    ($opts->{unblessed} ? { selector => $selector, style => $style } :
	     Sumi::CSS::Rule->new({ selector => $selector, style => $style }));
    }
    return $rules;
}

sub _parse_one_rule {
    my $rest = shift;
    my ($selector, $rule);

    if ($rest =~ $stmt_at_rule_re) {
        return $3, [ trim($1 . $2) ], $rule;
    }

    ($selector, $rest) = $rest =~ /^\s*(.+?)(\{.+)/ms;
    ($rule, $rest) = extract_bracketed($rest, '{}');
    $rule =~ s/\s*\n\s*/ /gms;

    if ($selector =~ $block_at_rule_re) {
	$rule =~ /^\s*\{(.+)\}\s*$/ms;
	$rule = _parse_rules($1);
	$type = "block_at";
    } else {
	$type = "style";
    }
    $selector = [ split /\s*\,\s*/, trim($selector) ];
    return $rest, $selector, $rule;
}

1