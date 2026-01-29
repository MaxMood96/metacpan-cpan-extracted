package Jinja2::TT2;

use strict;
use warnings;
use v5.20;

use Jinja2::TT2::Tokenizer;
use Jinja2::TT2::Parser;
use Jinja2::TT2::Emitter;

our $VERSION = '0.01';

sub new {
    my ($class, %opts) = @_;
    return bless {
        tokenizer => Jinja2::TT2::Tokenizer->new(),
        parser    => Jinja2::TT2::Parser->new(),
        emitter   => Jinja2::TT2::Emitter->new(%opts),
        debug     => $opts{debug} // 0,
    }, $class;
}

sub transpile {
    my ($self, $template) = @_;

    # Step 1: Tokenize
    my @tokens = $self->{tokenizer}->tokenize($template);

    if ($self->{debug}) {
        say STDERR "=== TOKENS ===";
        for my $tok (@tokens) {
            say STDERR "  [$tok->{type}] '$tok->{value}'";
        }
    }

    # Step 2: Parse into AST
    my $ast = $self->{parser}->parse(\@tokens);

    if ($self->{debug}) {
        require Data::Dumper;
        say STDERR "=== AST ===";
        say STDERR Data::Dumper::Dumper($ast);
    }

    # Step 3: Emit TT2
    return $self->{emitter}->emit($ast);
}

sub transpile_file {
    my ($self, $filename) = @_;

    open my $fh, '<:encoding(UTF-8)', $filename
        or die "Cannot open '$filename': $!";
    my $template = do { local $/; <$fh> };
    close $fh;

    return $self->transpile($template);
}

1;

__END__

=head1 NAME

Jinja2::TT2 - Transpile Jinja2 templates to Template Toolkit (TT2)

=head1 SYNOPSIS

    use Jinja2::TT2;

    my $transpiler = Jinja2::TT2->new();
    my $tt2_output = $transpiler->transpile($jinja2_template);

    # Or from a file
    my $tt2_output = $transpiler->transpile_file('template.j2');

=head1 DESCRIPTION

This module converts Jinja2 template syntax to Template Toolkit 2 (TT2) syntax.
It performs a mechanical translation, mapping Jinja2 constructs to their TT2
equivalents.

=head1 METHODS

=head2 new(%options)

Create a new transpiler instance.

Options:
    debug => 1   # Print tokenizer and parser debug output

=head2 transpile($template_string)

Transpile a Jinja2 template string to TT2.

=head2 transpile_file($filename)

Read a file and transpile its contents.

=head1 SUPPORTED CONSTRUCTS

=over 4

=item * Variables: C<{{ foo.bar }}> → C<[% foo.bar %]>

=item * Filters: C<{{ name|upper }}> → C<[% name | upper %]>

=item * Conditionals: C<{% if %}> → C<[% IF %]>

=item * Loops: C<{% for x in items %}> → C<[% FOREACH x IN items %]>

=item * Blocks: C<{% block name %}> → C<[% BLOCK name %]>

=item * Includes: C<{% include 'file' %}> → C<[% INCLUDE file %]>

=item * Comments: C<{# comment #}> → C<[%# comment %]>

=back

=head1 AUTHOR

Generated with Claude Code

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
