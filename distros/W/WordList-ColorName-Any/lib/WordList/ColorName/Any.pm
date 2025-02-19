package WordList::ColorName::Any;

use strict;
use parent qw(WordList);

use Role::Tiny::With;
with 'WordListRole::FirstNextResetFromEach';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-01-19'; # DATE
our $DIST = 'WordList-ColorName-Any'; # DIST
our $VERSION = '0.004'; # VERSION

our $DYNAMIC = 1;

our %PARAMS = (
    scheme => {
        summary => 'Graphics::ColorNames scheme name, e.g. "WWW" '.
            'for Graphics::ColorNames::WWW',
        schema => 'perl::colorscheme::modname',
        req => 1,
    },
);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $mod = "Graphics::ColorNames::$self->{params}{scheme}";
    (my $mod_pm = "$mod.pm") =~ s!::!/!g;
    require $mod_pm;

    my $res = &{"$mod\::NamesRgbTable"}();
    $self->{_names} = [sort keys %$res];
    $self;
}

sub each_word {
    my ($self, $code) = @_;

    for (@{ $self->{_names} }) {
        no warnings 'numeric';
        my $ret = $code->($_);
        return if defined $ret && $ret == -2;
    }
}

1;
# ABSTRACT: Wordlist from any Graphics::ColorNames::* module

__END__

=pod

=encoding UTF-8

=head1 NAME

WordList::ColorName::Any - Wordlist from any Graphics::ColorNames::* module

=head1 VERSION

This document describes version 0.004 of WordList::ColorName::Any (from Perl distribution WordList-ColorName-Any), released on 2023-01-19.

=head1 SYNOPSIS

From Perl:

 use WordList::ColorName::Any;

 my $wl = WordList::ColorName::Any->new(scheme => 'WWW');
 $wl->each_word(sub { ... });

From the command-line:

 % wordlist -w ColorName::Any=scheme,WWW

=head1 DESCRIPTION

This is a dynamic, parameterized wordlist to get list of words from a
Graphics::ColorNames::* module.

=head1 WORDLIST PARAMETERS


This is a parameterized wordlist module. When loading in Perl, you can specify
the parameters to the constructor, for example:

 use WordList::ColorName::Any;
 my $wl = WordList::ColorName::Any->(bar => 2, foo => 1);


When loading on the command-line, you can specify parameters using the
C<WORDLISTNAME=ARGNAME1,ARGVAL1,ARGNAME2,ARGVAL2> syntax, like in L<perl>'s
C<-M> option, for example:

 % wordlist -w ColorName::Any=foo,1,bar,2 ...

Known parameters:

=head2 scheme

Required. Graphics::ColorNames scheme name, e.g. "WWW" for Graphics::ColorNames::WWW.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/WordList-ColorName-Any>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-WordList-ColorName-Any>.

=head1 SEE ALSO

L<WordList>

L<Graphics::ColorNames>

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

This software is copyright (c) 2023, 2020 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=WordList-ColorName-Any>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
