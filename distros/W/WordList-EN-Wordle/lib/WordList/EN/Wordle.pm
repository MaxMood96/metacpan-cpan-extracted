package WordList::EN::Wordle;

use strict;
use parent 'WordList';

use Role::Tiny::With;
with 'WordListRole::Source::ArrayData';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-03-06'; # DATE
our $DIST = 'WordList-EN-Wordle'; # DIST
our $VERSION = '0.002'; # VERSION

our %STATS = ("num_words",12947,"num_words_contain_unicode",0,"num_words_contains_unicode",0,"num_words_contain_whitespace",0,"longest_word_len",5,"num_words_contain_nonword_chars",0,"shortest_word_len",5,"num_words_contains_whitespace",0,"avg_word_len",5,"num_words_contains_nonword_chars",0); # STATS

sub _arraydata {
    require ArrayData::Lingua::Word::EN::Wordle;
    ArrayData::Lingua::Word::EN::Wordle->new;
}

1;
# ABSTRACT: English word list for Wordle

__END__

=pod

=encoding UTF-8

=head1 NAME

WordList::EN::Wordle - English word list for Wordle

=head1 VERSION

This document describes version 0.002 of WordList::EN::Wordle (from Perl distribution WordList-EN-Wordle), released on 2022-03-06.

=head1 SYNOPSIS

 use WordList::EN::Wordle;

 my $wl = WordList::EN::Wordle->new;

 # Pick a (or several) random word(s) from the list
 my ($word) = $wl->pick;
 my ($word) = $wl->pick(1);  # ditto
 my @words  = $wl->pick(3);  # no duplicates

 # Check if a word exists in the list
 if ($wl->word_exists('foo')) { ... }  # case-sensitive

 # Call a callback for each word
 $wl->each_word(sub { my $word = shift; ... });

 # Iterate
 my $first_word = $wl->first_word;
 while (defined(my $word = $wl->next_word)) { ... }

 # Get all the words (beware, some wordlists are *huge*)
 my @all_words = $wl->all_words;

=head1 WORDLIST STATISTICS

 +----------------------------------+-------+
 | key                              | value |
 +----------------------------------+-------+
 | avg_word_len                     | 5     |
 | longest_word_len                 | 5     |
 | num_words                        | 12947 |
 | num_words_contain_nonword_chars  | 0     |
 | num_words_contain_unicode        | 0     |
 | num_words_contain_whitespace     | 0     |
 | num_words_contains_nonword_chars | 0     |
 | num_words_contains_unicode       | 0     |
 | num_words_contains_whitespace    | 0     |
 | shortest_word_len                | 5     |
 +----------------------------------+-------+

The statistics is available in the C<%STATS> package variable.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/WordList-EN-Wordle>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-WordList-EN-Wordle>.

=head1 SEE ALSO

This wordlist gets its source of words from
L<ArrayData::Lingua::Word::EN::Wordle>.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTING


To contribute, you can send patches by email/via RT, or send pull requests on
GitHub.

Most of the time, you don't need to build the distribution yourself. You can
simply modify the code, then test via:

 % prove -l

If you want to build the distribution (e.g. to try to install it locally on your
system), you can install L<Dist::Zilla>,
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla plugin and/or Pod::Weaver::Plugin. Any additional steps required
beyond that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=WordList-EN-Wordle>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
