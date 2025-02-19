## no critic: TestingAndDebugging::RequireUseStrict
package Comparer;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-23'; # DATE
our $DIST = 'Comparer'; # DIST
our $VERSION = '0.1.1'; # VERSION

1;
# ABSTRACT: Reusable comparer subroutines

__END__

=pod

=encoding UTF-8

=head1 NAME

Comparer - Reusable comparer subroutines

=head1 SPECIFICATION VERSION

0.1

=head1 VERSION

This document describes version 0.1.1 of Comparer (from Perl distribution Comparer), released on 2024-01-23.

=head1 SYNOPSIS

Basic:

 use Comparer::naturally;
 my $cmp = Comparer::naturally::gen_comparer;

 my @sorted = sort { $cmp->($a,$b) } ('track1.mp3', 'track10.mp3', 'track2.mp3', 'track1b.mp3', 'track1a.mp3');
 # => ('track1.mp3', 'track1a.mp3', 'track1b.mp3', 'track2.mp3', 'track10.mp3')

Specifying arguments:

 use Comparer::naturally;
 my $cmp = Comparer::naturally::gen_comparer(reverse => 1);
 my @sorted = sort { $cmp->($a,$b) } ...;

Specifying comparer on the command-line (for other CLI's):

 % customsort -c naturally ...
 % customsort -c naturally=reverse,1 ...

=head1 DESCRIPTION

B<EXPERIMENTAL. SPEC MIGHT STILL CHANGE.>

=head1 Glossary

A B<comparer> is a subroutine that accepts two items to be compare and return a
value of either -1/0/1. So in other words, just like Perl's C<cmp> or C<< <=>
>>.

A B<comparer module> is a module under the C<Comparer::*> namespace that you can
use to generate a comparer.

=head2 Writing a Comparer module

 package Comparer::naturally;

 # required. must return a hash (DefHash)
 sub meta {
     return +{
         v => 1,
         args => {
             reverse => {
                 schema => 'bool*', # Sah schema
             },
         },
     };
 }

 sub gen_comparer {
     my %args = @_;
     ...
 }

 1;

=head2 Namespace organization

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Comparer>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Comparer>.

=head1 SEE ALSO

=head2 Base specifications

L<DefHash>

L<Sah>

=head2 Related specifications

L<Sorter>

L<SortKey>

=head2 Previous incarnation

L<Sort::Sub>

C<Sorter>, C<SortKey>, and C<Comparer> are meant to eventually supersede
Sort::Sub. The main improvement over Sort::Sub is the split into three kinds of
subroutines:

=over

=item 1. sorter

A subroutine that accepts a list of items to sort.

C<Sorter::*> modules are meant to generate sorters.

=item 2. sort key generator

A subroutine that converts an item to a string/numeric key suitable for simple
comparison using C<eq> or C<==> during sorting.

C<SortKey::*> modules are meant to generate sort key generators.

=item 3. comparer

A subroutine that compares two items. Can be used in C<sort()> as custom sort
block.

C<Comparer::*> modules are meant to generate comparers.

Perl's C<sort()>, as mentioned above, allows us to specify a comparer, but
oftentimes it's more efficient to sort by key using key generator, where the
keys are often cached. And sometimes due to preprocessing and/or postprocessing
it's more suitable to use the more generic sorter interface.

=back

Aside from the above, C<Comparer> also makes Sort::Sub's special arguments
C<reverse> and C<is_ci> become ordinary arguments, because they are not always
applicable in all situation, especially C<is_ci>.

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
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>,
L<Pod::Weaver::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla- and/or Pod::Weaver plugins. Any additional steps required beyond
that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2024 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Comparer>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
