package CPAN::Changes::Parser::KeepAChangeLog;

use strict;
use warnings;

our $VERSION = '0.1.1';

use Moo;
extends 'CPAN::Changes::Parser';

has '+version_like' => (
  is      => 'ro',
  default => sub { qr/Unreleased/i },
);

sub parse_string {
    my ($self, $string, @rest) = @_;
    return undef unless defined $string;

    my $transformed = _kac_to_cpan_changes_spec($string);
    return undef unless defined $transformed;

    return $self->SUPER::parse_string($transformed, @rest);
}

# Transform Keep a Changelog 1.1.0-ish Markdown into CPAN::Changes::Spec-ish text.
# Returns transformed string, or undef if it doesn't look like KaC / can't be transformed.
sub _kac_to_cpan_changes_spec {
    my ($in) = @_;

    # Quick “does this plausibly look like Keep a Changelog?” gate.
    # We require at least one release heading of the KaC form.
    return undef unless $in =~ /^\s*##\s+\[(?:Unreleased|[^\]]+)\]/m;

    my @out;
    my $saw_release = 0;

    for my $line (split /\n/, $in, -1) {
        # Drop CR if file is CRLF
        $line =~ s/\r\z//;

        # Drop KaC link reference definitions (commonly at bottom), e.g.:
        #   [1.0.0]: https://example/compare/v0.9.0...v1.0.0
        #   [Unreleased]: https://example/compare/v1.0.0...HEAD
        if ($line =~ /^\s*\[[^\]]+\]:\s+\S+/) {
            next;
        }

        # Release headings:
        #   ## [1.1.0] - 2024-01-31
        #   ## [1.1.0]
        #   ## [Unreleased]
        if ($line =~ /^\s*##\s+\[([^\]]+)\]\s*(?:-\s*([0-9]{4}-[0-9]{2}-[0-9]{2}))?\s*$/) {
            my ($ver, $date) = ($1, $2);

            # Normalise Unreleased to a CPAN::Changes-ish release line with an allowed “date” token.
            if ($ver =~ /\AUnreleased\z/i) {
                push @out, "Unreleased Not Released";
            }
            else {
                # If date is missing, KaC is still KaC, but CPAN::Changes parser expects something date-like.
                # We'll accept missing date and set it to "Unknown" (allowed by CPAN::Changes::Spec).
                $date //= 'Unknown';
                push @out, "$ver $date";
            }

            $saw_release = 1;
            next;
        }

        # Category headings:
        #   ### Added
        #   ### Fixed
        # Map to CPAN group marker:
        #   [Added]
        if ($line =~ /^\s*###\s+(.+?)\s*$/) {
            my $group = $1;

            # Be conservative: ignore empty/odd headings that are likely Markdown scaffolding.
            $group =~ s/\s+\z//;
            $group =~ s/\A\s+//;

            # If it’s something like “Links” or “Changelog” we still *could* treat it as a group,
            # but KaC categories are the main use. We'll accept any text, as CPAN::Changes groups are free-form.
            push @out, "[$group]";
            next;
        }

        # Top-level title:
        #   # Changelog
        # Treat as preamble. CPAN::Changes parser supports preamble, so keep it (as plain text).
        if ($line =~ /^\s*#\s+(.+?)\s*$/) {
            push @out, $1;
            next;
        }

        # Keep bullets but normalise to "- " for consistency.
        # Preserve indentation for nested bullets.
        if ($line =~ /^(\s*)[*-]\s+(.*)$/) {
            push @out, $1 . "- " . $2;
            next;
        }

        # Otherwise: pass through line as-is.
        push @out, $line;
    }

    return undef unless $saw_release;

    # Basic sanity: after transform, we should still have at least one release line
    # that the base parser is likely to recognise. We can't call its private regex here,
    # but we can assert we emitted something release-like.
    my $out = join("\n", @out);
    return undef unless $out =~ /^\s*(?:Unreleased|[0-9A-Za-z_.]+)\s+(?:\d{4}-\d{2}-\d{2}|Unknown|Not Released)\b/m;

    return $out;
}

1;

__END__

=head1 NAME

CPAN::Changes::Parser::KeepAChangeLog - Parser for Keep a Changelog formatted files

=head1 SYNOPSIS

    use CPAN::Changes::Parser::KeepAChangeLog;
    
    my $parser = CPAN::Changes::Parser::KeepAChangeLog->new;
    my $changes = $parser->parse_file('CHANGELOG.md');
    
    for my $release ($changes->releases) {
        printf "%s %s\n", $release->version, $release->date;
        for my $entry ($release->entries) {
            printf "  - %s\n", $entry->text;
        }
    }

=head1 DESCRIPTION

This module extends L<CPAN::Changes::Parser> to parse changelog files that follow
the Keep a Changelog format (L<https://keepachangelog.com/>) version 1.1.0.

Keep a Changelog uses Markdown-style formatting with specific conventions for
releases and change categories. This parser transforms that format into
CPAN::Changes objects that can be used within the Perl ecosystem.

=head2 Supported Format Features

=over 4

=item * Release headings: C<## [version] - date> or C<## [Unreleased]>

=item * Category headings: C<### Added>, C<### Fixed>, etc.

=item * Bulleted lists with C<-> or C<*>

=item * Link reference definitions (automatically filtered out)

=back

=head1 METHODS

This module inherits all methods from L<CPAN::Changes::Parser>.

=head2 parse_string

    my $changes = $parser->parse_string($changelog_string);

Parses a Keep a Changelog formatted string and returns a L<CPAN::Changes>
object, or C<undef> if the string does not appear to be in Keep a Changelog format.

=head1 ATTRIBUTES

=head2 version_like

This attribute is overridden to recognize "Unreleased" as a valid version identifier.

=head1 SEE ALSO

=over 4

=item * L<CPAN::Changes::Parser>

=item * L<CPAN::Changes>

=item * L<https://keepachangelog.com/>

=back

=head1 AUTHOR

Dave Cross <dave@perlhacks.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Dave Cross.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

