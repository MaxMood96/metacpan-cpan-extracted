package Data::Sah::Compiler::human::TH::array;

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Mo qw(build default);
use Role::Tiny::With;

extends 'Data::Sah::Compiler::human::TH';
with 'Data::Sah::Compiler::human::TH::Comparable';
with 'Data::Sah::Compiler::human::TH::HasElems';
with 'Data::Sah::Type::array';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-02-16'; # DATE
our $DIST = 'Data-Sah'; # DIST
our $VERSION = '0.917'; # VERSION

sub handle_type {
    my ($self, $cd) = @_;
    my $c = $self->compiler;

    $c->add_ccl($cd, {
        fmt   => ["array", "arrays"],
        type  => 'noun',
    });
}

sub clause_each_index {
    my ($self, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};

    my %iargs = %{$cd->{args}};
    $iargs{outer_cd}             = $cd;
    $iargs{schema}               = $cv;
    $iargs{schema_is_normalized} = 0;
    $iargs{cache}                = $cd->{args}{cache};
    my $icd = $c->compile(%iargs);

    $c->add_ccl($cd, {
        type  => 'list',
        fmt   => 'each array subscript %(modal_verb)s be',
        items => [
            $icd->{ccls},
        ],
        vals  => [],
    });
}

sub clause_each_elem {
    my ($self, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};

    my %iargs = %{$cd->{args}};
    $iargs{outer_cd}             = $cd;
    $iargs{schema}               = $cv;
    $iargs{schema_is_normalized} = 0;
    $iargs{cache}                = $cd->{args}{cache};
    my $icd = $c->compile(%iargs);

    # can we say 'array of INOUNS', e.g. 'array of integers'?
    if (@{$icd->{ccls}} == 1) {
        my $c0 = $icd->{ccls}[0];
        if ($c0->{type} eq 'noun' && ref($c0->{text}) eq 'ARRAY' &&
                @{$c0->{text}} > 1 && @{$cd->{ccls}} &&
                    $cd->{ccls}[0]{type} eq 'noun') {
            for (ref($cd->{ccls}[0]{text}) eq 'ARRAY' ?
                     @{$cd->{ccls}[0]{text}} : ($cd->{ccls}[0]{text})) {
                my $fmt = $c->_xlt($cd, '%s of %s');
                $_ = sprintf $fmt, $_, $c0->{text}[1];
            }
            return;
        }
    }

    # nope, we can't
    $c->add_ccl($cd, {
        type  => 'list',
        fmt   => 'each array element %(modal_verb)s be',
        items => [
            $icd->{ccls},
        ],
        vals  => [],
    });
}

sub clause_elems {
    my ($self, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};

    for my $i (0..@$cv-1) {
        local $cd->{spath} = [@{$cd->{spath}}, $i];
        my $v = $cv->[$i];
        my %iargs = %{$cd->{args}};
        $iargs{outer_cd}             = $cd;
        $iargs{schema}               = $v;
        $iargs{schema_is_normalized} = 0;
        $iargs{cache}                = $cd->{args}{cache};
        my $icd = $c->compile(%iargs);
        $c->add_ccl($cd, {
            type  => 'list',
            fmt   => '%s %(modal_verb)s be',
            vals  => [
                $c->_ordinate($cd, $i+1, $c->_xlt($cd, "element")),
            ],
            items => [ $icd->{ccls} ],
        });
    }
}

1;
# ABSTRACT: human's type handler for type "array"

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Compiler::human::TH::array - human's type handler for type "array"

=head1 VERSION

This document describes version 0.917 of Data::Sah::Compiler::human::TH::array (from Perl distribution Data-Sah), released on 2024-02-16.

=for Pod::Coverage ^(clause_.+|superclause_.+)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Data-Sah>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Data-Sah>.

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

This software is copyright (c) 2024, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Data-Sah>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
