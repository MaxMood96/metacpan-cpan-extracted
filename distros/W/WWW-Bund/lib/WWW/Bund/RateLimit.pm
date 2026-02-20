package WWW::Bund::RateLimit;
our $VERSION = '0.002';
# ABSTRACT: Per-API rate limiting with sliding window

use Moo;
use Time::HiRes qw(time sleep);
use Carp qw(croak);
use namespace::clean;


has limits => (
    is      => 'ro',
    default => sub { {
        tagesschau => { max => 60, window => 3600 },
        smard      => { max => 60, window => 3600 },
    } },
);


has _timestamps => (is => 'ro', default => sub { {} });

sub check {
    my ($self, $api) = @_;
    my $limit = $self->limits->{$api} or return 1;

    my $now = time();
    my $window = $limit->{window};
    my $max = $limit->{max};

    $self->_timestamps->{$api} ||= [];
    my $ts = $self->_timestamps->{$api};

    @$ts = grep { $_ > $now - $window } @$ts;

    if (scalar(@$ts) >= $max) {
        my $oldest = $ts->[0];
        my $wait = $oldest + $window - $now;
        if ($wait > 0) {
            sleep($wait);
            @$ts = grep { $_ > time() - $window } @$ts;
        }
    }

    push @$ts, time();
    return 1;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::RateLimit - Per-API rate limiting with sliding window

=head1 VERSION

version 0.002

=head1 SYNOPSIS

    use WWW::Bund::RateLimit;

    my $limiter = WWW::Bund::RateLimit->new(
        limits => {
            tagesschau => { max => 60, window => 3600 },
            smard      => { max => 60, window => 3600 },
        },
    );

    # Check rate limit (blocks if exceeded)
    $limiter->check('tagesschau');

=head1 DESCRIPTION

Enforces per-API rate limits using a sliding window algorithm. If the rate
limit is exceeded, C<check> will sleep until the oldest request falls outside
the window.

Currently configured limits:

=over

=item * tagesschau: 60 requests per hour

=item * smard: 60 requests per hour

=back

APIs without configured limits are not rate-limited.

=head2 limits

HashRef of rate limit configurations per API. Each entry has:

=over

=item * C<max> - Maximum number of requests

=item * C<window> - Time window in seconds

=back

=head2 check

    $limiter->check($api_id);

Check rate limit for API. If limit is exceeded, sleeps until a request slot
becomes available.

Returns C<1> always (after potentially sleeping).

APIs without configured limits pass through immediately.

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
