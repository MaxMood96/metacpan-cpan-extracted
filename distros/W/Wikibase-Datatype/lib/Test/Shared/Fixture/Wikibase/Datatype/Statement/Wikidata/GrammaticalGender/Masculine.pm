package Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine;

use base qw(Wikibase::Datatype::Statement);
use strict;
use warnings;

use Test::Shared::Fixture::Wikibase::Datatype::Reference::Wikidata::VIAF;
use Test::Shared::Fixture::Wikibase::Datatype::Snak::Wikidata::GrammaticalGender::Masculine;

our $VERSION = 0.37;

sub new {
	my $class = shift;

	my @params = (
		'snak' => Test::Shared::Fixture::Wikibase::Datatype::Snak::Wikidata::GrammaticalGender::Masculine->new,
		'references' => [
			Test::Shared::Fixture::Wikibase::Datatype::Reference::Wikidata::VIAF->new,
		],
	);

	my $self = $class->SUPER::new(@params);

	return $self;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine - Test instance for Wikidata statement.

=head1 SYNOPSIS

 use Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine;

 my $obj = Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine->new(%params);
 my $id = $obj->id;
 my $property_snaks_ar = $obj->property_snaks;
 my $rank = $obj->rank;
 my $referenes_ar = $obj->references;
 my $snak = $obj->snak;

=head1 METHODS

=head2 C<new>

 my $obj = Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine->new(%params);

Constructor.

Returns instance of object.

=head2 C<id>

 my $id = $obj->id;

Get id of statement.

Returns string.

=head2 C<property_snaks>

 my $property_snaks_ar = $obj->property_snaks;

Get property snaks.

Returns reference to array with Wikibase::Datatype::Snak instances.

=head2 C<rank>

 my $rank = $obj->rank;

Get rank value.

=head2 C<references>

 my $referenes_ar = $obj->references;

Get references.

Returns reference to array with Wikibase::Datatype::Reference instance.

=head2 C<snak>

 my $snak = $obj->snak;

Get main snak.

Returns Wikibase::Datatype::Snak instance.

=head1 EXAMPLE

=for comment filename=fixture_create_and_print_statement_wd_grammatical_gender_masculine.pl

 use strict;
 use warnings;

 use Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine;
 use Wikibase::Datatype::Print::Statement;

 # Object.
 my $obj = Test::Shared::Fixture::Wikibase::Datatype::Statement::Wikidata::GrammaticalGender::Masculine->new;

 # Print out.
 print scalar Wikibase::Datatype::Print::Statement::print($obj);

 # Output:
 # P5185: Q499327 (normal)
 # References:
 #   {
 #     P248: Q53919
 #     P214: 113230702
 #     P813: 7 December 2013 (Q1985727)
 #   }

=head1 DEPENDENCIES

L<Test::Shared::Fixture::Wikibase::Datatype::Reference::Wikidata::VIAF>,
L<Test::Shared::Fixture::Wikibase::Datatype::Snak::Wikidata::GrammaticalGender::Masculine>,
L<Wikibase::Datatype::Statement>.

=head1 SEE ALSO

=over

=item L<Wikibase::Datatype>

Wikibase datatypes.

=item L<Wikibase::Datatype::Statement>

Wikibase statement datatype.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Wikibase-Datatype>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2020-2025 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.37

=cut
