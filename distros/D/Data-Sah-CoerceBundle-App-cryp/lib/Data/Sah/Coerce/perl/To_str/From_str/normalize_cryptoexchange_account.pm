package Data::Sah::Coerce::perl::To_str::From_str::normalize_cryptoexchange_account;

# AUTHOR
our $DATE = '2019-11-28'; # DATE
our $DIST = 'Data-Sah-CoerceBundle-App-cryp'; # DIST
our $VERSION = '0.009'; # VERSION

use 5.010001;
use strict;
use warnings;

sub meta {
    +{
        v => 4,
        summary => 'Normalize cryptoexchange account',
        might_fail => 1,
        prio => 50,
    };
}

sub coerce {
    my %args = @_;

    my $dt = $args{data_term};

    my $res = {};

    $res->{expr_match} = "!ref($dt)";
    $res->{modules}{"CryptoExchange::Catalog"} //= 0;
    $res->{expr_coerce} = join(
        "",
        "do { my (\$xch, \$acc); $dt =~ m!(.+)/(.+)! and (\$xch, \$acc) = (\$1, \$2) or (\$xch, \$acc) = ($dt, 'default'); ",
        "if (\$acc !~ /\\A[A-Za-z0-9_-]+\\z/) { [qq(Invalid account syntax (\$acc), please only use letters/numbers/underscores/dashes)] } ",
        "elsif (length \$acc > 64) { [qq(Account name too long (\$acc), please do not exceed 64 characters)] } ",
        "else { my \$cat = CryptoExchange::Catalog->new; my \@data = \$cat->all_data; ",
        "  my \$lc = lc(\$xch); my \$rec; for (\@data) { if (defined(\$_->{code}) && \$lc eq lc(\$_->{code}) || \$lc eq lc(\$_->{name}) || \$lc eq \$_->{safename}) { \$rec = \$_; last } } ",
        "  if (!\$rec) { ['Unknown cryptoexchange code/name/safename: ' . \$lc] } else { [undef, qq(\$rec->{safename}/\$acc)] } ",
        "} }",
    );

    $res;
}

1;
# ABSTRACT: Normalize cryptoexchange account

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Coerce::perl::To_str::From_str::normalize_cryptoexchange_account - Normalize cryptoexchange account

=head1 VERSION

This document describes version 0.009 of Data::Sah::Coerce::perl::To_str::From_str::normalize_cryptoexchange_account (from Perl distribution Data-Sah-CoerceBundle-App-cryp), released on 2019-11-28.

=head1 SYNOPSIS

To use in a Sah schema:

 ["str",{"x.perl.coerce_rules"=>["From_str::normalize_cryptoexchange_account"]}]

=head1 DESCRIPTION

Cryptoexchange account is of the following format:

 cryptoexchange/account

where C<cryptoexchange> is the name/code/safename of cryptoexchange as listed in
L<CryptoExchange::Catalog>. This coercion rule normalizes cryptoexchange into
safename and will die if name/code/safename is not listed in the catalog module.

C<account> must also be [A-Za-z0-9_-]+ only and not exceed 64 characters in
length.

=for Pod::Coverage ^(meta|coerce)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Data-Sah-CoerceBundle-App-cryp>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Data-Sah-CoerceBundle-App-cryp>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Data-Sah-CoerceBundle-App-cryp>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019, 2018 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
