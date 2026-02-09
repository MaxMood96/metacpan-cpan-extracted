package DPKG::Packages::Parser;

use v5.40;
use feature 'class';
no warnings 'experimental::class';

use Clone qw(clone);
use Carp qw(croak);

our $VERSION = '0.01';

class DPKG::Packages::Parser {
	field $file :param :reader = 'Packages';

	field %entries = ();

	method parse(@fields) {
		if(-r $file) {
			$self->_parse_from_file(@fields);
			return 1;
		} else {
			croak("DPKG::Packages::Parser - $file is not a readable file");
		}
	}

	method _parse_from_file(@fields) {
		if(@fields) {
			unshift @fields, 'Package' if ! grep { 'Packages' eq $_ } @fields;
		}
		open(my $f, '<', $file) or die "Cannot read $file\n";
		my %entry = ();
		my $last_key = ''; # 'Tag' is multi-line, I don't know why...
		while(<$f>) {
			chomp;
			if(!$_) {
				# Tags need to be parsed
				my @array_fields = qw(Tag Depends Pre-Depends Replaces Provides Breaks Enhances Conflicts Recommends Suggests);
				foreach(@array_fields) {
					if(defined($entry{$_})) {
						my @temp = split ', ', $entry{$_};
						$entry{$_} = \@temp;
					}
				}
				my @version_fields = qw(Depends Pre-Depends Replaces Provides Breaks Enhances Conflicts Recommends Suggests);
				foreach(@version_fields) {
					if(defined($entry{$_})) {
						my @new_entries = ();
						foreach(@{$entry{$_}}) {
							if(/ \| /) {
								my @a = ();
								foreach(split(/ \| /, $_)) {
									my $pkg = $self->_parse_package_str($_);
									push @a, $pkg;
								}
								push @new_entries, \@a;
							} else {
								push @new_entries, $self->_parse_package_str($_);
							}
						}
						$entry{$_} = \@new_entries;
					}
				}
				$entries{$entry{Package}} = clone(\%entry);
				%entry = ();
			} else {
				if(!/^\s+/) {
					my ($key, $val) = split(': ', $_, 2);
					if((@fields && grep { $key eq $_ } @fields) || !@fields) {
						$entry{$last_key = $key} = $val;
					} else {
						$last_key = $key;
					}
				} else {
					if((@fields && grep { $last_key eq $_ } @fields) || !@fields) {
						$entry{$last_key} .= $_;
					}
				}
			}
		}
		close($f);
	}

	method _parse_package_str($s) {
		$_ = $s;
		if(/^([\w\-\+\.\:]+) \((\S+) (\S+)\)/) {
			my ($name, $arch) = $self->_parse_package_name($1);
			my %e = (name => $name, op => $2, version => $3, arch => $arch);
			return \%e;
		} elsif(/^([\w\-\+\.\:]+):any/) {
			my ($name, $arch) = $self->_parse_package_name($1);
			my %e = (name => $name, op => undef, version => 'any', arch => $arch);
			return \%e;
		} elsif(/^([\w\-\+\.\:]+)$/) {
			my ($name, $arch) = $self->_parse_package_name($1);
			my %e = (name => $name, op => undef, version => undef, arch => $arch);
			return \%e;
		} else {
			say "i don't know: $_";
			my %e = (name => $_, op => undef, version => undef, arch => undef);
			return \%e;
		}
	}

	method _parse_package_name($name) {
		return split(':', $name);
	}

	method get_package($name) {
		if(defined($entries{$name})) {
			return $entries{$name};
		} else {
			return undef;
		}
	}
}

1;
__END__

=encoding utf-8

=head1 NAME

DPKG::Packages::Parser - Parses the Debian Packages file.

