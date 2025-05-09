package Wikibase::Datatype::Print::Sitelink;

use base qw(Exporter);
use strict;
use warnings;

use Error::Pure qw(err);
use Readonly;
use Wikibase::Datatype::Print::Value::Item;

Readonly::Array our @EXPORT_OK => qw(print);

our $VERSION = 0.18;

sub print {
	my ($obj, $opts_hr) = @_;

	if (! $obj->isa('Wikibase::Datatype::Sitelink')) {
		err "Object isn't 'Wikibase::Datatype::Sitelink'.";
	}

	my $ret = '';
	if (defined $obj->title) {
		$ret .= $obj->title;
	}
	if (defined $obj->site) {
		$ret .= ' ('.$obj->site.')';
	}
	if (@{$obj->badges}) {
		my @print = map { Wikibase::Datatype::Print::Value::Item::print($_, $opts_hr) } @{$obj->badges};
		$ret .= ' ['.(join ' ', @print).']';
	}

	return $ret;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Wikibase::Datatype::Print::Sitelink - Wikibase sitelink pretty print helpers.

=head1 SYNOPSIS

 use Wikibase::Datatype::Print::Sitelink qw(print);

 my $pretty_print_string = print($obj, $opts_hr);
 my @pretty_print_lines = print($obj, $opts_hr);

=head1 SUBROUTINES

=head2 C<print>

 my $pretty_print_string = print($obj, $opts_hr);
 my @pretty_print_lines = print($obj, $opts_hr);

Construct pretty print output for L<Wikibase::Datatype::Sitelink>
object.

Returns string in scalar context.
Returns list of lines in array context.

=head1 ERRORS

 print():
         Object isn't 'Wikibase::Datatype::Sitelink'.

=head1 EXAMPLE

=for comment filename=create_and_print_sitelink.pl

 use strict;
 use warnings;

 use Unicode::UTF8 qw(decode_utf8 encode_utf8);
 use Wikibase::Datatype::Print::Sitelink;
 use Wikibase::Datatype::Sitelink;

 # Object.
 my $obj = Wikibase::Datatype::Sitelink->new(
         'badges' => [
                 Wikibase::Datatype::Value::Item->new(
                         'value' => 'Q123',
                 ),
         ],
         'site' => 'cswiki',
         'title' => decode_utf8('Hlavní strana'),
 );

 # Print.
 print encode_utf8(Wikibase::Datatype::Print::Sitelink::print($obj))."\n";

 # Output:
 # Hlavní strana (cswiki) [Q123]

=head1 DEPENDENCIES

L<Error::Pure>,
L<Exporter>,
L<Readonly>,
L<Wikibase::Datatype::Print::Value::Item>.

=head1 SEE ALSO

=over

=item L<Wikibase::Datatype::Sitelink>

Wikibase sitelink datatype.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Wikibase-Datatype-Print>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2020-2025 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.18

=cut
