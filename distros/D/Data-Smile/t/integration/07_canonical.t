=pod

=encoding utf-8

=head1 PURPOSE

Test canonical key ordering for C<encode_smile>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2026 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
same terms as Perl 5 itself.

=cut

use Test2::V0;
use Test2::Plugin::BailOnFail;

use Data::Smile::PP ();

my $in = {
	zeta  => 1,
	alpha => 2,
	beta  => 3,
};

my $canonical = Data::Smile::PP::encode_smile(
	$in,
	{ canonical => 1, write_header => 0, shared_names => 0, shared_values => 0 },
);

my $redecoded = Data::Smile::PP::decode_smile(
	$canonical,
	{ require_header => 0 },
);

is(
	$redecoded,
	$in,
	'canonical output decodes to original hash',
);

my @canonical_order = ( $canonical =~ /(alpha|beta|zeta)/g );

is(
	\@canonical_order,
	[ qw( alpha beta zeta ) ],
	'canonical encoding emits sorted hash keys',
);

done_testing;
