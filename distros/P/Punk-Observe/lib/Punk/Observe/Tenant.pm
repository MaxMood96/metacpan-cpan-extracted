package Punk::Observe::Tenant;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Tenant - the tenant seam, kept honest

=head1 SYNOPSIS

    use Punk::Observe::Tenant;

    my $r = Punk::Observe::Tenant::resolve('acme', undef);
    die $r->{reason} unless $r->{ok};

=head1 DESCRIPTION

Every path this distribution builds is rooted at the store root and every
segment header carries a tenant id, so the engine is single-tenant in policy
and never in path.

This module does not resolve tenants for a hosted deployment. It keeps the
seam from rotting in the meantime, which is what decides whether that
deployment is configuration or a rewrite.

=head2 The default is a constant

The self-hosted shape is the whole shape: one tenant, named by configuration,
resolved by returning it. The hosted shape is the same code with a callback.

If the constant case went through a different path than the callback case,
everything the seam was built for would be spent.

=head2 A tenant id is never taken from anything a client sends

Not a header, not a query parameter, not a path segment.

That is not a check performed here - it is the B<absence> of a function that
would do it. The resolver callback takes an opaque userdata and no request,
and there is nothing in this distribution that reads a tenant out of one.

=head2 Host code is not trusted

A resolver is a callback the host supplies, and whatever it returns is
validated against the same character class as a configured constant before a
byte of it reaches a path. An over-long answer is B<refused>, never
truncated: shortening an invalid id into a valid one is the same class of
mistake as accepting it.

=head1 FUNCTIONS

=head2 check

    my $r = Punk::Observe::Tenant::check($id);

Returns C<< { ok, code, reason } >>. A tenant id is
C<[A-Za-z0-9_-]{1,64}>.

The reason is specific, because the person debugging a resolver wrote the
resolver and "invalid tenant" is not a bug report.

=head2 resolve

    my $r = Punk::Observe::Tenant::resolve($fixed, $coderef_or_undef);

Resolves through the seam and validates the result. Returns
C<< { ok, code, reason, tenant } >>. A bad configured constant is refused at
configuration time and says so in C<at>, so a typo is a boot failure rather
than a runtime one.

=head2 hash

    my $h = Punk::Observe::Tenant::hash($id);

The hash a segment header carries.

=head2 owns

    my $bool = Punk::Observe::Tenant::owns($header_hash, $id);

Whether a segment belongs to this tenant. Checked when the file is B<opened>:
a mis-filed segment found at open is an error, one found after it has been
read is a disclosure that already happened.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Plugin::Observe>

=cut
