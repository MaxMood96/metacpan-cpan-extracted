package License::SPDX;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Cpanel::JSON::XS;
use Error::Pure qw(err);
use File::Share ':all';
use List::Util qw(first);
use Perl6::Slurp qw(slurp);

our $VERSION = 0.06;

# Constructor.
sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# Process parameters.
	set_params($self, @params);

	# Load all SPDX licenses.
	open my $data_fh, '<', dist_dir('License-SPDX').'/licenses.json';
	my $data = slurp($data_fh);
	$self->{'licenses'} = Cpanel::JSON::XS->new->ascii->pretty->allow_nonref->decode($data);

	# Load all SPDX exceptions.
	open my $data_exc_fh, '<', dist_dir('License-SPDX').'/exceptions.json';
	my $data_exc = slurp($data_exc_fh);
	$self->{'exceptions'} = Cpanel::JSON::XS->new->ascii->pretty->allow_nonref->decode($data_exc);

	return $self;
}

sub check_exception {
	my ($self, $check_string, $opts_hr) = @_;

	if (! defined $opts_hr) {
		$opts_hr = {};
	}
	if (! exists $opts_hr->{'check_type'}) {
		$opts_hr->{'check_type'} = 'id';
	}

	my $check_cb = sub {
		my $exception_hr = shift;
		if ($opts_hr->{'check_type'} eq 'id') {
			if ($check_string eq $exception_hr->{'licenseExceptionId'}) {
				return 1;
			}
		} elsif ($opts_hr->{'check_type'} eq 'name') {
			if ($check_string eq $exception_hr->{'name'}) {
				return 1;
			}
		} else {
			err "Check type '$opts_hr->{'check_type'}' doesn't supported.";
		}
	};

	if (first { $check_cb->($_); } @{$self->{'exceptions'}->{'exceptions'}}) {
		return 1;
	} else {
		return 0;
	}
}

sub check_license {
	my ($self, $check_string, $opts_hr) = @_;

	if (! defined $opts_hr) {
		$opts_hr = {};
	}
	if (! exists $opts_hr->{'check_type'}) {
		$opts_hr->{'check_type'} = 'id';
	}

	my $check_cb = sub {
		my $license_hr = shift;
		if ($opts_hr->{'check_type'} eq 'id') {
			if ($check_string eq $license_hr->{'licenseId'}) {
				return 1;
			}
		} elsif ($opts_hr->{'check_type'} eq 'name') {
			if ($check_string eq $license_hr->{'name'}) {
				return 1;
			}
		} else {
			err "Check type '$opts_hr->{'check_type'}' doesn't supported.";
		}
	};

	if (first { $check_cb->($_); } @{$self->{'licenses'}->{'licenses'}}) {
		return 1;
	} else {
		return 0;
	}
}

sub exception {
	my ($self, $exception_id) = @_;

	return first { $_->{'licenseExceptionId'} eq $exception_id } @{$self->{'exceptions'}->{'exceptions'}};
}

sub exceptions {
	my $self = shift;

	return @{$self->{'exceptions'}->{'exceptions'}};
}

sub license {
	my ($self, $license_id) = @_;

	return first { $_->{'licenseId'} eq $license_id } @{$self->{'licenses'}->{'licenses'}};
}

sub licenses {
	my $self = shift;

	return @{$self->{'licenses'}->{'licenses'}};
}

sub spdx_release_date {
	my $self = shift;

	return $self->{'licenses'}->{'releaseDate'};
}

