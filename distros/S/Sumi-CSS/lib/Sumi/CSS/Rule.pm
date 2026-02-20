package Sumi::CSS::Rule;

use Mojo::Base qw/-base -signatures/;
use Storable qw(dclone);

has "selector";
has "style";

sub type {
    my $self = shift;

    my $selector = join ", ", $self->selector->@*;

    if ($selector =~ /^\s*\@(media|supports|layer|scope)/) {
	return "block_at"
    }
    elsif ($selector =~ /^\s*\@/) {
	return "statement_at"
    }
    else {
	return "style"
    }
}

sub to_string_ugly {
    my $self = shift;
    my $string = "";;
    for ($self->type) {
	/statement_at/ && do {
	    $string .= sprintf "%s %s;\n", ((join ", ", $self->selector->@*), $self->style || "");
	    last
	};
	/block_at/ && do {
	    $string .= ((join ", ", $self->selector->@*) . " {");
	    $string .= $_->to_string for $self->style->@*;
	    $string .= "}\n"
	};
	/style/ && do {
	    $string .= sprintf "%s %s\n", ((join ", ", $self->selector->@*), $self->style);
	    last
	};
    }
    return $string;
}

sub localized {
    my $self = dclone(shift);
    my $lstr = shift;

    my $selector = join ", ", $self->selector->@*;

    for ($self->type) {
	/statement_at/ && do { last };
	/block_at/     && do { $_ = $_->localized($lstr) for $self->style->@*; last; };
	/style/        && do { $self->selector([ map { join " " , $lstr, $_ } $self->selector->@* ]); last };
    }
    return $self;
}


sub to_string {
    my ($self, $indent_level, $indent_depth) = @_;
    $indent_level //= 0;
    $indent_depth //= 4;

    my $pad = " " x ($indent_depth * $indent_level);         # 2-space indentation
    my $inner_pad = " " x ($indent_depth * ($indent_level + 1));

    my $string = "";

    for ($self->type) {
        /statement_at/ && do {
            $string .= sprintf "%s%s%s\n",
              $pad,
              (join ", ", $self->selector->@*),
              ($self->style // ";");
            last;
        };
        /block_at/ && do {
            $string .= $pad . (join ", ", $self->selector->@*) . " {\n";
            $string .= $_->to_string($indent_level + 1, $indent_depth) for $self->style->@*;
            $string .= $pad . "}\n";
            last;
        };
        /style/ && do {
            $string .= sprintf "%s%s %s\n",
              $pad,
              (join ", ", $self->selector->@*),
              $self->style;
            last;
        };
    }
    return $string;
}

1;


=head1 NAME

Sumi::CSS::Rule - A single CSS rule node for Sumi::CSS

=head1 SYNOPSIS

    use Sumi::CSS::Rule;

    my $rule = Sumi::CSS::Rule->new(
        selector => ['.foo'],
        style    => 'color: red;'
    );

    say $rule->type;           # "style"
    say $rule->to_string;      # ".foo color: red;"

=head1 DESCRIPTION

L<Sumi::CSS::Rule> represents a single CSS rule, at-rule, or nested block, with type introspection and formatting utilities.

=head1 ATTRIBUTES

=head2 selector

    my $sel = $rule->selector;
    $rule->selector(['.foo', '.bar']);

An array reference of selector strings.

=head2 style

    my $style = $rule->style;
    $rule->style('color: red;');

A string or array reference representing the CSS style body.  
In the case of nested at-rules, this may contain more C<Sumi::CSS::Rule> objects.

=head1 METHODS

=head2 type

    my $type = $rule->type;

Returns the rule type, one of:

=over 4

=item * C<style> — a normal CSS selector rule

=item * C<statement_at> — a statement-level at-rule (e.g. C<@import>)

=item * C<block_at> — a block-level at-rule (e.g. C<@media>)

=back

=head2 to_string

    my $text = $rule->to_string;
    my $text = $rule->to_string($indent_level, $indent_depth);

Returns the formatted CSS representation of this rule, optionally
with indentation control.

=head2 to_string_ugly

    my $text = $rule->to_string_ugly;

Returns a less formatted version of the rule, mainly used internally.

=head2 localized

    my $localized_rule = $rule->localized('.en');

Returns a deep-cloned copy of the rule with all selectors localized
by prefixing them with the provided string.

=head1 SEE ALSO

L<Sumi::CSS>

=head1 AUTHOR

Simone Cesano <scesano@cpan.org>

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut
