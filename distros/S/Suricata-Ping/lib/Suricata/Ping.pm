package Suricata::Ping;

use 5.006;
use strict;
use warnings;
use Regexp::IPv6 qw($IPv6_re);
use Regexp::IPv4 qw($IPv4_re);
use YAML::XS     qw(Load);
use File::Slurp  qw(read_file);
use Hash::Merge  ();

=head1 NAME

Suricata::Ping - Reads in a suricata config and sends a ping to the specifid interface.

=head1 VERSION

Version 0.0.1

=cut

our $VERSION = '0.0.1';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Suricata::Ping;

    my $suricata_ping;
    eval {
        $suricata_ping=Suricata::Ping->new(
            config_file=>'/usr/local/etc/suricata/config.yaml'
        );
    };
    if ($@) {
        print $@."\n";
        exit 1;
    }
    $suricata_ping->ping;

=head1 SUBROUTINES/METHODS

=head2 new

Initiates the object.

    - config_file :: The Suricata config to read in.
        - default :: undef

    - pattern :: Pattern to use with the ping.
        - default :: e034o31qwe9034oldlAd31qdgf3

    - ip :: The IP to ping.
        - default :: 8.8.8.8

    - section :: The config section of the config to use.
        - default, Linux :: af_packet
        - default, other :: pcap

    - count :: Number of packets to send.
        - default :: 5

=cut

