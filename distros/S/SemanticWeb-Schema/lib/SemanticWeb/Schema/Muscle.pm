use utf8;

package SemanticWeb::Schema::Muscle;

# ABSTRACT: A muscle is an anatomical structure consisting of a contractile form of tissue that animals use to effect movement.

use Moo;

extends qw/ SemanticWeb::Schema::AnatomicalStructure /;


use MooX::JSON_LD 'Muscle';
use Ref::Util qw/ is_plain_hashref /;
# RECOMMEND PREREQ: Ref::Util::XS

use namespace::autoclean;

our $VERSION = 'v9.0.0';


has antagonist => (
    is        => 'rw',
    predicate => '_has_antagonist',
    json_ld   => 'antagonist',
);



has blood_supply => (
    is        => 'rw',
    predicate => '_has_blood_supply',
    json_ld   => 'bloodSupply',
);



has insertion => (
    is        => 'rw',
    predicate => '_has_insertion',
    json_ld   => 'insertion',
);



has muscle_action => (
    is        => 'rw',
    predicate => '_has_muscle_action',
    json_ld   => 'muscleAction',
);



has nerve => (
    is        => 'rw',
    predicate => '_has_nerve',
    json_ld   => 'nerve',
);





1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SemanticWeb::Schema::Muscle - A muscle is an anatomical structure consisting of a contractile form of tissue that animals use to effect movement.

=head1 VERSION

version v9.0.0

=head1 DESCRIPTION

A muscle is an anatomical structure consisting of a contractile form of
tissue that animals use to effect movement.

=head1 ATTRIBUTES

=head2 C<antagonist>

The muscle whose action counteracts the specified muscle.

A antagonist should be one of the following types:

=over

=item C<InstanceOf['SemanticWeb::Schema::Muscle']>

=back

=head2 C<_has_antagonist>

A predicate for the L</antagonist> attribute.

=head2 C<blood_supply>

C<bloodSupply>

The blood vessel that carries blood from the heart to the muscle.

A blood_supply should be one of the following types:

=over

=item C<InstanceOf['SemanticWeb::Schema::Vessel']>

=back

=head2 C<_has_blood_supply>

A predicate for the L</blood_supply> attribute.

=head2 C<insertion>

The place of attachment of a muscle, or what the muscle moves.

A insertion should be one of the following types:

=over

=item C<InstanceOf['SemanticWeb::Schema::AnatomicalStructure']>

=back

=head2 C<_has_insertion>

A predicate for the L</insertion> attribute.

=head2 C<muscle_action>

C<muscleAction>

The movement the muscle generates.

A muscle_action should be one of the following types:

=over

=item C<Str>

=back

=head2 C<_has_muscle_action>

A predicate for the L</muscle_action> attribute.

=head2 C<nerve>

The underlying innervation associated with the muscle.

A nerve should be one of the following types:

=over

=item C<InstanceOf['SemanticWeb::Schema::Nerve']>

=back

=head2 C<_has_nerve>

A predicate for the L</nerve> attribute.

=head1 SEE ALSO

L<SemanticWeb::Schema::AnatomicalStructure>

=head1 SOURCE

The development version is on github at L<https://github.com/robrwo/SemanticWeb-Schema>
and may be cloned from L<git://github.com/robrwo/SemanticWeb-Schema.git>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/robrwo/SemanticWeb-Schema/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Robert Rothenberg <rrwo@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018-2020 by Robert Rothenberg.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
