package Data::Sah::Filter::perl::Filename::Safe::alphanum_identifier;

use 5.010001;
use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-01-22'; # DATE
our $DIST = 'Data-Sah-FilterBundle-Filename-Safe'; # DIST
our $VERSION = '0.001'; # VERSION

sub meta {
    +{
        v => 1,
        summary => 'Replace characters that are not [A-Za-z0-9_] with underscore (_), avoid digit as first character',
        description => <<'MARKDOWN',

This is just like the `alphanum`
(<pm:Data::Sah::Filter::perl::Filename::Safe::alphanum_identifier>) filter
except with an additional rule: if the first character of the result is a digit
([0-9]) then an underscore prefix is added.

MARKDOWN
        might_fail => 0,
        args => {
        },
        examples => [
            {value => '', filtered_value => ''},
            {value => 'foo', filtered_value => 'foo'},
            {value => '123  456-789.foo.bar', filtered_value => '_123_456_789_foo.bar'},
            {value => 'a123  456-789.foo.bar', filtered_value => 'a123_456_789_foo.bar'},
            {value => '__123  456-789.foo.bar', filtered_value => '__123_456_789_foo.bar'},
        ],
    };
}

sub filter {
    my %fargs = @_;

    my $dt = $fargs{data_term};
    my $gen_args = $fargs{args} // {};

    my $res = {};
    $res->{expr_filter} = join(
        "",
        "do { ", (
            "my \$tmp = $dt; my \$ext; \$tmp =~ s/\\.(\\w+)\\z// and \$ext = \$1; \$tmp =~ s/[^A-Za-z0-9_]+/_/g; \$tmp = \"_\$tmp\" if \$tmp =~ /\\A[0-9]/; defined(\$ext) ? \"\$tmp.\$ext\" : \$tmp",
        ), "}",
    );

    $res;
}

1;
# ABSTRACT: Replace characters that are not [A-Za-z0-9_] with underscore (_), avoid digit as first character

__END__

=pod

=encoding UTF-8

=head1 NAME

Data::Sah::Filter::perl::Filename::Safe::alphanum_identifier - Replace characters that are not [A-Za-z0-9_] with underscore (_), avoid digit as first character

=head1 VERSION

This document describes version 0.001 of Data::Sah::Filter::perl::Filename::Safe::alphanum_identifier (from Perl distribution Data-Sah-FilterBundle-Filename-Safe), released on 2024-01-22.

=head1 SYNOPSIS

=head2 Using in Sah schema's C<prefilters> (or C<postfilters>) clause

 ["str","prefilters",[["Filename::Safe::alphanum_identifier"]]]

=head2 Using with L<Data::Sah>:

 use Data::Sah qw(gen_validator);
 
 my $schema = ["str","prefilters",[["Filename::Safe::alphanum_identifier"]]];
 my $validator = gen_validator($schema);
 if ($validator->($some_data)) { print 'Valid!' }

=head2 Using with L<Data::Sah:Filter> directly:

 use Data::Sah::Filter qw(gen_filter);

 my $filter = gen_filter([["Filename::Safe::alphanum_identifier"]]);
 my $filtered_value = $filter->($some_data);

=head2 Sample data and filtering results

 "" # valid, unchanged
 "foo" # valid, unchanged
 "123  456-789.foo.bar" # valid, becomes "_123_456_789_foo.bar"
 "a123  456-789.foo.bar" # valid, becomes "a123_456_789_foo.bar"
 "__123  456-789.foo.bar" # valid, becomes "__123_456_789_foo.bar"

=for Pod::Coverage ^(meta|filter)$

=head1 DESCRIPTION

This is just like the C<alphanum>
(L<Data::Sah::Filter::perl::Filename::Safe::alphanum_identifier>) filter
except with an additional rule: if the first character of the result is a digit
([0-9]) then an underscore prefix is added.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Data-Sah-FilterBundle-Filename-Safe>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Data-Sah-FilterBundle-Filename-Safe>.

=head1 SEE ALSO

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

This software is copyright (c) 2024 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Data-Sah-FilterBundle-Filename-Safe>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
