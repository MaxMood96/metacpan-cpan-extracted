package Data::Sah::Coerce::perl::To_int::From_str::convert_id_dow_name_to_num;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-10-20'; # DATE
our $DIST = 'Sah-Schemas-Date-ID'; # DIST
our $VERSION = '0.008'; # VERSION

sub meta {
    +{
        v => 4,
        summary => 'Convert Indonesian day-of-week name (e.g. Mg, Sen, Selasa) to number (1-7, 1=Monday/Senin)',
        prio => 50,
    };
}

sub coerce {
    my %args = @_;

    my $dt = $args{data_term};

    my $res = {};
    my $pkg = __PACKAGE__;

    $res->{expr_match} = "!ref($dt)";
    $res->{expr_coerce} = join(
        "",
        "do { ",

        # since this is a small translation table we put it inline, but for
        # larger translation table we should move it to a separate perl module
        "\$$pkg\::dow_nums ||= {",
        "  sn=>1, sen=>1, senin=>1, ",
        "  sl=>2, sel=>2, selasa=>2, ",
        "  ra=>3, rb=>3, rab=>3, rabu=>3, ",
        "  ka=>4, km=>4, kam=>4, kamis=>4, ",
        "  ju=>5, jm=>5, jum=>5, jumat=>5, 'jum\\'at'=>5, ",
        "  sa=>6, sb=>6, sab=>6, sabtu=>6, ",
        "  mi=>7, mg=>7, min=>7, mgg=>7, minggu=>7, ",
        "}; ",
        "\$$pkg\::dow_nums->{lc $dt} || $dt; ",
        "}",
    );

    $res;
}

1;
# ABSTRACT: Convert Indonesian day-of-week name (e.g. Mg, Sen, Selasa) to number (1-7, 1=Monday/Senin)

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Coerce::perl::To_int::From_str::convert_id_dow_name_to_num - Convert Indonesian day-of-week name (e.g. Mg, Sen, Selasa) to number (1-7, 1=Monday/Senin)

=head1 VERSION

This document describes version 0.008 of Data::Sah::Coerce::perl::To_int::From_str::convert_id_dow_name_to_num (from Perl distribution Sah-Schemas-Date-ID), released on 2022-10-20.

=head1 SYNOPSIS

To use in a Sah schema:

 ["int",{"x.perl.coerce_rules"=>["From_str::convert_id_dow_name_to_num"]}]

=head1 DESCRIPTION

This rule can convert Indonesian day-of-week names like:

 Mg
 SEN
 selasa

to corresponding day-of-week numbers (i.e. 7, 1, 2 in the examples above).
Unrecognized strings will just be passed as-is.

=for Pod::Coverage ^(meta|coerce)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-Schemas-Date-ID>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-Schemas-Date-ID>.

=head1 SEE ALSO

Coerce rule L<From_str::convert_en_dow_name_to_num|Data::Sah::Coerce::perl::To_int::From_str::convert_en_dow_name_to_num>

Coerce rule L<From_str::convert_locale_dow_name_to_num|Data::Sah::Coerce::perl::To_int::From_str::convert_locale_dow_name_to_num>

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

This software is copyright (c) 2022, 2020, 2019 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sah-Schemas-Date-ID>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
