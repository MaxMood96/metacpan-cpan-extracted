package Catalyst::Seal::Guard;

use strict;
use warnings;

our $VERSION = '0.01';

our %ORIGINAL;

sub replace {
    my ($key, $code) = @_;

    my $orig = do { no strict 'refs'; *{$key}{CODE} };
    unless ($orig) {
        require Catalyst::Seal;
        Catalyst::Seal::note("$key does not exist, not patching");
        return 0;
    }

    no strict 'refs';
    no warnings 'redefine';
    $ORIGINAL{$key} ||= $orig;
    *{$key} = $code;
    return 1;
}

sub restore {
    my ($key) = @_;
    my $orig = delete $ORIGINAL{$key} or return 0;
    no strict 'refs';
    no warnings 'redefine';
    *{$key} = $orig;
    return 1;
}

1;

__END__

=head1 NAME

Catalyst::Seal::Guard - replace a subroutine and keep the original

=head1 DESCRIPTION

Most of what this distribution does is install a replacement over somebody
else's subroutine. This is where that happens, so that there is one place that
knows what was there before.

The original matters at runtime and not only for tests. Several replacements
call the subroutine they shadowed: C<Catalyst::Seal::Finalize> falls back to
the stock C<finalize_encoding> for a response it has no answer for, and
C<Catalyst::Seal::Construct> calls the stock C<BUILD> for anything that is not a
plain context object. They reach it through C<%ORIGINAL>.

=cut

=head2 replace

    Catalyst::Seal::Guard::replace('Catalyst::handle_request', \&my_version);

Installs the replacement and remembers the original. Returns true when it did.

Returns false, without installing anything, when the named subroutine does not
exist. A patch site that is not there is a Catalyst that is not the one this
was written for, and installing a replacement for a subroutine nobody defined
would create it rather than replace it.

=cut

=head2 restore

Puts the original subroutine back. For tests, for a step that installs a patch
and then finds it cannot keep its side of the bargain, and for anyone who wants
to undo one at runtime.

=cut

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

