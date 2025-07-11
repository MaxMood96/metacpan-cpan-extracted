package Gherkin::TokenMatcher;
$Gherkin::TokenMatcher::VERSION = '33.0.0';
use strict;
use warnings;

use List::Util qw(any first reduce);

our $LANGUAGE_RE = qr/^\s*#\s*language\s*:\s*([a-zA-Z\-_]+)\s*$/o;

use Class::XSAccessor accessors => [
    qw/dialect _default_dialect_name _indent_to_remove _active_doc_string_separator _keyword_types _sorted_step_keywords /,
];

use Cucumber::Messages;
use Gherkin::Dialect;


sub new {
    my ( $class, $options ) = @_;
    $options->{'dialect'} ||= Gherkin::Dialect->new( { dialect => 'en' } );
    my $self = bless $options, $class;
    $self->_default_dialect_name( $self->dialect_name );
    $self->reset();
    return $self;
}

sub _add_keyword_type_mappings {
    my ($keyword_types, $keywords, $type) = @_;

    for my $keyword (@{$keywords}) {
        if (not exists $keyword_types->{$keyword}) {
            $keyword_types->{$keyword} = [];
        }
        push @{$keyword_types->{$keyword}}, $type;
    }
}

sub dialect_name { $_[0]->dialect->dialect }
sub change_dialect {
    my $self = shift;
    $self->dialect->change_dialect(@_);

    my $keyword_types = {};
    _add_keyword_type_mappings($keyword_types, $self->dialect->Given,
                               Cucumber::Messages::Step::KEYWORDTYPE_CONTEXT);
    _add_keyword_type_mappings($keyword_types, $self->dialect->When,
                               Cucumber::Messages::Step::KEYWORDTYPE_ACTION);
    _add_keyword_type_mappings($keyword_types, $self->dialect->Then,
                               Cucumber::Messages::Step::KEYWORDTYPE_OUTCOME);
    _add_keyword_type_mappings($keyword_types,
                               [ @{ $self->dialect->And }, @{ $self->dialect->But } ],
                               Cucumber::Messages::Step::KEYWORDTYPE_CONJUNCTION);
    $self->_keyword_types( $keyword_types );
    $self->_sorted_step_keywords(
        [ sort {
            length $b <=> length $a  # longest keyword first (See #400)
          } map {
              @{ $self->dialect->$_ }
          } qw/Given When Then And But/ ]
        );
}

sub reset {
    my $self = shift;
    $self->change_dialect( $self->_default_dialect_name );
    $self->_indent_to_remove(0);
    $self->_active_doc_string_separator(undef);

}

sub match_FeatureLine {
    my ( $self, $token ) = @_;
    $self->_match_title_line( $token, FeatureLine => $self->dialect->Feature );
}

sub match_RuleLine {
    my ( $self, $token ) = @_;
    $self->_match_title_line( $token,
        RuleLine => $self->dialect->Rule );
}

sub match_ScenarioLine {
    my ( $self, $token ) = @_;
    $self->_match_title_line(
        $token,
        ScenarioLine => $self->dialect->Scenario )
        or $self->_match_title_line(
            $token,
            ScenarioLine => $self->dialect->ScenarioOutline );
}

sub match_BackgroundLine {
    my ( $self, $token ) = @_;
    $self->_match_title_line( $token,
        BackgroundLine => $self->dialect->Background );
}

sub match_ExamplesLine {
    my ( $self, $token ) = @_;
    $self->_match_title_line( $token,
        ExamplesLine => $self->dialect->Examples );
}

sub match_Language {
    my ( $self, $token ) = @_;
    if ( $token->line and $token->line->get_line_text =~ $LANGUAGE_RE ) {
        my $dialect_name = $1;
        $self->_set_token_matched( $token,
                                   Language => { text => $dialect_name } );
        local $@;
        eval { $self->change_dialect( $dialect_name, $token->location ) };
        return (1, $@);
    } else {
        return;
    }
}

sub match_TagLine {
    my ( $self, $token ) = @_;
    return unless $token->line and $token->line->startswith('@');

    my ($tags, $err) = $token->line->tags;
    $self->_set_token_matched( $token,
                               TagLine => { items => $tags } );
    return (1, $err);
}

sub _match_title_line {
    my ( $self, $token, $token_type, $keywords ) = @_;
    return unless $token->line;

    for my $keyword (@{$keywords}) {
        if ( $token->line->startswith_title_keyword($keyword) ) {
            my $title =
              $token->line->get_rest_trimmed( length( $keyword . ': ' ) );
            $self->_set_token_matched( $token, $token_type,
                { text => $title, keyword => $keyword } );
            return 1;
        }
    }

    return;
}

sub _set_token_matched {
    my ( $self, $token, $matched_type, $options ) = @_;
    $options->{'items'} ||= [];
    $token->matched_type($matched_type);

    if ( defined $options->{'text'} ) {
        chomp( $options->{'text'} );
        $token->matched_text( $options->{'text'} );
    }

    $token->matched_keyword( $options->{'keyword'} )
      if defined $options->{'keyword'};
    $token->matched_keyword_type( $options->{'keyword_type'} )
      if defined $options->{'keyword_type'};

    if ( defined $options->{'indent'} ) {
        $token->matched_indent( $options->{'indent'} );
    } else {
        $token->matched_indent( $token->line ? $token->line->indent : 0 );
    }

    $token->matched_items( $options->{'items'} )
      if defined $options->{'items'};

    $token->location->{'column'} = $token->matched_indent + 1;
    $token->matched_gherkin_dialect( $self->dialect_name );
}

