package HTTP::Throwable::Role::Status::NotFound 0.028;
our $AUTHORITY = 'cpan:STEVAN';

use Moo::Role;

with(
    'HTTP::Throwable',
    'HTTP::Throwable::Role::BoringText',
);

sub default_status_code { 404 }
sub default_reason      { 'Not Found' }

no Moo::Role; 1;

=pod

=encoding UTF-8

=head1 NAME

HTTP::Throwable::Role::Status::NotFound - 404 Not Found

=head1 VERSION

version 0.028

=head1 DESCRIPTION

The server has not found anything matching the Request-URI.
No indication is given of whether the condition is temporary
or permanent. The 410 (Gone) status code SHOULD be used if
the server knows, through some internally configurable mechanism,
that an old resource is permanently unavailable and has no
forwarding address. This status code is commonly used when
the server does not wish to reveal exactly why the request
has been refused, or when no other response is applicable.

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan.little@iinteractive.com>

=item *

Ricardo Signes <cpan@semiotic.systems>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Infinity Interactive, Inc.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

__END__

# ABSTRACT: 404 Not Found

#pod =head1 DESCRIPTION
#pod
#pod The server has not found anything matching the Request-URI.
#pod No indication is given of whether the condition is temporary
#pod or permanent. The 410 (Gone) status code SHOULD be used if
#pod the server knows, through some internally configurable mechanism,
#pod that an old resource is permanently unavailable and has no
#pod forwarding address. This status code is commonly used when
#pod the server does not wish to reveal exactly why the request
#pod has been refused, or when no other response is applicable.
#pod
