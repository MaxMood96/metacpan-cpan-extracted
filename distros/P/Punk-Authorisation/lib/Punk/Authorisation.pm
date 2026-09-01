package Punk::Authorisation;

use 5.010;
use strict;
use warnings;
use XSLoader ();
use Punk::Command ();

our $VERSION = '0.01';

XSLoader::load('Punk::Authorisation', $VERSION);

if (Punk::Command->can('register_doctor')) {
    Punk::Command->register_doctor('Punk::Authorisation' => sub {
        my $mod    = 'Punk/Plugin/Authorisation.pm';
        my $loaded = $INC{$mod} || eval { require $mod; $INC{$mod} };
        return (0, "$VERSION; the plugin did not load") unless $loaded;

        (my $dir = $loaded) =~ s/\.pm\z//;
        $dir .= '/sqitch';
        my $ok = -f "$dir/sqitch.plan";
        return ($ok, $VERSION . ($ok ? ' (punk_authz)' : '; no plan for punk_authz'));
    }, __PACKAGE__);
}

1;

__END__

=head1 NAME

Punk::Authorisation - may this user act on this row

=head1 SYNOPSIS

    # lib/Shop.pm
    auth model => 'User', rank => [qw(member admin owner)], roles => sub { ... };
    plugin 'Authorisation';                       # rules: Shop::Authorisation

    # lib/Shop/Authorisation.pm
    package Shop::Authorisation;
    use Punk::Plugin::Authorisation;              # installs `rule`

    rule 'doc.edit' => sub {
        my ($c, $doc) = @_;
        return 1 if $doc->{owner_id} == $c->auth_id;
        return $c->forbidden if $c->rank_at_least('admin');
        return $c->not_yours;
    };
    1;

    # in a controller
    my $doc = $c->model('Doc')->get(id => $c->param('id'));
    $c->may('doc.edit', $doc) or return $c->deny;

=head1 DESCRIPTION

C<auth_guard> answers B<may this user reach this route>. An API key's scope
answers B<may this credential call this operation>. Neither can answer B<may
this user act on this row>, and that is where the commonest authorisation bug
in a web application lives: the controller that loads a row by an id from the
request and forgets to ask whose it is.

This distribution is the asking. The rules are the application's and live in
one package it owns; what lives here is the machinery around them -
collecting them, refusing to guess at a name nobody defined, and turning a
refusal into the right status, which is a 404 rather than a 403 whenever a
403 would confirm that somebody else's row exists.

Two modules and a table:

=over 4

=item L<Punk::Plugin::Authorisation>

The plugin. Its options, its helpers, and what each refusal means. This is
the one to read.

=item L<Punk::Model::Grant>

The grants table, for what one user hands another. Off unless
C<< plugin 'Authorisation' => { grants => ... } >> asks for it, and worth
reading about before it is: a grant table is a second source of truth
wherever a rule already encodes ownership.

=item The C<punk_authz> Sqitch project

Ships beside the plugin, so L<Punk::Sqitch> deploys the table without the
application writing the DDL. The DDL is in L<Punk::Model::Grant> for an
application that manages its schema another way.

=back

=head1 REQUIREMENTS

L<Punk> 0.32 or newer. The plugin reads the role ladder and the roles hook
from the C<auth> keyword through C<< $app->auth_config >>, which 0.32 is the
first release to provide, rather than being told them a second time in its
own options.

=head1 SEE ALSO

L<Punk::Plugin::Authorisation> for the plugin, L<Punk::Model::Grant> for the
table, L<Punk::Auth> for the guard this sits beside, and L<Punk::DIY> for a
generated application that uses all of them.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
