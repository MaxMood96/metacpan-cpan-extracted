package Sumi::CSS;

use Mojo::Base qw/-base -signatures/;
use Class::Method::Modifiers;
use Storable qw(dclone);

use Sumi::CSS::Util qw(_walk _parse_rules _remove_comments);
use Sumi::CSS::Rule;

# ABSTRACT: Mojo-like access to cascading style sheets

has rules => sub { [] };  # array of rule nodes

my $stmt_at_rule_re = qr/^\s*(\@(?:charset|import|namespace))\b([^;]*);(.*)$/ms;
my $block_at_rule_re = qr/^\s*\@(media|supports|layer|scope)\b(.*)$/;

around new => sub {
    my $orig = shift;
    my $self = shift;
    my $ret;
    if ($_[1] && !ref $_[1]) {
	my $css = shift;
	return $self->new(@_)->parse($css);
    }
    return $orig->($self, @_);
};

sub parse {
    my $self = shift;
    my $css = shift;
    $self->rules(_parse_rules($css));
    $self;
}

sub walk {
    my $self = shift;
    my $rules = $self->rules;
    _walk($rules, @_);
    return $self;
}

sub to_string {
    my $self = shift;
    my $opts = shift || {};
    my $minimize = $opts->{minimize};
    my $indent   = $opts->{indent};

    my $css = join "\n", map { $_->to_string(0, $indent) } $self->rules->@*;

    if ($minimize) {
	for ($css) {
	    s/^[ \t]+//mg;
	    s/[ \t]+$//mg;
	    s/\n/ /g;
	}
    }
    return $css;
}


sub localized {
    my $self = dclone(shift());
    my $lstr = shift;
    $self->rules([ map { $_->localized($lstr) } $self->rules->@* ]);
    $self;
}


=head1 NAME

Sumi::CSS - Mojo-like access to cascading style sheets

=head1 SYNOPSIS

    use Sumi::CSS;

    # Parse CSS text
    my $css = Sumi::CSS->new->parse(<<'CSS');
    @media screen {
      body { color: black; background: white; }
    }
    .foo { color: red; }
    CSS

    # Walk the rules
    $css->walk(sub ($rule) {
        say $rule->to_string;
    });

    # Get the full CSS back as string
    say $css->to_string;

    # Minify output
    say $css->to_string({ minimize => 1 });

    # Indented output (custom depth)
    say $css->to_string({ indent => 2 });

    # Create a localized copy of the CSS
    my $localized = $css->localized('.en');

=head1 DESCRIPTION

L<Sumi::CSS> provides a L<Mojolicious>-style object interface for parsing,
walking, and reconstructing CSS documents with support of nested at-rules.

=head1 ATTRIBUTES

=head2 rules

    my $rules = $css->rules;
    $css->rules([ $rule1, $rule2 ]);

An array reference of L<Sumi::CSS::Rule> objects representing parsed CSS rules.

=head1 METHODS

=head2 new

    my $css = Sumi::CSS->new;
    my $css = Sumi::CSS->new->parse($css_text);
    my $css = Sumi::CSS->new($other_css);

Creates a new C<Sumi::CSS> object.  
If called with a string as the first argument, it automatically parses
that string as CSS content.

=head2 parse

    $css = $css->parse($css_text);

Parses a CSS string and populates the internal rule list.

=head2 walk

    $css->walk(sub ($rule) { ... });

Walks over all CSS rules (recursively for nested at-rules) and applies
the provided callback. Returns the invocant for chaining.

=head2 to_string

    my $string = $css->to_string;
    my $string = $css->to_string({ minimize => 1 });
    my $string = $css->to_string({ indent => 2 });

Serializes the parsed CSS back into text.  
Takes an optional hash reference with the following keys:

=over 4

=item * C<minimize>

If true, removes extra whitespace and newlines for compact output.

=item * C<indent>

Controls indentation depth (default: 4 spaces).

=back

=head2 localized

    my $localized = $css->localized('.en');

Returns a deep-cloned version of the CSS tree with selectors localized
using the given prefix (e.g. prepending C<.en> to class selectors).
This can be used for namespacing or scoping CSS for localization or components.

=head1 INTERNALS

=head2 _parse_rules, _walk, _remove_comments

These internal helper functions are provided by L<Sumi::CSS::Util> and are
not intended for external use.

=head1 SEE ALSO

L<Mojolicious>, L<Mojo::DOM>, L<CSS::Tiny>, L<CSS::SAC::Parser>

=head1 AUTHOR

Simone Cesano

=head1 LICENSE

This module is released under the same terms as Perl itself.

=cut

1;
