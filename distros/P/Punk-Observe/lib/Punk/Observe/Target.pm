package Punk::Observe::Target;

use 5.010;
use strict;
use warnings;

use Punk::Observe ();

our $VERSION = $Punk::Observe::VERSION;

1;

__END__

=head1 NAME

Punk::Observe::Target - where a webhook is allowed to point

=head1 SYNOPSIS

    use Punk::Observe::Target;

    my $r = Punk::Observe::Target::check($url, \@allowlist);
    die "refused: $r->{reason}\n" unless $r->{ok};

=head1 DESCRIPTION

A webhook URL is attacker-influenced input, and fetching it is an SSRF: the
server makes a request to an address a user typed into a form.

On a cloud instance that request comes from inside the perimeter. The classic
target is the metadata service on C<169.254.169.254>, which hands credentials
to anything asking from the right place; loopback reaches whatever else is
bound on the box, including this process.

So the destination is validated B<before> the request and the default is
refusal: loopback, link-local, the private ranges, and anything that is not
plain C<http> or C<https>.

=head2 What it does not claim

This is not a complete SSRF defence. A hostname that resolves to a private
address defeats any check made on a string, which is why the same policy must
also be applied to the B<address> at connect time by the caller.

What this module does is refuse the literal cases - which is most of them -
and refuse them where an operator can see the reason.

A few names are refused as well as addresses, because C<http://localhost:5432/>
never reaches an address check that is only applied to literals:
C<localhost>, anything under C<.localhost>, C<.local>, C<.internal> and
C<metadata.google.internal>.

Userinfo cannot disguise a host. C<http://hooks.example.com@127.0.0.1/> is
loopback, and a parser that stops at the first delimiter reads the decoy.

=head2 The allowlist is exhaustive

An operator who has decided an internal host is a legitimate webhook target
says so explicitly. Once an allowlist exists, nothing outside it is permitted
- falling through to the default ranges would make it a suggestion rather
than a policy.

An entry matches a whole host or a B<dot-anchored> suffix. The anchor
matters: an entry of C<slack.com> must not admit C<slack.com.attacker.net>,
which a plain suffix compare does.

The allowlist never overrides the scheme. C<file://> and C<gopher://> are not
webhook destinations under any policy.

=head1 FUNCTIONS

=head2 check

    my $r = Punk::Observe::Target::check($url, $allowlist_or_undef);

Returns C<< { ok, code, reason } >>. C<reason> is a sentence fit to show an
operator, since the point of refusing is that somebody can tell why.

=head1 SEE ALSO

L<Punk::Observe>, L<Punk::Observe::Route>

=cut