sub match_EOF {
    my ( $self, $token ) = @_;
    return unless $token->is_eof;
    $self->_set_token_matched( $token, 'EOF' );
    return 1;
}

sub match_Empty {
    my ( $self, $token ) = @_;
    return unless $token->line and $token->line->is_empty;
    $self->_set_token_matched( $token, Empty => { indent => 0 } );
    return 1;
}

sub match_Comment {
    my ( $self, $token ) = @_;
    return unless $token->line and $token->line->startswith('#');

    my $comment_text = $token->line->line_text;
    $comment_text =~ s/\r\n$//;    # Why?

    $self->_set_token_matched( $token,
        Comment => { text => $comment_text, indent => 0 } );
    return 1;
}

sub match_Other {
    my ( $self, $token ) = @_;
    return unless $token->line;

    # take the entire line, except removing DocString indents
    my $text = $token->line->get_line_text( $self->_indent_to_remove );
    $self->_set_token_matched( $token,
        Other => { indent => 0, text => $self->_unescaped_docstring($text) } );
    return 1;
}

sub _unescaped_docstring {
    my ( $self, $text ) = @_;
    if ( $self->_active_doc_string_separator ) {
        $text =~ s!\\"\\"\\"!"""!;
        $text =~ s!\\`\\`\\`!```!;
        return $text;
    } else {
        return $text;
    }
}

sub match_StepLine {
    my ( $self, $token ) = @_;
    my @keywords = @{ $self->_sorted_step_keywords };
    my $line = $token->line;

    for my $keyword (@keywords) {
        if ( $line->startswith($keyword) ) {
            my $title = $line->get_rest_trimmed( length($keyword) );
            my $keyword_type =
                (scalar @{$self->_keyword_types->{$keyword}} > 1)
                ? Cucumber::Messages::Step::KEYWORDTYPE_UNKNOWN
                : $self->_keyword_types->{$keyword}->[0];
            $self->_set_token_matched(
                $token,
                StepLine => {
                    text => $title,
                    keyword => $keyword,
                    keyword_type => $keyword_type,
                } );
            return 1;
        }
    }
    return;
}

sub match_DocStringSeparator {
    my ( $self, $token ) = @_;
    if ($token->is_eof) {
        return 0;
    }
    if ( !$self->_active_doc_string_separator ) {
        return $self->_match_DocStringSeparator( $token, '"""', 1 )
          || $self->_match_DocStringSeparator( $token, '```', 1 );
    } else {
        return $self->_match_DocStringSeparator( $token,
            $self->_active_doc_string_separator, 0 );
    }
}

sub _match_DocStringSeparator {
    my ( $self, $token, $separator, $is_open ) = @_;
    return unless $token->line->startswith($separator);

    my $content_type;
    if ($is_open) {
        $content_type = $token->line->get_rest_trimmed( length($separator) );
        $self->_active_doc_string_separator($separator);
        $self->_indent_to_remove( $token->line->indent );
    } else {
        $self->_active_doc_string_separator(undef);
        $self->_indent_to_remove(0);
    }

    $self->_set_token_matched( $token,
        DocStringSeparator => { text => $content_type, keyword => $separator } );
}

sub match_TableRow {
    my ( $self, $token ) = @_;
    return unless $token->line->startswith('|');

    $self->_set_token_matched( $token,
        TableRow => { items => $token->line->table_cells } );
}

1;


__END__


=head1 NAME

Gherkin::TokenMatcher - Line token matching for the Gherkin parser

=head1 SYNOPSIS

  use Gherkin::TokenMatcher;
  use Gherkin::Dialect;

  # Instantiate a token matcher with the default language 'Emoji'
  my $matcher = Gherkin::TokenMatcher->new( {
        dialect => Gherkin::Dialect->new( { dialect => 'em'} )
  } );

=head1 DESCRIPTION

The Gherkin language has a line-based structure. The parser knows about state,
but defers identifying the type of line tokens to the token matcher. The
matcher knows how to identify line tokens based on the grammar's keywords.
Although the matcher knows how to identify line tokens based on the keywords,
it depends on L<Gherkin::Dialect> to provide the actual keyword texts.

=head1 METHODS

=head2 new( [$options] )

Constructor.

C<$options> is a hashref with the following keys:

=over

=item C<dialect>

An instance of L<Gherkin::Dialect> to provide the keyword texts used to identify
the type of line-token being matched.

=back

=head2 dialect_name

Returns the name of the current dialect selected from the C<dialect> instance.

=head2 change_dialect

Changes the selected dialect on the C<dialect> instance. Dialects are groups of
keywords belonging together; this is how keyword translations are being handled.

=head2 reset

Changes the token scanner's state back to its initial state; used to restart
scanning a document. Multiple documents may be parsed using a single token
scanner with a C<reset> call in-between.

=head1 SEE ALSO

=over 8

=item * L<Gherkin>

=item * L<Gherkin::Dialect>

=item * L<Gherkin::MarkdownTokenMatcher>

=item * L<Gherkin::Parser>

=back

=head1 LICENSE

See L<Gherkin>.

=cut
