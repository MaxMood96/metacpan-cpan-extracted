package Data::Sah::Filter::perl::JSON::decode;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-11-15'; # DATE
our $DIST = 'Sah-Schemas-JSON'; # DIST
our $VERSION = '0.007'; # VERSION

sub meta {
    +{
        v => 1,
        summary => 'Decode from JSON',
        might_fail => 1,
        examples => [
            {value=>'', valid=>0, summary=>'Empty string is not valid JSON'},
            {value=>'null', filtered_value=>undef},
            {value=>'[1,2,3]', filtered_value=>[1,2,3]},
            {value=>'"foo"', filtered_value=>'foo'},
            {value=>'"foo', valid=>0, summary=>'Invalid JSON, missing closing quote'},
            {value=>{}, valid=>0, summary=>'Will become something like "HASH(0x560142d4e5e8)" and fail because it is not valid JSON'},
            #{value=>undef, valid=>0, summary=>'Will decode empty string and fail because empty string is not valid JSON'},
        ],
    };
}

sub filter {
    my %args = @_;

    my $dt = $args{data_term};

    my $res = {};

    $res->{modules}{"JSON::MaybeXS"} = 0;
    $res->{expr_filter} = join(
        "",
        "do { my \$tmp = $dt; my \$decoded; eval { \$decoded = JSON::MaybeXS->new->allow_nonref->decode(\$tmp) }; \$@ ? [\"String is not a valid JSON: \$@\", \$tmp] : [undef, \$decoded] }",
    );

    $res;
}

1;
# ABSTRACT: Decode from JSON

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Filter::perl::JSON::decode - Decode from JSON

=head1 VERSION

This document describes version 0.007 of Data::Sah::Filter::perl::JSON::decode (from Perl distribution Sah-Schemas-JSON), released on 2022-11-15.

=head1 SYNOPSIS

=head2 Using in Sah schema's C<prefilters> (or C<postfilters>) clause

 ["str","prefilters",[["JSON::decode"]]]

=head2 Using with L<Data::Sah>:

 use Data::Sah qw(gen_validator);
 
 my $schema = ["str","prefilters",[["JSON::decode"]]];
 my $validator = gen_validator($schema);
 if ($validator->($some_data)) { print 'Valid!' }

=head2 Using with L<Data::Sah:Filter> directly:

 use Data::Sah::Filter qw(gen_filter);

 my $filter = gen_filter([["JSON::decode"]]);
 # $errmsg will be empty/undef when filtering succeeds
 my ($errmsg, $filtered_value) = $filter->($some_data);

=head2 Sample data and filtering results

 "" # INVALID (String is not a valid JSON: malformed JSON string, neither tag, array, object, number, string or atom, at character offset 0 (before "(end of string)") at (eval 2368) line 8. ), unchanged (Empty string is not valid JSON)
 "null" # valid, becomes undef
 "[1,2,3]" # valid, becomes [1,2,3]
 "\"foo\"" # valid, becomes "foo"
 "\"foo" # INVALID (String is not a valid JSON: unexpected end of string while parsing JSON string, at character offset 4 (before "(end of string)") at (eval 2372) line 8. ), unchanged (Invalid JSON, missing closing quote)
 {} # INVALID (String is not a valid JSON: malformed JSON string, neither tag, array, object, number, string or atom, at character offset 0 (before "HASH(0x559dffd6f0a8)") at (eval 2373) line 8. ), unchanged (Will become something like "HASH(0x560142d4e5e8)" and fail because it is not valid JSON)

=for Pod::Coverage ^(meta|filter)$

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-Schemas-JSON>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-Schemas-JSON>.

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

This software is copyright (c) 2022, 2021 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sah-Schemas-JSON>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
