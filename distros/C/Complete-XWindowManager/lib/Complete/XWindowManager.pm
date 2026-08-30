package Complete::XWindowManager;

use 5.010001;
use strict;
use warnings;

use Exporter 'import';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2026-05-29'; # DATE
our $DIST = 'Complete-XWindowManager'; # DIST
our $VERSION = '0.001'; # VERSION

our @EXPORT_OK = qw(
                       complete_window_id
                       complete_window_title
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Completion routines related to X Window Manager',
};

$SPEC{complete_xwm_window_id} = {
    v => 1.1,
    summary => 'Complete from a list of existing window IDs',
    args => {
        word => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
};
sub complete_xwm_window_id {
    require Complete::Util;
    require Desktop::XWindowManager::Util;

    my %args = @_;

    my $res = Desktop::XWindowManager::Util::list_xwm_windows(detail=>1);
    return {message=>"Can't list windows: $res->[0] - $res->[1]"}
        unless $res->[0] == 200;

    Complete::Util::complete_array_elem(
        word  => $args{word},
        array => [map { +{word=>$_->{id}, summary=>$_->{title}} } @{ $res->[2] }],
    );
}

$SPEC{complete_xwm_window_title} = {
    v => 1.1,
    summary => 'Complete from a list of existing window titles',
    args => {
        word => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
};
sub complete_xwm_window_title {
    require Complete::Util;
    require Desktop::XWindowManager::Util;

    my %args = @_;

    my $res = Desktop::XWindowManager::Util::list_xwm_windows(detail=>1);
    return {message=>"Can't list windows: $res->[0] - $res->[1]"}
        unless $res->[0] == 200;

    Complete::Util::complete_array_elem(
        word  => $args{word},
        array => [map {$_->{title}} @{ $res->[2] }],
    );
}

1;
# ABSTRACT: Completion routines related to X Window Manager

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::XWindowManager - Completion routines related to X Window Manager

=head1 VERSION

This document describes version 0.001 of Complete::XWindowManager (from Perl distribution Complete-XWindowManager), released on 2026-05-29.

=for Pod::Coverage .+

=head1 FUNCTIONS


=head2 complete_xwm_window_id

Usage:

 complete_xwm_window_id(%args) -> any

Complete from a list of existing window IDs.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<word>* => I<str>

(No description)


=back

Return value:  (any)



=head2 complete_xwm_window_title

Usage:

 complete_xwm_window_title(%args) -> any

Complete from a list of existing window titles.

This function is not exported.

Arguments ('*' denotes required arguments):

=over 4

=item * B<word>* => I<str>

(No description)


=back

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-XWindowManager>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Complete-XWindowManager>.

=head1 SEE ALSO

L<Complete>

Other C<Complete::*> modules.

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

This software is copyright (c) 2026 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Complete-XWindowManager>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
