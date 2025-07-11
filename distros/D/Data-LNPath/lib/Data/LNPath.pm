package Data::LNPath;

use 5.006;
use strict;
use warnings;
use Scalar::Util qw/blessed/;

our $VERSION = '1.03';

our (%ERROR, %METH, $caller);

BEGIN {
	%ERROR = (
		invalid_key => 'A miserable death %s - %s - %s',
		invalid_index => 'A slightly more miserable death %s - %s - %s',
		invalid_method => 'A horrible horrible miserable death %s - %s - %s',
		allow_meth_keys => 'jump from a high building',
	);
	%METH = (
		extract_path => sub {
			my ($follow, $end, $data, @path) = @_;

			if (scalar @path && !$end) {
				my ($key, $ref) = (shift @path, ref $data);
				$follow = sprintf "%s/%s", $follow, $key;
				if ($ref eq 'HASH') {
					$data = $data->{$key};
					$METH{error}->('invalid_key', $key, $follow) if ! defined $data;
				}
				elsif ( $ref eq 'ARRAY' ) {
					$data = $data->[$key - 1];
					$METH{error}->('invalid_index', $key, $follow) if ! defined $data;
				}
				elsif ( $ref && blessed $data ) {
					my ($meth, $params) = $METH{meth_params}->($key, $data);
					$data = scalar @{ $params || [] } ? $data->$meth(@{ $params }) : $data->$meth;
					$METH{error}->('invalid_method', $key, $follow) if ! defined $data;
				}
				else {
					$METH{error}->('invalid_path', $key, $follow) if (exists $ERROR{invalid_path});
					$end = 1;
				}
				return $METH{extract_path}->($follow, $end, $data, @path);
			}

			return $data;
		},
		unescape => sub {
			return '' unless defined $_[0];
			$_[0] =~ s/^\///g;
			$_[0] =~ s/\+/ /g;
			$_[0] =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
			return $_[0];
		},
		meth_params => sub {
			my ($key, $obj) = @_;
			my ($method, $args) = $key =~ /^(.*?)\((.*)\)$/;
			$args = $METH{generate_params}->($args, $obj) if $args;
			return ($method || $key, $args);
		},
		generate_params => sub {
			my ($string, $obj, @world, $current) = @_;
			foreach ( split /(?![^\(\[\{]+[\]\}\)]),/, $string ) {
				if ( $_ =~ m/^\s*\[\s*(.*)\]/ ) {
					$current = $METH{generate_params}->($1, $obj);
					push @world, $current;
				}
				elsif ( $_ =~ m/^\s*\{\s*(.*)\s*\}/ ) {
					$current = {};
					my %temp = split '=>', $1;
					do { $current->{$METH{generate_params}->(defined $ERROR{allow_meth_keys} ? sprintf("'%s'", $_) : ($_, $obj))->[0] } = $METH{generate_params}->($temp{$_}, $obj)->[0] } for keys %temp;
					push @world, $current;
				}
				elsif ( ($_ =~ m/^\s*(\d+)\s*$/) || ($_ =~ m/^\s*[\'\"]+\s*(.*?)\s*[\'\"]+\s*$/) ) {
					push @world, $1;
				}
				else {
					my $ex = $_ =~ s/^\s*\&//;
					my ($method, $args) = $_ =~ /^\s*(.*?)\((.*)\)$/;
					($method) = $_ =~ m/\s*(.*)\s*/ unless $method;
					$args = $args ? $METH{generate_params}->($args, $obj) : [];
					push @world, $ex ? do { no strict 'refs'; *{"${caller}::${method}"}->(@{ $args }); } : $obj->$method(@{ $args });
				}
			}
			return \@world;
		},
		error => sub {
			my ($error) = @_;
			my $find = $ERROR{$error};
			return ref $find eq 'CODE'
				? $find->(@_)
				: die sprintf $find, @_;
		}
	);
}

sub import {
	my ($pkg, $sub) = shift;
	return unless my @export = @_;
	my $opts = ref $export[scalar @export - 1] ? pop @export : {};
	$ERROR{no_error} = 1 if $opts->{return_undef};
	%ERROR = (%ERROR, %{ $opts->{errors} }) if $opts->{errors};
	@export = qw/lnpath/ if scalar @export == 1 && $export[0] eq 'all';
	$caller = scalar caller();
	{
		no strict 'refs';
		for ( @export ) {
			if ( $sub = $pkg->can($_) ? $_ : $opts->{as} && $opts->{as}->{$_} ) {
				*{"${caller}::${_}"} = \&{"${pkg}::${sub}"};
			}
		}
	}
}

sub lnpath {
	my ($data, $key) = @_;
	my $val = eval {
		$METH{extract_path}->('', 0, $data, split('/', $METH{unescape}->($key)))
	};
	if ($@ && !$ERROR{no_error}) {
		die $@;
	}
	return $val;
}

1;

__END__

=head1 NAME

Data::LNPath - lookup on nested data via path

=head1 VERSION

Version 1.03

=cut

=head1 SYNOPSIS

	use Data::LNPath qw/lnpath/ => {
		errors => {
			invalid_key => \&invalid_key,
			invalid_index => \&invalid_index,
			invalid_method => \&invalid_method,,
			allow_meth_keys => undef
		}
	};

	my $data = {
		one => {
			a => [qw/10 20 30/],
			b => { a => 10, b => 20, c => 30 },
			c => 1
		},
		two => [qw/1 2 3/],
		three => 10,
	};

	lnpath($data, '/three'); # 10
	lnpath($data, 'one/a/1'); # 10;
	lnpath($data, 'one/b/a'); # 10
	lnpath($data, 'two/2/3/4'); # 2 unless you set the additional error invalid_path (make it die)
	
	...

	use Data::LNPath qw/lnpath/;

	{
		package Test::Obj;

		sub new { bless {}, shift };
		sub plus {
			return $_[1] + $_[2];
		}

		sub minus {
			return $_[1] - $_[2];
		}

		sub crazy_world {
			return $_[1] || 100;	
		}
		
		sub magic {
			my $self = shift;
			return $_[0];
		}
	}

	sub moon {
		return $_[0] || 100;
	}

	my $data = {
		four => Test::Obj->new(),
	};

	lnpath($data, 'four/plus(10, 2)'); # 12, 'four->plus(10, 2)'
	lnpath($data, 'four/minus(200, crazy_world)'); # 100, 'four->plus(200, crazy_world)'
	lnpath($data, 'four/minus(200, crazy_world(50))'); # 150, 'four->plus(200, crazy_world(50))'
	lnpath($data, 'four/plus(200, &moon)'); # 300, 'four->plus(200, &moon)'

=head1 EXPORT

=head2 lnpath

Lookup data in a struct by path.

	lnpath($data, $path);

=cut

=head1 AUTHOR

Robert Acock, C<< <email at lnation.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-data-lnpath at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Data-LNPath>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Data::LNPath


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Data-LNPath>

=item * Search CPAN

L<http://search.cpan.org/dist/Data-LNPath/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2017->2025 Robert Acock.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

