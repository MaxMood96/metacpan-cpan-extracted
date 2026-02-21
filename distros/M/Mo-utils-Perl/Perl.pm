package Mo::utils::Perl;

use base qw(Exporter);
use strict;
use version 0.77;
use warnings;

use English;
use Error::Pure qw(err);
use Readonly;

Readonly::Array our @EXPORT_OK => qw(check_version);

our $VERSION = 0.01;

sub check_version {
	my ($self, $key) = @_;

	_check_key($self, $key) && return;

	eval {
		version->parse($self->{$key});
	};
	if ($EVAL_ERROR) {
		err "Parameter '$key' isn't right Perl version.",
			'Value', $self->{$key},
			'Error', $EVAL_ERROR,
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

Mo::utils::Perl - Mo Perl utilities.

=head1 SYNOPSIS

 use Mo::utils::Perl qw(check_version);

 check_version($self, $key);

=head1 DESCRIPTION

Utilities for checking of Perl related values.

=head1 SUBROUTINES

=head2 C<check_version>

 check_version($self, $key);

I<Since version 0.01.>

Check parameter defined by C<$key> which is right Perl version defined in
L<version>.

Put error if check isn't ok.

Returns undef.

=head1 ERRORS

 check_version():
         Parameter '%s' isn't right Perl version.
                 Error: %s
                 Value: %s


=head1 EXAMPLE1

=for comment filename=check_version_ok.pl

 use strict;
 use warnings;

 use Mo::utils::Perl qw(check_version);

 my $self = {
         'key' => '0.01',
 };
 check_version($self, 'key');

 # Print out.
 print "ok\n";

 # Output:
 # ok

=head1 EXAMPLE2

=for comment filename=check_version_fail.pl

 use strict;
 use warnings;

 use Error::Pure;
 use Mo::utils::Perl qw(check_version);

 $Error::Pure::TYPE = 'Error';

 my $self = {
         'key' => 'bad',
 };
 check_version($self, 'key');

 # Print out.
 print "ok\n";

 # Output like:
 # #Error [..Perl.pm:?] Parameter 'key' isn't right Perl version.

=head1 DEPENDENCIES

L<English>,
L<Exporter>,
L<Error::Pure>,
L<Readonly>,
L<version>.

=head1 SEE ALSO

=over

=item L<Mo::utils>

Mo utilities.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Mo-utils-Perl>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2026 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.01

=cut
