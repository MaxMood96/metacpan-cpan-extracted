package App::cryp::Cmd::Exchange::get_order;

our $DATE = '2021-05-26'; # DATE
our $VERSION = '0.012'; # VERSION

use 5.010;
use strict;
use warnings;

require App::cryp::exchange;

our %SPEC;

$SPEC{handle_cmd} = $App::cryp::exchange::SPEC{get_order};
*handle_cmd = \&App::cryp::exchange::get_order;

1;
# ABSTRACT: Get information about an order

__END__

=pod

=encoding UTF-8

=head1 NAME

App::cryp::Cmd::Exchange::get_order - Get information about an order

=head1 VERSION

This document describes version 0.012 of App::cryp::Cmd::Exchange::get_order (from Perl distribution App-cryp-exchange), released on 2021-05-26.

=head1 FUNCTIONS


=head2 handle_cmd

Usage:

 handle_cmd(%args) -> [$status_code, $reason, $payload, \%result_meta]

Get information about an order.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<account>* => I<cryptoexchange::account>

=item * B<order_id>* => I<str>

=item * B<pair>* => I<str>

=item * B<type>* => I<str>


=back

Returns an enveloped result (an array).

First element ($status_code) is an integer containing HTTP-like status code
(200 means OK, 4xx caller error, 5xx function error). Second element
($reason) is a string containing error message, or something like "OK" if status is
200. Third element ($payload) is the actual result, but usually not present when enveloped result is an error response ($status_code is not 2xx). Fourth
element (%result_meta) is called result metadata and is optional, a hash
that contains extra information, much like how HTTP response headers provide additional metadata.

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-cryp-exchange>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-cryp-exchange>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://github.com/perlancar/perl-App-cryp-exchange/issues>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021, 2018 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
