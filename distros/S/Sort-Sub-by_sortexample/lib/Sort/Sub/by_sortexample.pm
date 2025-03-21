package Sort::Sub::by_sortexample;

use 5.010001;
use strict;
use warnings;
use Log::ger;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2025-01-12'; # DATE
our $DIST = 'Sort-Sub-by_sortexample'; # DIST
our $VERSION = '0.001'; # VERSION

sub meta {
    return {
        v => 1,
        summary => 'Sort by a SortExample module',
        description => <<'MARKDOWN',

This is basically the same as <pm:Sort::Sub::by_example>, but instead of
specifying the example items directly, you specify the name of a `SortExample::`
module, without the prefix.

MARKDOWN
        args => {
            sortexample => {
                summary => 'The name of a SortExample:: module, without the prefix',
                schema => ['perl::modname'],
                req => 1,
                pos => 0,
            },
        },
    };
}

sub gen_sorter {
    require Module::Load::Util;
    require Sort::ByExample;

    my ($is_reverse, $is_ci, $args) = @_;

    my $example = Module::Load::Util::call_module_function_with_optional_args(
        {ns_prefix => "SortExample"}, "$args->{sortexample}::get_example");

    $example = [map {lc} @$example] if $is_ci;
    $example = [reverse @$example] if $is_reverse;

    log_trace "example=%s", $example;

    my $cmp = Sort::ByExample->cmp($example);
    #use Data::Dmp; dd $cmp
}

1;
# ABSTRACT: Sort by a SortExample module

__END__

=pod

=encoding UTF-8

=head1 NAME

Sort::Sub::by_sortexample - Sort by a SortExample module

=head1 VERSION

This document describes version 0.001 of Sort::Sub::by_sortexample (from Perl distribution Sort-Sub-by_sortexample), released on 2025-01-12.

=head1 SYNOPSIS

Generate sorter (accessed as variable) via L<Sort::Sub> import:

 use Sort::Sub '$by_sortexample'; # use '$by_sortexample<i>' for case-insensitive sorting, '$by_sortexample<r>' for reverse sorting
 my @sorted = sort $by_sortexample ('item', ...);

Generate sorter (accessed as subroutine):

 use Sort::Sub 'by_sortexample<ir>';
 my @sorted = sort {by_sortexample} ('item', ...);

Generate directly without Sort::Sub:

 use Sort::Sub::by_sortexample;
 my $sorter = Sort::Sub::by_sortexample::gen_sorter(
     ci => 1,      # default 0, set 1 to sort case-insensitively
     reverse => 1, # default 0, set 1 to sort in reverse order
 );
 my @sorted = sort $sorter ('item', ...);

Use in shell/CLI with L<sortsub> (from L<App::sortsub>):

 % some-cmd | sortsub by_sortexample
 % some-cmd | sortsub by_sortexample --ignore-case -r

=head1 DESCRIPTION

=for Pod::Coverage ^(gen_sorter|meta)$

=head1 SORT ARGUMENTS

C<*> marks required arguments.

=head2 sortexample*

perl::modname.

The name of a SortExample:: module, without the prefix.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sort-Sub-by_sortexample>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sort-Sub-by_sortexample>.

=head1 SEE ALSO

L<Sort::ByExample>

L<Sort::Sub::by_example>

L<Sort::Sub>

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

This software is copyright (c) 2025 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sort-Sub-by_sortexample>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
