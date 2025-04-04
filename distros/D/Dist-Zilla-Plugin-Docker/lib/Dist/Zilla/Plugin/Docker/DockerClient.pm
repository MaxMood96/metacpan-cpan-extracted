package Dist::Zilla::Plugin::Docker::DockerClient;
# ABSTRACT: Internal Use Only, do not use!
$Dist::Zilla::Plugin::Docker::DockerClient::VERSION = '0.01';
use strict;
use warnings;

use Moose;

has docker_tag => (is => 'ro', isa => 'Str', required => 1);

sub build_image {
  my ($self, $dir, $dockerfile) = @_;

  system('docker', 'build',
    '-f' => $dockerfile,
    '-t' => $self->docker_tag,
    $dir
  ) and Carp::croak "docker build failed: $@";
}

sub push_image {
  my $self = shift;

  system('docker', 'push', $self->docker_tag)
    and Carp::croak "docker build failed: $@";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Docker::DockerClient - Internal Use Only, do not use!

=head1 VERSION

version 0.01

=for Pod::Coverage - build_image
- push_image

=head1 SOURCE

The development version is on github at L<https://https://github.com/mschout/dist-zilla-plugin-docker>
and may be cloned from L<git://https://github.com/mschout/dist-zilla-plugin-docker.git>

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website
L<https://github.com/mschout/dist-zilla-plugin-docker/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Michael Schout <mschout@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Michael Schout.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