sub new {
	my ( $empty, %opts ) = @_;

	# make sure the value passed for the config file looks sane
	if ( !defined( $opts{config_file} ) ) {
		die('$opts{config_file} is undef');
	} elsif ( !-f $opts{config_file} ) {
		die( '$opts{config_file}, "' . $opts{config_file} . '", is not a file' );
	} elsif ( !-r $opts{config_file} ) {
		die( '$opts{config_file}, "' . $opts{config_file} . '", is readable' );
	}

	# make sure we have a IP specified for IP or use the default
	if ( defined( $opts{ip} ) ) {
		if ( ref( $opts{ip} ) ne '' ) {
			die( '$opts{ip} has a ref of "' . ref( $opts{ip} ) . '" instead of ""' );
		} elsif ( $opts{ip} !~ /^$IPv4_re$/
			&& $opts{ip} !~ /^$IPv6_re$/ )
		{
			die( '$opts{ip}, "' . $opts{ip} . '", does not appear to IPv4 or 6' );
		}
	} else {
		$opts{ip} = '8.8.8.8';
	}

	# make sure we have a count specified for count or use the default
	if ( defined( $opts{count} ) ) {
		if ( ref( $opts{count} ) ne '' ) {
			die( '$opts{count} has a ref of "' . ref( $opts{count} ) . '" instead of ""' );
		} elsif ( $opts{count} !~ /^[0-9]+$/ ) {
			die( '$opts{count}, "' . $opts{count} . '", does not appear to appear to be a integer' );
		} elsif ( $opts{count} < 1 ) {
			die( '$opts{count}, "' . $opts{count} . '", may not be less than 1' );
		}
	} else {
		$opts{count} = 5;
	}

	# make sure we have a sane value for pattern or use the default
	if ( defined( $opts{pattern} ) ) {
		if ( ref( $opts{pattern} ) ne '' ) {
			die( '$opts{pattern} has a ref of "' . ref( $opts{pattern} ) . '" instead of ""' );
		}
	} else {
		$opts{pattern} = 'e034o31qwe9034oldlAd31qdgf3';
	}

	# make sure we have something sane for the section or use the default
	if ( defined( $opts{section} ) ) {
		if ( ref( $opts{section} ) ne '' ) {
			die( '$opts{section} has a ref of "' . ref( $opts{section} ) . '" instead of ""' );
		}
	} else {
		if ( $^O eq 'linux' ) {
			$opts{section} = 'af-packet';
		} else {
			$opts{section} = 'pcap';
		}
	}

	# read in the base config
	my $raw_config;
	eval { $raw_config = read_file( $opts{config_file} ); };
	if ($@) {
		die( 'Failed to read in "' . $opts{config_file} . '"... ' . $@ );
	}

	# parse the base config
	my $parsed_config;
	eval { $parsed_config = Load($raw_config); };
	if ($@) {
		die( 'Parsing "' . $opts{config_file} . '" failed... ' . $@ );
	}

	# read in the includes if needed
	if ( defined( $parsed_config->{include} ) ) {
		if ( ref( $parsed_config->{include} ) ne 'ARRAY' ) {
			die(      '.include is defined but is of ref type "'
					. ref( $parsed_config->{include} )
					. '" instead of "ARRAY"' );
		}

		my $merger = Hash::Merge->new('RIGHT_PRECEDENT');

		my $include_int = 0;
		while ( defined( $parsed_config->{include}[$include_int] ) ) {
			if ( ref( $parsed_config->{include}[$include_int] ) ne '' ) {
				die(      '.include['
						. $include_int
						. '] is defined but is of ref type "'
						. ref( $parsed_config->{include} )
						. '" instead of ""' );
			}

			my $raw_include;
			eval { $raw_include = read_file( $parsed_config->{include}[$include_int] ); };
			if ($@) {
				die(      'Failed to read in include['
						. $include_int . '], "'
						. $parsed_config->{include}[$include_int] . '"... '
						. $@ );
			}

			my $parsed_include;
			eval { $parsed_include = Load($raw_include); };
			if ($@) {
				die(      'Parsing .include['
						. $include_int . '], "'
						. $parsed_config->{include}[$include_int]
						. '", failed... '
						. $@ );
			}

			$parsed_config = $merger->merge( $parsed_config, $parsed_include );

			$include_int++;
		} ## end while ( defined( $parsed_config->{include}[$include_int...]))
	} ## end if ( defined( $parsed_config->{include} ) )

	if ( !defined( $parsed_config->{ $opts{section} } ) ) {
		die( '.' . $opts{section} . ' not found in the config file ' . $opts{config_file} );
	}
	if ( ref( $parsed_config->{ $opts{section} } ) ne 'ARRAY' ) {
		die( 'section .' . $opts{section} . ' ref is "' . $parsed_config->{ $opts{section} } . '" and not "ARRAY"' );
	}
	if ( !defined( $parsed_config->{ $opts{section} }[0] ) ) {
		die( '.' . $opts{section} . '[0] is undef so this config has no configured interfaces' );
	}

	my @interfaces;
	my $interfaces_int = 0;
	while ( defined( $parsed_config->{ $opts{section} }[$interfaces_int] ) ) {
		if (   ( ref( $parsed_config->{ $opts{section} }[$interfaces_int] ) eq 'HASH' )
			&& defined( $parsed_config->{ $opts{section} }[$interfaces_int]{interface} )
			&& ( ref( $parsed_config->{ $opts{section} }[$interfaces_int]{interface} ) eq '' ) )
		{
			push( @interfaces, $parsed_config->{ $opts{section} }[$interfaces_int]{interface} );
		}

		$interfaces_int++;
	} ## end while ( defined( $parsed_config->{ $opts{section...}}))

	if ( !defined( $interfaces[0] ) ) {
		die(      'No configured interfaces found in the config file "'
				. $opts{config_file}
				. '" under the section .'
				. $opts{section} );
	}

	my $self = {
		config_file => $opts{config_file},
		pattern     => $opts{pattern},
		ip          => $opts{ip},
		section     => $opts{section},
		interfaces  => \@interfaces,
		count       => $opts{count},
	};
	bless $self;

	return $self;
} ## end sub new

=head2 ping

Pings each interface.

This does not return any status or the like.

This requires ping be in the current path.

    $suricata_ping->ping;

=cut

sub ping {
	my ( $self, %opts ) = @_;

	foreach my $interface ( @{ $self->{interfaces} } ) {
		system( 'ping', '-c', $self->{count}, '-p', $self->{pattern}, '-I', $interface, $self->{ip} );
	}
}

=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-suricata-ping at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Suricata-Ping>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Suricata::Ping


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Suricata-Ping>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Suricata-Ping>

=item * Search CPAN

L<https://metacpan.org/release/Suricata-Ping>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999


=cut

1;    # End of Suricata::Ping
