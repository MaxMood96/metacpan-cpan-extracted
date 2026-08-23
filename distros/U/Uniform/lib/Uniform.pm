package Uniform;

use strict;
use warnings;

our $VERSION = '1.03';

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Uniform - The Unified, Framework-Agnostic Web Infrastructure Specification for Perl

=head1 SYNOPSIS

    # This is a documentation and utility anchor distribution.
    # See companion component packages for active implementations:

    # cpanm Uniform::HTMX


=head1 DESCRIPTION

The C<Uniform> ecosystem provides a standardized, framework-agnostic architectural
layer for modern Perl web development.

Web frameworks (such as Dancer2, Mojolicious, Catalyst, and raw Plack/PSGI) handle
common tasks—such as processing HTTP headers, manipulating file uploads, and tracking
session authentication—using wildly divergent object maps and execution semantics.

The C<Uniform> specification isolates these operational variances into dedicated,
framework-specific driver subclasses. By programming against a C<Uniform::*>
interface, your core application business logic remains entirely decoupled from the
underlying web deployment engine, preventing framework lock-in and simplifying future
platform migrations.

=head1 THE UNIFORM COMPONENT SPECIFICATION

Every component authored under the C<Uniform::*> namespace must adhere to the
following strict architectural contracts:

=over 4

=item 1. Explicit Framework Subclasses

Components must not use runtime auto-detection or implicit framework guessing engines.
Drivers must be explicitly loaded and instantiated by the application developer:

    use Uniform::HTMX::PSGI;
    my $hx = Uniform::HTMX::PSGI->new($env);

=item 2. Fluent Mutators

All state modification methods must return C<$self> to preserve clean method-chaining
capabilities.

=item 3. The apply() Boundary

State changes or outbound headers must never be implicitly written to the web server
mid-flight. Outbound side-effects must remain safely queued in memory until the developer
explicitly executes the C<apply()> method.

=item 4. Fail-Fast Exceptions

Methods must strictly validate their incoming parameters. If an invalid reference or a
malformed parameter structure is encountered, the driver must throw an immediate
exception using L<Uniform::Exceptions> or C<Carp::croak> to guarantee clear error tracking.

=back

=head1 CENTRAL UTILITIES

This root distribution exposes shared internal utility libraries designed to accelerate
the development of external driver plugins. See L<Uniform::Utils> for details.

=head1 SEE ALSO

L<Uniform::HTMX>

L<Uniform::Upload>

=head1 AUTHOR

Joshua S. Day E<lt>HAX@cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by Joshua S. Day.
This is free software, licensed under the Artistic License 2.0.

=cut
