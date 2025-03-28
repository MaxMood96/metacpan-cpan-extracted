## no critic: TestingAndDebugging::RequireUseStrict
package Require::HookChain::source::test::str;

#IFUNBUILT
# use strict;
# use warnings;
#END IFUNBUILT

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-12-05'; # DATE
our $DIST = 'Require-HookChain'; # DIST
our $VERSION = '0.016'; # VERSION

sub new {
    my ($class, $src) = @_;
    bless { src => $src }, $class;
}

sub Require::HookChain::source::test::str::INC {
    my ($self, $r) = @_;

    # safety, in case we are not called by Require::HookChain
    return () unless ref $r;

    return if defined $r->src;

    $r->src($self->{src});
    return 1;
}

1;
# ABSTRACT: Use a constant string as source code

__END__

=pod

=encoding UTF-8

=head1 NAME

Require::HookChain::source::test::str - Use a constant string as source code

=head1 VERSION

This document describes version 0.016 of Require::HookChain::source::test::str (from Perl distribution Require-HookChain), released on 2023-12-05.

=head1 SYNOPSIS

In Perl code:

 use Require::HookChain 'source::test::str' => "1;\n";
 use Foo; # will use "1;\n" as source code even if the real Foo.pm is installed

On the command-line:

 # will use string '1' if Foo is not installed
 % perl -MRHC=-end,1,source::test::src,1 -MFoo -E...

=head1 DESCRIPTION

This is a test hook to load a constant string as source code of modules you are
loading. You can also achieve the same effect by directly installing an C<@INC>
hook without the L<Require::HookChain> framework like this:

 unshift @INC, sub { \"some string" };

=for Pod::Coverage .+

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Require-HookChain>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Require-HookChain>.

=head1 SEE ALSO

L<Require::HookChain>

Other C<Require::HookChain::source::*>

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

This software is copyright (c) 2023, 2022, 2020, 2017 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Require-HookChain>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
