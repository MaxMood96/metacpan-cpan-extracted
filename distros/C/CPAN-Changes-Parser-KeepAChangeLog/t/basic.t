use strict;
use warnings;

use Test::More;

use CPAN::Changes::Parser::KeepAChangeLog;

sub _walk_entries {
    my ($node, $cb) = @_;

    if (ref($node) eq 'ARRAY') {
        _walk_entries($_, $cb) for @$node;
        return;
    }

    # CPAN::Changes::Entry objects are blessed refs; we don't need to name the class
    # as long as they have ->text and ->entries.
    if (ref($node) && eval { $node->can('text') && $node->can('entries') }) {
        $cb->($node);
        my @kids = $node->entries;
        _walk_entries(\@kids, $cb) if @kids;
        return;
    }

    # Unknown scalar/ref: ignore (keeps test resilient)
    return;
}

sub _find_entry_by_text {
    my ($entries, $want) = @_;
    my $found;

    _walk_entries($entries, sub {
        my ($e) = @_;
        return if defined $found;
        $found = $e if defined $e->text && $e->text eq $want;
    });

    return $found;
}


my $parser = CPAN::Changes::Parser::KeepAChangeLog->new;

subtest 'basic Keep a Changelog file parses' => sub {
    my $kac = <<'END_CHANGELOG';
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
### Added
- Experimental feature

### Fixed
- Typo in documentation

## [1.0.0] - 2024-01-01
### Added
- Initial release

[Unreleased]: https://example.com/compare/v1.0.0...HEAD
[1.0.0]: https://example.com/releases/tag/v1.0.0
END_CHANGELOG

    my $changes = $parser->parse_string($kac);

    ok($changes, 'parser returned a CPAN::Changes object') or do {
        diag("parse_string returned undef");
        done_testing;
        return;
    };

    my @releases = $changes->releases;
    is(scalar @releases, 2, 'two releases parsed') or do {
        diag("Got releases: " . join(", ", map { $_->version } @releases));
        done_testing;
        return;
    };

    is($releases[0]->version, '1.0.0', 'oldest release has version 1.0.0');
    is($releases[1]->version, 'Unreleased', 'latest release is Unreleased');
    is($releases[1]->date, 'Not Released', 'Unreleased mapped to "Not Released" date');

    my @entries = $releases[1]->entries;
    ok(@entries, 'Unreleased has entries');

    my $added_group = $releases[1]->find_entry('Added');
    ok($added_group, 'Added group exists');

    my $experimental = $added_group->find_entry('Experimental feature');
    ok($experimental, 'Added group contains "Experimental feature"');

    is($experimental->text, 'Experimental feature', 'Entry text preserved');

    done_testing;
};

subtest 'non-Keep a Changelog file returns undef' => sub {
    my $not_kac = <<'END_CHANGES';
Revision history for Foo-Bar

1.23  2024-01-01
  - Regular CPAN-style changes file
END_CHANGES

    my $changes = $parser->parse_string($not_kac);

    ok(!defined $changes, 'non-KaC input returns undef');

    done_testing;
};

done_testing;

