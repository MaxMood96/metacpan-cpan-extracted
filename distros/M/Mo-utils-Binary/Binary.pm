package Mo::utils::Binary;

use base qw(Exporter);
use strict;
use warnings;

use Error::Pure qw(err);
use Readonly;

Readonly::Array our @EXPORT_OK => qw(check_bytes_len);

our $VERSION = 0.01;

sub check_bytes_len {
	my ($self, $key, $length) = @_;

	_check_key($self, $key) && return;

	use bytes;
	if (length($self->{$key}) > $length) {
		err "Parameter '".$key."' has bad bytes length.",
			'Value', $self->{$key},
			'Expected bytes length', $length,
			'Real bytes length', length($self->{$key}),
		;
	}

	return;
}

sub _check_key {
	my ($self, $key) = @_;

	if (! exists $self->{$key} || ! defined $self->{$key}) {
		return 1;
	}

	return 0;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Mo::utils::Binary - Mo utilities for binary data.

=head1 SYNOPSIS

 use Mo::utils::Binary qw(check_bytes_len);

 check_bytes_len($self, $key, $length);

=head1 DESCRIPTION

Mo utilities for checking of binary data.

=head1 SUBROUTINES

=head2 C<check_bytes_len>

 check_bytes_len($self, $key, $count);

Check parameter defined by C<$key> which is in bytes length.

Put error if check isn't ok.

Returns undef.

=head1 ERRORS

 check_bytes_len():
         Parameter '%s' has bad bytes length.
                 Value: %s
                 Expected bytes length: %s
                 Real bytes length: %s

=head1 EXAMPLE1

=for comment filename=check_bytes_len_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Binary qw(check_bytes_len);

 my $self = {
         'key' => 'foo',
 };
 check_bytes_len($self, 'key', 3);

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE2

=for comment filename=check_bytes_len_fail.pl

 use strict;
 use utf8;
 use warnings;

 use Error::Pure;
 use Mo::utils::Binary qw(check_bytes_len);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => '森林',
 };
 check_bytes_len($self, 'key', 3);

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [..Binary.pm:?] Parameter 'key' has bad bytes length.

=head1 DEPENDENCIES

L<Exporter>,
L<Error::Pure>,
L<Readonly>.

=head1 SEE ALSO

=over

=item L<Mo>

Micro Objects. Mo is less.

=item L<Mo::utils::Array>

Mo array utilities.

=item L<Mo::utils::Language>

Mo language utilities.

=item L<Mo::utils::CSS>

Mo CSS utilities.

=item L<Wikibase::Datatype::Utils>

Wikibase datatype utilities.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Mo-utils-Binary>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
