use strict;
use warnings;

package Maven::Xml::Pom::DependencyManagement;
$Maven::Xml::Pom::DependencyManagement::VERSION = '1.15';
# ABSTRACT: Maven DependencyManagement element
# PODNAME: Maven::Xml::Pom::DependencyManagement

use Maven::Xml::Pom::Dependencies;

use parent qw(Maven::Xml::XmlNodeParser);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(
    qw(
        dependencies
        )
);

sub _get_parser {
    my ( $self, $name ) = @_;
    if ( $name eq 'dependencies' ) {
        return Maven::Xml::Pom::Dependencies->new();
    }
    return $self->Maven::Xml::XmlNodeParser::_get_parser($name);
}

1;

__END__

=pod

=head1 NAME

Maven::Xml::Pom::DependencyManagement - Maven DependencyManagement element

=head1 VERSION

version 1.15

=head1 AUTHOR

Lucas Theisen <lucastheisen@pastdev.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Lucas Theisen.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<Maven::Agent|Maven::Agent>

=back

=cut