sub spdx_version {
	my $self = shift;

	return $self->{'licenses'}->{'licenseListVersion'};
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

License::SPDX - Object for SPDX licenses handling.

=head1 SYNOPSIS

 use License::SPDX;

 my $obj = License::SPDX->new;
 my $checked = $obj->check_exception($check_string, $opts_hr);
 my $checked = $obj->check_license($check_string, $opts_hr);
 my $exception_hr = $obj->exception($exception_id);
 my @exceptions = $obj->exceptions;
 my $license_hr = $obj->license($license_id);
 my @licenses = $obj->licenses;
 my $spdx_release_date = $obj->spdx_release_date;
 my $spdx_version = $obj->spdx_version;

=head1 DESCRIPTION

Object for SPDX licenses handling is using license data from L<https://github.com/spdx/license-list-data> repository.
Actual version is 3.21.

=head1 METHODS

=head2 C<new>

 my $obj = License::SPDX->new;

Constructor.

Returns instance of object.

=head2 C<check_exception>

 my $checked = $obj->check_exception($check_string, $opts_hr);

Check if license exception exists.
Argument C<$opts_hr> is reference to hash with parameter 'check_type' for
definition of C<check_exception()> type.

Possible 'check_type' values:

 'id' - Check license exception id.
 'name' - Check license exception name.

Default value of 'check_type' is 'id'.
If 'check_type' is bad, fail with error.

Returns 1 (license exist) or 0 (license doesn't exist).

=head2 C<check_license>

 my $checked = $obj->check_license($check_string, $opts_hr);

Check if license exists.
Argument C<$opts_hr> is reference to hash with parameter 'check_type' for
definition of C<check_license()> type.

Possible 'check_type' values:

 'id' - Check license id.
 'name' - Check license name.

Default value of 'check_type' is 'id'.
If 'check_type' is bad, fail with error.

Returns 1 (license exist) or 0 (license doesn't exist).

=head2 C<exception>

 my $exception_hr = $obj->exception($exception_id);

Get license exception structure.

Returns reference to hash.

=head2 C<exceptions>

 my @exceptions = $obj->exceptions;

Get all license exception structures.

Returns array of references to hash.

=head2 C<license>

 my $license_hr = $obj->license($license_id);

Get license structure.

Returns reference to hash.

=head2 C<licenses>

 my @licenses = $obj->licenses;

Get all license structures.

Returns array of references to hash.

=head2 C<spdx_release_date>

 my $spdx_release_date = $obj->spdx_release_date;

Get release date of data structure with SPDX license.

Returns string.

=head2 C<spdx_version>

 my $spdx_version = $obj->spdx_version;

Get version of data structure with SPDX license.

Returns string.

=head1 ERRORS

 new():
         From Class::Utils::set_params():
                 Unknown parameter '%s'.

 check_exception():
         Check type '%s' doesn't supported.

 check_license():
         Check type '%s' doesn't supported.

=head1 EXAMPLE1

=for comment filename=check_license_id.pl

 use strict;
 use warnings;

 use License::SPDX;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 license_id\n";
         exit 1;
 }
 my $license_id = $ARGV[0];

 # Object.
 my $obj = License::SPDX->new;

 print 'License with id \''.$license_id.'\' is ';
 if ($obj->check_license($license_id)) {
         print "supported.\n";
 } else {
         print "not supported.\n";
 }

 # Output for 'MIT':
 # License with id 'MIT' is supported.

 # Output for 'BAD':
 # License with id 'BAD' is not supported.

=head1 EXAMPLE2

=for comment filename=check_license_exception_id.pl

 use strict;
 use warnings;

 use License::SPDX;

 if (@ARGV < 1) {
         print STDERR "Usage: $0 license_exception_id\n";
         exit 1;
 }
 my $license_exception_id = $ARGV[0];

 # Object.
 my $obj = License::SPDX->new;

 print 'License exception with id \''.$license_exception_id.'\' is ';
 if ($obj->check_exception($license_exception_id)) {
         print "supported.\n";
 } else {
         print "not supported.\n";
 }

 # Output for 'LGPL-3.0-linking-exception':
 # License exception with id 'LGPL-3.0-linking-exception' is supported.

 # Output for 'BAD':
 # License exception with id 'BAD' is not supported.

=head1 DEPENDENCIES

L<Class::Utils>,
L<Cpanel::JSON::XS>,
L<Error::Pure>.
L<File::Share>,
L<List::Util>,
L<Perl6::Slurp>.

=head1 SEE ALSO

=over

=item L<rpm-spec-license>

Tool for working with RPM spec file licenses.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/License-SPDX>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© 2023 Michal Josef Špaček

BSD 2-Clause License

=head1 VERSION

0.06

=cut
