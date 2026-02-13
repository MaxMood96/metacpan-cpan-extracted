package WWW::Bund::API::Tagesschau;
our $VERSION = '0.001';
# ABSTRACT: Adapter for Tagesschau API (news)

use Moo;
use namespace::clean;


has client => (is => 'ro', required => 1, weak_ref => 1);


sub homepage {
    my ($self) = @_;
    $self->client->call('tagesschau', 'tagesschau_homepage');
}


sub news {
    my ($self, %params) = @_;
    $self->client->call('tagesschau', 'tagesschau_news',
        %params ? (params => \%params) : (),
    );
}


sub search {
    my ($self, $query) = @_;
    $self->client->call('tagesschau', 'tagesschau_search',
        params => { searchText => $query },
    );
}


sub channels {
    my ($self) = @_;
    $self->client->call('tagesschau', 'tagesschau_channels');
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::API::Tagesschau - Adapter for Tagesschau API (news)

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;
    my $tagesschau = $bund->tagesschau;

    # Get homepage news
    my $homepage = $tagesschau->homepage;

    # Get all news (optionally filtered)
    my $news = $tagesschau->news;
    my $news = $tagesschau->news(regions => 1);

    # Search news
    my $results = $tagesschau->search('Bundestag');

    # List available channels
    my $channels = $tagesschau->channels;

=head1 DESCRIPTION

Type-safe adapter for the Tagesschau API, providing access to news articles
from Germany's main public broadcasting news service.

=head2 client

L<WWW::Bund> client instance. Required. Weak reference.

=head2 homepage

    my $homepage = $tagesschau->homepage;

Get news from the homepage. Returns HashRef with news, regional, and video sections.

=head2 news

    my $news = $tagesschau->news;
    my $news = $tagesschau->news(regions => 1);

Get all news articles. Optional query parameters can filter results.

=head2 search

    my $results = $tagesschau->search($query);

Search news articles by keyword. Returns ArrayRef of matching articles.

=head2 channels

    my $channels = $tagesschau->channels;

List available news channels/categories.

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
