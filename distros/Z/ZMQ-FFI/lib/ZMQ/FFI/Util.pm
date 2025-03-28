package ZMQ::FFI::Util;
$ZMQ::FFI::Util::VERSION = '1.19';
# ABSTRACT: zmq convenience functions

use strict;
use warnings;

use FFI::Platypus;
use FFI::CheckLib qw(find_lib);
use Carp;

use Sub::Exporter -setup => {
    exports => [qw(
        zmq_soname
        zmq_version
        valid_soname
        current_tid
    )],
};

sub zmq_soname {
    my %args = @_;

    my $die = $args{die};

    my ($soname) = find_lib(
        lib => 'zmq',
        alien => 'Alien::ZMQ::latest',
        verify => sub {
            my($name, $libpath) = @_;
            return valid_soname($libpath);
        },
    );

    if ( !$soname && $die ) {
        croak
            qq(Could not load libzmq:\n),
            q(Is libzmq on your loader path?);
    }

    return $soname;
}

sub zmq_version {
    my ($soname) = @_;

    $soname //= zmq_soname();

    return unless $soname;

    my $ffi = FFI::Platypus->new( lib => $soname, ignore_not_found => 1 );
    my $zmq_version = $ffi->function(
        'zmq_version',
        ['int*', 'int*', 'int*'],
        'void'
    );

    unless (defined $zmq_version) {
        croak   "Could not find zmq_version in '$soname'\n"
              . "Is '$soname' on your loader path?";
    }

    my ($major, $minor, $patch);
    $zmq_version->call(\$major, \$minor, \$patch);

    return $major, $minor, $patch;
}

sub valid_soname {
    my ($soname) = @_;

    my $ffi = FFI::Platypus->new( lib => $soname, ignore_not_found => 1 );
    my $zmq_version = $ffi->function(
        'zmq_version',
        ['int*', 'int*', 'int*'],
        'void'
    );

    return defined $zmq_version;
}

sub current_tid {
    if (eval 'use threads; 1') {
        require threads;
        threads->import();
        return threads->tid;
    }
    else {
        return -1;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

ZMQ::FFI::Util - zmq convenience functions

=head1 VERSION

version 1.19

=head1 SYNOPSIS

    use ZMQ::FFI::Util q(zmq_soname zmq_version)

    my $soname = zmq_soname();
    my ($major, $minor, $patch) = zmq_version($soname);

=head1 FUNCTIONS

=head2 zmq_soname([die => 0|1])

Tries to load C<libzmq> by looking for platform-specific shared library file
using L<FFI::CheckLib> with a fallback to L<Alien::ZMQ::latest>.

Returns the name of the first one that was successful or undef. If you would
prefer exceptional behavior pass C<die =E<gt> 1>

=head2 ($major, $minor, $patch) = zmq_version([$soname])

return the libzmq version as the list C<($major, $minor, $patch)>. C<$soname>
can either be a filename available in the ld cache or the path to a library
file. If C<$soname> is not specified it is resolved using C<zmq_soname> above

If C<$soname> cannot be resolved undef is returned

=head1 SEE ALSO

=over 4

=item *

L<ZMQ::FFI>

=back

=head1 AUTHOR

Dylan Cali <calid1984@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2023 by Dylan Cali.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
