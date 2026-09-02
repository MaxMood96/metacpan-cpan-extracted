package Punk::APIKey;

use 5.010;
use strict;
use warnings;
use XSLoader ();
use Punk::Command ();

our $VERSION = '0.02';

XSLoader::load('Punk::APIKey', $VERSION);

if (Punk::Command->can('register_doctor')) {
    Punk::Command->register_doctor('Punk::APIKey' => sub {
        my $mod    = 'Punk/Plugin/APIKey.pm';
        my $loaded = $INC{$mod} || eval { require $mod; $INC{$mod} };
        return (0, "$VERSION; no plan for punk_apikey") unless $loaded;

        (my $dir = $loaded) =~ s/\.pm\z//;
        $dir .= '/sqitch';
        return -f "$dir/sqitch.plan"
            ? (1, "$VERSION (punk_apikey)")
            : (0, "$VERSION; no plan for punk_apikey");
    }, __PACKAGE__);
}

1;

__END__

=head1 NAME

Punk::APIKey - API keys for Punk applications

=head1 SYNOPSIS

    package MyApp;
    use Punk;
    use Punk::Plugin::APIKey;

    plugin 'APIKey' => {
        model  => 'ApiKey',
        owner  => 'owner_id',
        scopes => [qw(read write admin)],
    };

    my ($key, $row) = $c->api_key_issue(owner => $c->auth_id, label => 'CI',
                                        scopes => ['read']);

    my $api = under '/api/v1' => api_key_guard(scope => 'read');

=head1 DESCRIPTION

A key is minted once, stored as a digest, presented as
C<Authorization: Bearer>, and checked by a guard that answers an API's
refusals rather than a browser's. It is scoped, revocable, rate limited per
key, and answerable to its owner's current standing.

This file is the distribution: it loads the compiled half and carries the
version. What it holds is documented where the behaviour is.

=head2 What is here

=over 4

=item L<Punk::Plugin::APIKey>

The plugin, and the reference documentation: the key format, the options, the
guards, the owner's standing, the per-key limit and the traps.

=item L<Punk::Model::ApiKey>

The table, for an application that has not declared a model of its own.

=item L<Punk::Command::Apikey>

C<punk apikey> - issuing, listing and revoking keys from outside the browser,
reading the application's own configuration rather than taking a table on the
command line.

=item The C<punk_apikey> Sqitch project

The schema for SQLite, PostgreSQL and MySQL, registered through
L<Punk::Sqitch> when it is installed. The DDL is in
L<Punk::Plugin::APIKey/"THE SCHEMA"> for an application that manages its
schema some other way.

=back

=head1 THE EXAMPLE

F<example/apikey-demo/> is the whole plugin as a running application: keys
minted in a browser, spent from a terminal, narrowed by a demotion, refused
by a suspension, and revoked. Generated with C<punk new ApiKeyDemo --sqitch
sqlite>, so its layout is the ordinary one.

    cd example/apikey-demo
    punk sqitch deploy      # two projects: this plugin's, then the app's
    plackup app.psgi

Its F<README.md> is the tour and its F<t/01-basic.t> asserts every claim in
it.

=head1 SEE ALSO

L<Punk::Plugin::APIKey>, L<Punk::Auth>, L<Punk::Sqitch>.

=head1 AUTHOR

LNATION <email@lnation.org>

=head1 BUGS

Please report any bugs or feature requests to C<bug-punk-apikey at
rt.cpan.org>, or through the web interface at
L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Punk-APIKey>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Punk::APIKey

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2026 by LNATION <email@lnation.org>.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