=head1 SYNOPSIS

  use v5.40;
  use DPKG::Packages::Parser;
  #
  my $p = DPKG::Packages::Parser->new(file => "Packages");
  $p->parse(); # Parse all fields
  my $package = $p->get_package('perl');
  say $package->{Description};
  #
  # If you only need one or several fields, you can pass an array of field names.
  # This is significantly faster.
  $p->parse('Filename'); # We're only interested in the Filename of each package.
  my $libperl_pkg = $p->get_package('libperl5.36');
  say $libperl_pkg->{Filename};

=head1 DESCRIPTION

DPKG::Packages::Parser is parser for the Debian 'Packages' file. It aims to provide a fast and simple implementation.

=head1 METHODS

=over 3

=item new(file => 'Packages')

Creates a new DPKG::Packages::Parser object. Creating the object does not parse the file automatically. For this call the C<parse()> method.

=item parse([@fields])

Reads the file from disk and parses the entire file. You can optionally pass a list of fields that you're interested in. This speeds up processing and keeps the amount of memory lower than retaining all the fields.

Note that when passing a list of fields, the C<Package> name will always be included in the result, even if you don't pass it along.

This function returns C<1> on success or croaks if the file is not readable.

=item get_package('perl')

Takes one argument, the name of the Debian package, and returns a hashref containing all information about the package OR a hashref containing the specified fields that were given during the parse phase.

Below you can see the parsed result for the Perl package in Debian 12. (I shortened the Provides array a bit for brevity, you get the point..)

Each package name that is refered is a hash with four fields to retain all information. The value will be undef for the fields that were not available.

