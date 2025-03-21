package Data::Sah::Compiler::perl::TH::cistr;

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Mo qw(build default);
use Role::Tiny::With;

extends 'Data::Sah::Compiler::perl::TH::str';
with 'Data::Sah::Type::cistr';

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-02-16'; # DATE
our $DIST = 'Data-Sah'; # DIST
our $VERSION = '0.917'; # VERSION

sub before_all_clauses {
    my ($self, $cd) = @_;
    my $c = $self->compiler;
    my $dt = $cd->{data_term};

    # XXX only do this when there are clauses

    # convert to lowercase so we don't lc() the data repeatedly
    $self->set_tmp_data_term($cd, "lc($dt)");
}

sub after_all_clauses {
    my ($self, $cd) = @_;
    my $c = $self->compiler;
    my $dt = $cd->{data_term};

    $self->restore_data_term($cd);
}

sub superclause_comparable {
    my ($self, $which, $cd) = @_;
    my $c  = $self->compiler;
    my $ct = $cd->{cl_term};
    my $dt = $cd->{data_term};

    if ($which eq 'is') {
        $c->add_ccl($cd, "$dt eq lc($ct)");
    } elsif ($which eq 'in') {
        if ($dt =~ /\$_\b/) {
            $c->add_ccl($cd, "do { my \$_sahv_dt = $dt; grep { lc(\$_) eq \$_sahv_dt } \@{ $ct } }");
        } else {
            $c->add_ccl($cd, "grep { lc(\$_) eq $dt } \@{ $ct }");
        }
    }
}

sub superclause_sortable {
    my ($self, $which, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};
    my $ct = $cd->{cl_term};
    my $dt = $cd->{data_term};

    if ($which eq 'min') {
        $c->add_ccl($cd, "$dt ge lc($ct)");
    } elsif ($which eq 'xmin') {
        $c->add_ccl($cd, "$dt gt lc($ct)");
    } elsif ($which eq 'max') {
        $c->add_ccl($cd, "$dt le lc($ct)");
    } elsif ($which eq 'xmax') {
        $c->add_ccl($cd, "$dt lt lc($ct)");
    } elsif ($which eq 'between') {
        if ($cd->{cl_is_expr}) {
            $c->add_ccl($cd, "$dt ge lc($ct\->[0]) && ".
                            "$dt le lc($ct\->[1])");
        } else {
            # simplify code
            $c->add_ccl($cd, "$dt ge ".$c->literal(lc $cv->[0]).
                            " && $dt le ".$c->literal(lc $cv->[1]));
        }
    } elsif ($which eq 'xbetween') {
        if ($cd->{cl_is_expr}) {
            $c->add_ccl($cd, "$dt gt lc($ct\->[0]) && ".
                            "$dt lt lc($ct\->[1])");
        } else {
            # simplify code
            $c->add_ccl($cd, "$dt gt ".$c->literal(lc $cv->[0]).
                            " && $dt lt ".$c->literal(lc $cv->[1]));
        }
    }
}

sub superclause_has_elems {
    my ($self_th, $which, $cd) = @_;
    my $c  = $self_th->compiler;
    my $cv = $cd->{cl_value};
    my $ct = $cd->{cl_term};
    my $dt = $cd->{data_term};

    if ($which eq 'has') {
        $c->add_ccl($cd, "index($dt, lc($ct)) > -1");
    } else {
        $self_th->SUPER::superclause_has_elems($which, $cd);
    }
}

# turn "(?-xism:blah)" to "(?i-xsm:blah)"
sub __change_re_str_switch {
    my $re = shift;

    if ($^V ge v5.14.0) {
        state $sub = sub { my $s = shift; $s =~ /i/ ? $s : "i$s" };
        $re =~ s/\A\(\?\^(\w*):/"(?".$sub->($1).":"/e;
    } else {
        state $subl = sub { my $s = shift; $s =~ /i/ ? $s : "i$s" };
        state $subr = sub { my $s = shift; $s =~ s/i//; $s };
        $re =~ s/\A\(\?(\w*)-(\w*):/"(?".$subl->($1)."-".$subr->($2).":"/e;
    }
    return $re;
}

sub clause_match {
    my ($self, $cd) = @_;
    my $c  = $self->compiler;
    my $cv = $cd->{cl_value};
    my $ct = $cd->{cl_term};
    my $dt = $cd->{data_term};

    if ($cd->{cl_is_expr}) {
        $c->add_ccl($cd, join(
            "",
            "ref($ct) eq 'Regexp' ? $dt =~ qr/$ct/i : ",
            "do { my \$_sahv_re = $ct; eval { \$_sahv_re = /\$_sahv_re/i; 1 } && ",
            "$dt =~ \$_sahv_re }",
        ));
    } else {
        # simplify code and we can check regex at compile time
        my $re = $c->_str2reliteral($cd, $cv);
        $re = __change_re_str_switch($re);
        $c->add_ccl($cd, "$dt =~ /$re/i");
    }
}

1;
# ABSTRACT: perl's type handler for type "cistr"

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Compiler::perl::TH::cistr - perl's type handler for type "cistr"

=head1 VERSION

This document describes version 0.917 of Data::Sah::Compiler::perl::TH::cistr (from Perl distribution Data-Sah), released on 2024-02-16.

=for Pod::Coverage ^(clause_.+|superclause_.+|handle_.+|before_.+|after_.+)$

=head1 NOTES

Should probably be reimplemented using special Perl string type, or special Perl
operators, instead of simulated using C<lc()> on a per-clause basis. The
implementation as it is now is not "contagious", e.g. C<< [cistr =>
check_each_elem => '$_ eq "A"'] >> should be true even if data is C<"Aaa">,
since one would expect C<< $_ eq "A" >> is also done case-insensitively, but it
is currently internally implemented by converting data to lowercase and
splitting per character to become C<< ["a", "a", "a"] >>.

Or, avoid C<cistr> altogether and use C<prefilters> to convert to
lowercase/uppercase first before processing.

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
