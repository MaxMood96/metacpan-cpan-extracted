package Complete::Chrome;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2021-05-09'; # DATE
our $DIST = 'Complete-Chrome'; # DIST
our $VERSION = '0.002'; # VERSION

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(
                       complete_chrome_profile_name
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Completion routines related to Google Chrome',
};

$SPEC{complete_chrome_profile_name} = {
    v => 1.1,
    summary => 'Complete from a list of Google Chrome profile names',
    args => {
        word => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
    },
    result_naked => 1,
};
sub complete_chrome_profile_name {
    require Complete::Util;
    require Chrome::Util::Profile;

    my %args = @_;

    my $res = Chrome::Util::Profile::list_chrome_profiles(detail=>1);
    return {message=>"Can't list Chrome profiles: $res->[0] - $res->[1]"}
        unless $res->[0] == 200;

    Complete::Util::complete_array_elem(
        word  => $args{word},
        array => [map {$_->{name}} @{ $res->[2] }],
    );
}

1;
# ABSTRACT: Completion routines related to Google Chrome

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Chrome - Completion routines related to Google Chrome

=head1 VERSION

This document describes version 0.002 of Complete::Chrome (from Perl distribution Complete-Chrome), released on 2021-05-09.

=for Pod::Coverage .+

=head1 FUNCTIONS


=head2 complete_chrome_profile_name

Usage:

 complete_chrome_profile_name(%args) -> any

Complete from a list of Google Chrome profile names.

This function is not exported by default, but exportable.

Arguments ('*' denotes required arguments):

=over 4

=item * B<word>* => I<str>


=back

Return value:  (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-Chrome>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Complete-Chrome>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Complete-Chrome>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 SEE ALSO

L<Complete>

Other C<Complete::*> modules.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021, 2020 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
