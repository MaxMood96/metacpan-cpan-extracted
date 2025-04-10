#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Role::HelpAsText 2.155;

# ABSTRACT: Translate element help from pod to text

use Mouse::Role;
use strict;
use warnings;
use Pod::Text;
use Pod::Simple 3.23;
use v5.20;

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

requires('get_help');

sub get_help_as_text ($self, @args) {
    my $pod = $self->get_help(@args) ;
    return unless defined $pod;

    my $parser = Pod::Text->new(
        indent => 0,
        nourls => 1,
    );

    # require Pod::Simple 3.23
    $parser->parse_characters('utf8');

    my $output = '';
    $parser->output_string(\$output);

    $parser->parse_string_document("=pod\n\n" . $pod);
    $output =~ s/[\n\s]+$//;

    return $output;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Role::HelpAsText - Translate element help from pod to text

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 $self->get_help_as_text( ... );

=head1 DESCRIPTION

Role used to transform Config::Model help text or description from pod
to text. The provided method should be used when the help text should
be displayed on STDOUT.

This functionality is provided as a role because the interface to
L<Pod::Text> is not so easy.

=head1 METHODS

=head2 get_help_as_text

Calls C<get_help> and transform the Pod output to text.

=head2 SEE ALSO

L<Pod::Text>, L<Pod::Simple>

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
