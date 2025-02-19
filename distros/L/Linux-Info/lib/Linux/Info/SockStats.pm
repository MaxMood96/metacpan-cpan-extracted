package Linux::Info::SockStats;
use strict;
use warnings;
use Carp qw(croak);

our $VERSION = '2.19'; # VERSION
# ABSTRACT: Collect linux socket statistics.


sub new {
    my $class = shift;
    my $opts  = ref( $_[0] ) ? shift : {@_};

    my %self = (
        files => {
            path     => '/proc',
            sockstat => 'net/sockstat',
        }
    );

    foreach my $file ( keys %{ $opts->{files} } ) {
        $self{files}{$file} = $opts->{files}->{$file};
    }

    return bless \%self, $class;
}

sub get {
    my $self  = shift;
    my $class = ref $self;
    my $file  = $self->{files};
    my %socks = ();

    my $filename =
      $file->{path} ? "$file->{path}/$file->{sockstat}" : $file->{sockstat};
    open my $fh, '<', $filename
      or croak "$class: unable to open $filename ($!)";

    while ( my $line = <$fh> ) {
        if ( $line =~ /sockets: used (\d+)/ ) {
            $socks{used} = $1;
        }
        elsif ( $line =~ /TCP: inuse (\d+)/ ) {
            $socks{tcp} = $1;
        }
        elsif ( $line =~ /UDP: inuse (\d+)/ ) {
            $socks{udp} = $1;
        }
        elsif ( $line =~ /RAW: inuse (\d+)/ ) {
            $socks{raw} = $1;
        }
        elsif ( $line =~ /FRAG: inuse (\d+)/ ) {
            $socks{ipfrag} = $1;
        }
    }

    close($fh);
    return \%socks;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Linux::Info::SockStats - Collect linux socket statistics.

=head1 VERSION

version 2.19

=head1 SYNOPSIS

    use Linux::Info::SockStats;

    my $lxs  = Linux::Info::SockStats->new;
    my $stat = $lxs->get;

=head1 DESCRIPTION

Linux::Info::SockStats gathers socket statistics from the virtual F</proc> filesystem (procfs).

For more information read the documentation of the front-end module L<Linux::Info>.

=head1 SOCKET STATISTICS

Generated by F</proc/net/sockstat>.

    used    -  Total number of used sockets.
    tcp     -  Number of tcp sockets in use.
    udp     -  Number of udp sockets in use.
    raw     -  Number of raw sockets in use.
    ipfrag  -  Number of ip fragments in use (only available by kernels > 2.2).

=head1 METHODS

=head2 new()

Call C<new()> to create a new object.

    my $lxs = Linux::Info::SockStats->new;

It's possible to set the path to the proc filesystem.

     Linux::Info::SockStats->new(
        files => {
            # This is the default
            path => '/proc',
            sockstat => 'net/sockstat',
        }
    );

=head2 get()

Call C<get()> to get the statistics. C<get()> returns the statistics as a hash reference.

    my $stat = $lxs->get;

=head1 EXPORTS

Nothing.

=head1 SEE ALSO

=over

=item *

B<proc(5)>

=item *

L<Linux::Info>

=back

=head1 AUTHOR

Alceu Rodrigues de Freitas Junior <glasswalk3r@yahoo.com.br>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2015 by Alceu Rodrigues de Freitas Junior.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
