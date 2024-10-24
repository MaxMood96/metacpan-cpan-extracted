package Number::Format::Metric;

use 5.010001;
use locale;
use strict;
use utf8;
use warnings;

use Exporter qw(import);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-02-14'; # DATE
our $DIST = 'Number-Format-Metric'; # DIST
our $VERSION = '0.602'; # VERSION

our @EXPORT_OK = qw(
                       format_metric
               );

sub format_metric {
    my ($num, $opts) = @_;
    $opts //= {};
    $opts->{base} //= 2;

    my $im    = $opts->{i_mark} // 1;
    my $base0 = $opts->{base};
    my $base  = $base0 == 2 ? 1024 : 1000;

    my $rank;
    my $prefix;
    if ($num == 0) {
        $rank = 0;
        $prefix = "";
    } else {
        $rank = int(log(abs($num))/log($base));
        if    ($rank ==  0 && abs($num) >= 1) { $prefix = ""  }
        elsif ($rank ==  1) { $prefix = $im && $base0==10 ? "ki" : "k" } # kilo
        elsif ($rank ==  2) { $prefix = $im && $base0==10 ? "Mi" : "M" } # mega
        elsif ($rank ==  3) { $prefix = $im && $base0==10 ? "Gi" : "G" } # giga
        elsif ($rank ==  4) { $prefix = $im && $base0==10 ? "Ti" : "T" } # tera
        elsif ($rank ==  5) { $prefix = $im && $base0==10 ? "Pi" : "P" } # peta
        elsif ($rank >=  8) { $prefix = $im && $base0==10 ? "Yi" : "Y" } # yotta
        elsif ($rank ==  7) { $prefix = $im && $base0==10 ? "Zi" : "Z" } # zetta
        elsif ($rank ==  6) { $prefix = $im && $base0==10 ? "Ei" : "E" } # exa
        elsif ($rank ==  0) { $prefix = "m" } # milli
        elsif ($rank == -1) { $prefix = "μ" } # micro
        elsif ($rank == -2) { $prefix = "n" } # nano
        elsif ($rank == -3) { $prefix = "p" } # pico
        elsif ($rank == -4) { $prefix = "f" } # femto
        elsif ($rank == -5) { $prefix = "a" } # atto
        elsif ($rank == -6) { $prefix = "z" } # zepto
        elsif ($rank <= -7) { $prefix = "y" } # yocto
    }

    my $prec = $opts->{precision} // 1;
    $num = $num / $base**($rank <= 0 && abs($num) < 1 ? $rank-1 : $rank);
    if ($opts->{return_array}) {
        return [$num, $prefix];
    } else {
        my $snum = sprintf("%.${prec}f", $num);
        return $snum . $prefix;
    }
}

1;
# ABSTRACT: Format number with metric prefix

__END__

=pod

=encoding UTF-8

=head1 NAME

Number::Format::Metric - Format number with metric prefix

=head1 VERSION

This document describes version 0.602 of Number::Format::Metric (from Perl distribution Number-Format-Metric), released on 2023-02-14.

=head1 SYNOPSIS

 use Number::Format::Metric qw(format_metric);

 format_metric(14     , {base=>10});               # => "14.0"
 format_metric(14     , {base=>10, precision=>0}); # => "14"
 format_metric(12001  , {base=> 2, precision=>1}); # => "11.7k"
 format_metric(12001  , {base=>10, precision=>3}); # => "12.001ki"
 format_metric(-0.0017, {base=>10});               # => "-1.7m"
 format_metric(1.26e6 , {base=>10});               # => "1.3Mi"

=head1 FUNCTIONS

None exported by default but all of them exportable.

=head2 format_metric($num, \%opts) => STR

Format C<$num> using metric prefix. Locale settings are respected (this module
uses L<locale>). Might produce non-Latin Unicode characters (e.g. μ for 1e-6
prefix). Known options:

=over

=item * base => INT (either 2 or 10, default: 2)

=item * precision => INT

=item * i_mark => BOOL (default: 1)

Give "i" suffix to prefixes when in base 10 for k, M, G, T, and so on.

=back

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Number-Format-Metric>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Number-Format-Metric>.

=head1 SEE ALSO

Other number formatting modules: L<Number::Format>, L<Format::Human::Bytes>,
L<Number::Bytes::Human>.

L<https://en.wikipedia.org/wiki/Metric_prefix>

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 CONTRIBUTOR

=for stopwords Steven Haryanto

Steven Haryanto <stevenharyanto@gmail.com>

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

This software is copyright (c) 2023, 2014, 2013 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Number-Format-Metric>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
