## no critic: Modules::ProhibitAutomaticExportation

package Test::Sort::Sub;

use 5.010001;
use strict 'subs', 'vars';
use warnings;

use Exporter 'import';
use Sort::Sub ();
use Test::More 0.98;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-07-17'; # DATE
our $DIST = 'Sort-Sub'; # DIST
our $VERSION = '0.121'; # VERSION

our @EXPORT = qw(sort_sub_ok);

sub _sort {
    my ($args, $extras, $output_name) = @_;

    my $subname = $args->{subname};
    Sort::Sub->import("$subname$extras", ($args->{args} ? $args->{args} : ()));
    my $res;
    if ($args->{compares_record}) {
        $res = [map {$_->[0]} sort {&{$subname}($a,$b)}
                    (map { [$args->{input}[$_], $_] } 0..$#{ $args->{input} })];
    } else {
        $res = [sort {&{$subname}($a,$b)} @{ $args->{input} }];
    }
    is_deeply($args->{$output_name}, $res) or diag explain $res;
}

sub sort_sub_ok {
    my %args = @_;

    my $subname = $args{subname};
    subtest "sort_sub_ok $subname" => sub {
        my $res;

        if ($args{output}) {
            _sort(\%args, '', 'output');
        }

        if ($args{output_i}) {
            _sort(\%args, '<i>', 'output_i');
        }

        if ($args{output_r}) {
            _sort(\%args, '<r>', 'output_r');
        };

        if ($args{output_ir}) {
            _sort(\%args, '<ir>', 'output_ir');
        };
    };
}

1;
# ABSTRACT: Test Sort::Sub::* subroutine

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Sort::Sub - Test Sort::Sub::* subroutine

=head1 VERSION

This document describes version 0.121 of Test::Sort::Sub (from Perl distribution Sort-Sub), released on 2024-07-17.

=head1 FUNCTIONS

=head2 sort_sub_ok(%args) => bool

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sort-Sub>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sort-Sub>.

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

This software is copyright (c) 2024, 2020, 2019, 2018, 2016, 2015 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sort-Sub>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
