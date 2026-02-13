package WWW::Bund::API::Bundestag;
our $VERSION = '0.001';
# ABSTRACT: Adapter for Bundestag API (parliament data)

use Moo;
use namespace::clean;


has client => (is => 'ro', required => 1, weak_ref => 1);


sub speaker {
    my ($self) = @_;
    $self->client->call('bundestag', 'bundestag_speaker');
}


sub conferences {
    my ($self) = @_;
    $self->client->call('bundestag', 'bundestag_conferences');
}


sub ausschuesse {
    my ($self) = @_;
    $self->client->call('bundestag', 'bundestag_ausschuesse');
}


sub ausschuss {
    my ($self, $id) = @_;
    $self->client->call('bundestag', 'bundestag_ausschuss',
        params => { AUSSCHUSS_ID => $id },
    );
}


sub mdb_index {
    my ($self) = @_;
    $self->client->call('bundestag', 'bundestag_mdb_index');
}


sub mdb_bio {
    my ($self, $id) = @_;
    $self->client->call('bundestag', 'bundestag_mdb_bio',
        params => { MDB_ID => $id },
    );
}


sub article {
    my ($self, $id) = @_;
    $self->client->call('bundestag', 'bundestag_article',
        params => { ARTICLE_ID => $id },
    );
}


sub video_feed {
    my ($self) = @_;
    $self->client->call('bundestag', 'bundestag_video_feed');
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

WWW::Bund::API::Bundestag - Adapter for Bundestag API (parliament data)

=head1 VERSION

version 0.001

=head1 SYNOPSIS

    use WWW::Bund;

    my $bund = WWW::Bund->new;
    my $bundestag = $bund->bundestag;

    # General info
    my $speaker = $bundestag->speaker;
    my $conferences = $bundestag->conferences;

    # Committees (Ausschüsse)
    my $committees = $bundestag->ausschuesse;
    my $committee = $bundestag->ausschuss($id);

    # Members of Parliament (MdB)
    my $mdb_index = $bundestag->mdb_index;
    my $biography = $bundestag->mdb_bio($mdb_id);

    # Content
    my $article = $bundestag->article($article_id);
    my $videos = $bundestag->video_feed;

=head1 DESCRIPTION

Type-safe adapter for the Bundestag API, providing access to German Federal
Parliament (Bundestag) data including members, committees, and proceedings.

Note: This API returns XML responses which are parsed to HashRef.

=head2 client

L<WWW::Bund> client instance. Required. Weak reference.

=head2 speaker

Get information about the Bundestag speaker (Bundestagspräsident).

=head2 conferences

List upcoming and recent Bundestag conferences/sessions.

=head2 ausschuesse

List all Bundestag committees (Ausschüsse).

=head2 ausschuss

    my $committee = $bundestag->ausschuss($committee_id);

Get details for a specific committee by ID.

=head2 mdb_index

List all Members of Bundestag (MdB - Mitglieder des Bundestags).

=head2 mdb_bio

    my $biography = $bundestag->mdb_bio($mdb_id);

Get biography and details for a specific MdB by ID.

=head2 article

    my $article = $bundestag->article($article_id);

Get a specific article/document by ID.

=head2 video_feed

Get video feed of Bundestag proceedings.

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