The Debian packages format also allows C<OR> statements. If those are encountered, it will generate an array of two or more items to reflect the C<OR>. (The OR condition is not specified explicitely)

  $VAR1 = {
            'Architecture' => 'amd64',
            'Recommends' => [
                              {
                                'arch' => undef,
                                'op' => undef,
                                'name' => 'netbase',
                                'version' => undef
                              }
                            ],
            'Pre-Depends' => [
                               {
                                 'name' => 'dpkg',
                                 'arch' => undef,
                                 'op' => '>=',
                                 'version' => '1.17.17'
                               }
                             ],
            'Section' => 'perl',
            'Size' => '238900',
            'Description' => 'Larry Wall\'s Practical Extraction and Report Language',
            'Installed-Size' => '670',
            'Build-Essential' => 'yes',
            'SHA256' => 'afa50ec7d9b1a407cd0187dae033644ef13578d4f3792435e0c41b962ffec0c4',
            'Conflicts' => [
                             {
                               'name' => 'libjson-pp-perl',
                               'arch' => undef,
                               'op' => '<<',
                               'version' => '2.27200-2'
                             }
                           ],
            'Description-md5' => '603cb1e5fe66da8106c364f4e9b84082',
            'Depends' => [
                           {
                             'version' => '5.36.0-7+deb12u3',
                             'op' => '=',
                             'arch' => undef,
                             'name' => 'perl-base'
                           },
                           {
                             'name' => 'perl-modules-5.36',
                             'op' => '>=',
                             'arch' => undef,
                             'version' => '5.36.0-7+deb12u3'
                           },
                           {
                             'op' => '=',
                             'arch' => undef,
                             'name' => 'libperl5.36',
                             'version' => '5.36.0-7+deb12u3'
                           }
                         ],
            'Package' => 'perl',
            'Multi-Arch' => 'allowed',
            'Replaces' => [
                            {
                              'version' => '5.36.0-2',
                              'name' => 'perl-base',
                              'op' => '<<',
                              'arch' => undef
                            },
                            {
                              'arch' => undef,
                              'op' => '<<',
                              'name' => 'perl-modules',
                              'version' => '5.22.0~'
                            }
                          ],
            'Maintainer' => 'Niko Tyni <ntyni@debian.org>',
            'Tag' => [
                       'devel::interpreter',
                       'devel::lang:perl',
                       'devel::library',
                       'implemented-in::c',
                       'implemented-in::perl',
                       'interface::commandline',
                       'role::devel-lib',
                       'role::metapackage',
                       'role::program'
                     ],
            'Version' => '5.36.0-7+deb12u3',
            'Provides' => [
                            {
                              'name' => 'libansicolor-perl',
                              'arch' => undef,
                              'op' => '=',
                              'version' => '5.01'
                            },
                            {
                              'version' => '2.40',
                              'name' => 'libarchive-tar-perl',
                              'op' => '=',
                              'arch' => undef
                            },
                            {
                              'version' => '1.02',
                              'name' => 'libattribute-handlers-perl',
                              'op' => '=',
                              'arch' => undef
                            },
                            {
                              'name' => 'libautodie-perl',
                              'op' => '=',
                              'arch' => undef,
                              'version' => '2.34'
                            },
                            # I removed some Packages for brevity in between here
                            {
                              'op' => '=',
                              'arch' => undef,
                              'name' => 'podlators-perl',
                              'version' => '4.14'
                            }
                          ],
            'Filename' => 'pool/main/p/perl/perl_5.36.0-7+deb12u3_amd64.deb',
            'Breaks' => [
                          {
                            'version' => '0.22.10',
                            'op' => '<<',
                            'arch' => undef,
                            'name' => 'apt-show-versions'
                          },
                          {
                            'name' => 'libdist-inkt-perl',
                            'op' => '<<',
                            'arch' => undef,
                            'version' => '0.024-5'
                          },
                          {
                            'version' => '1.35-3',
                            'arch' => undef,
                            'op' => '<<',
                            'name' => 'libmarc-charset-perl'
                          },
                          {
                            'arch' => undef,
                            'op' => '<<',
                            'name' => 'libperl-dev',
                            'version' => '5.24.0~'
                          },
                          {
                            'version' => '5.36.0-1',
                            'name' => 'perl-doc',
                            'op' => '<<',
                            'arch' => undef
                          },
                          {
                            'name' => 'perl-modules-5.22',
                            'arch' => undef,
                            'op' => undef,
                            'version' => undef
                          },
                          {
                            'op' => undef,
                            'arch' => undef,
                            'name' => 'perl-modules-5.24',
                            'version' => undef
                          },
                          {
                            'arch' => undef,
                            'op' => '<<',
                            'name' => 'perl-modules-5.26',
                            'version' => '5.26.2-5'
                          }
                        ],
            'Priority' => 'standard',
            'Suggests' => [
                            {
                              'version' => undef,
                              'arch' => undef,
                              'op' => undef,
                              'name' => 'perl-doc'
                            },
                            [
                              {
                                'op' => undef,
                                'arch' => undef,
                                'name' => 'libterm-readline-gnu-perl',
                                'version' => undef
                              },
                              {
                                'name' => 'libterm-readline-perl-perl',
                                'arch' => undef,
                                'op' => undef,
                                'version' => undef
                              }
                            ],
                            {
                              'version' => undef,
                              'op' => undef,
                              'arch' => undef,
                              'name' => 'make'
                            },
                            {
                              'version' => undef,
                              'name' => 'libtap-harness-archive-perl',
                              'op' => undef,
                              'arch' => undef
                            }
                          ],
            'Homepage' => 'http://dev.perl.org/perl5/',
            'MD5sum' => 'ecd2edf27d8e7a67795e81e1756de5f4'
          };


If you had passed a list of fields, for example: Size and MD5sum, the result would be:

  $VAR1 = {
          'Size' => '238900',
          'MD5sum' => 'ecd2edf27d8e7a67795e81e1756de5f4',
          'Package' => 'perl'
        };

=back

=head1 AUTHOR

Adriaan Dens E<lt>adri@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2026- Adriaan Dens

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 1

=item 1. DPKG::Parse::Packages - A slightly different implementation for parsing Packages files. It doesn't allow a filter of fields and also doesn't parse the lists. It is, however, the inspiration for this package.

=back
=cut
