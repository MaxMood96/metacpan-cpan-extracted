package WWW::Bund::Role::IO;
our $VERSION = '0.002';
# ABSTRACT: Interface role for pluggable HTTP backends

use Moo::Role;


requires 'call';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::Role::IO - Interface role for pluggable HTTP backends

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    package My::HTTP::Backend;
    use Moo;
    with 'WWW::Bund::Role::IO';

    sub call {
        my ($self, $request) = @_;
        # Execute HTTP request
        # Return WWW::Bund::HTTPResponse
    }

=head1 DESCRIPTION

Role defining the interface for HTTP backend implementations. Allows plugging
in alternative HTTP clients (async, mocked, etc.) by implementing the C<call>
method.

The default implementation is L<WWW::Bund::LWPIO> using L<LWP::UserAgent>.

=head1 REQUIRED METHODS

=head2 call

    my $response = $io->call($request);

Execute an HTTP request. Takes L<WWW::Bund::HTTPRequest>, returns
L<WWW::Bund::HTTPResponse>.

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-www-bund/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.de>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
