package Net::FTP::Path::Iter;

# ABSTRACT: Iterative, recursive, FTP file finder

use 5.010;

use strict;
use warnings;
use Carp;

our $VERSION = '0.07';

use Net::FTP;
use File::Spec::Functions qw[ splitpath ];

use parent 'Path::Iterator::Rule';

use Net::FTP::Path::Iter::Dir;

use namespace::clean;
























sub new {

    my $class = shift;

    my %attr;
    if ( @_ % 2 ) {
        my $host = shift;
        %attr = @_;
        $attr{Host} = $host;
    }
    else {
        %attr = @_;
    }

    my $self = $class->SUPER::new();

    defined( my $host = delete $attr{Host} )
      or croak( "missing Host attribute\n" );

    defined( my $user = delete $attr{user} )
      or croak( "missing user attribute\n" );

    defined( my $password = delete $attr{password} )
      or croak( "missing password attribute\n" );

    $self->{server} = Net::FTP->new( $host, %attr )
      or croak( "unable to connect to server $host\n" );

    $self->{server}->login( $user, $password )
      or croak( "unable to log in to $host\n" );

    return $self;
}

sub _defaults {
    return (
        _stringify      => 0,
        follow_symlinks => 1,
        depthfirst      => 0,
        sorted          => 1,
        loop_safe       => 1,
        error_handler   => sub { die sprintf( '%s: %s', @_ ) },
        visitor         => undef,
    );
}

sub _fast_defaults {

    return (
        _stringify      => 0,
        follow_symlinks => 1,
        depthfirst      => -1,
        sorted          => 0,
        loop_safe       => 0,
        error_handler   => undef,
        visitor         => undef,
    );
}

sub _objectify {

    my ( $self, $path ) = @_;

    my ( undef, $directories, $name ) = splitpath( $path );

    $directories =~ s{(.+)/$}{$1};

    my %attr = (
        parent => $directories,
        name   => $name,
        path   => $path,
    );

    return Net::FTP::Path::Iter::Dir->new( server => $self->{server}, %attr );
}

sub _children {

    my ( undef, $path ) = @_;

    return map { [ $_->{name}, $_ ] } $path->_children;
}

sub _iter {

    my $self     = shift;
    my $defaults = shift;

    $defaults->{loop_safe} = 0;

    $self->SUPER::_iter( $defaults, @_ );

}

1;

#
# This file is part of Net-FTP-Path-Iter
#
# This software is Copyright (c) 2017 by Smithsonian Astrophysical Observatory.
#
# This is free software, licensed under:
#
#   The GNU General Public License, Version 3, June 2007
#

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory

=head1 NAME

Net::FTP::Path::Iter - Iterative, recursive, FTP file finder

=head1 VERSION

version 0.07

=head1 SYNOPSIS

    use Net::FTP::Path::Iter;

    # connect to the FTP site
    my $ftp = Net::FTP::Path::Iter->new( $ftp_site, $user, $password );

    # define a visitor callback routine. It will recieve a
    # Net::FTP::Path::Iter::Entry object.
    sub visitor { my ($entry) = @_ }

    # use the Path::Iterator::Rule all() method to traverse the
    # site;
    $ftp->all( '/', \&visitor );

=head1 DESCRIPTION

B<Net::FTP::Path::Iter> is a subclass of L<Path::Iterator::Rule> which
iterates over an FTP site rather than a local filesystem.

See the documentation L<Path::Iterator::Rule> for how to filter and
traverse paths.  When B<Net::FTP::Path::Iter> passes a path to a callback or
returns one from an iterator, it will be in the form of a
L<Net::FTP::Path::Iter::Entry> object.

B<Net::FTP::Path::Iter> uses L<Net::FTP> to connect to the FTP site.

=head2 Symbolic Links

At present, B<Net::FTP::Path::Iter> does not handle symbolic links. It will
output an error and skip them.

=head1 METHODS

=head2 new

  $ftp = Net::FTP::Path::Iter->new( [$host], %options );

Open up a connection to an FTP host and log in.  The arguments
are the same as for L<Net::FTP/new>, with the addition of two
mandatory options,

=over

=item C<user>

The user name

=item C<password>

The password

=back

=head1 INTERNALS

=head1 ATTRIBUTES

B<Net::FTP::Path::Iter> subclasses L<Path::Iter::Rule>. It is a hash based object
and has the following additional attributes:

=over

=item C<server>

The B<Net::FTP> object representing the connection to the FTP server.

=back

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-net-ftp-path-iter@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Net-FTP-Path-Iter>

=head2 Source

Source is available at

  https://gitlab.com/djerius/net-ftp-path-iter

and may be cloned from

  https://gitlab.com/djerius/net-ftp-path-iter.git

=head1 AUTHOR

Diab Jerius <djerius@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2017 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
