package Sah::Schema::date::month_name::id;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-10-20'; # DATE
our $DIST = 'Sah-Schemas-Date-ID'; # DIST
our $VERSION = '0.008'; # VERSION

our $schema = [cistr => {
    summary => 'Month name (abbreviated or full, in Indonesian), e.g. "Mar" or "JUNI"',
    in => [
        qw/jan feb mar apr mei jun jul agu sep okt nov des/,
        qw/januari februari maret april juni juli agustus september oktober november desember/,
    ],
    description => <<'_',

See also related schemas for other locales, e.g.
<pm:Sah::Schema::date::month_name::en> (English),
<pm:Sah::Schema::date::month_name::en_or_id> (English/Indonesian), etc.

_
    examples => [
        {value=>'', valid=>0, summary=>'Empty string'},
        {value=>'jan', valid=>1},
        {value=>'FEBRUARI', valid=>1},
        {value=>'march', valid=>0, summary=>'English'},
        {value=>0, valid=>0, summary=>'Not a name'},
        {value=>1, valid=>0, summary=>'Not a name'},
        {value=>12, valid=>0, summary=>'Not a name'},
        {value=>13, valid=>0, summary=>'Not a name'},
    ],
}];

1;

# ABSTRACT: Month name (abbreviated or full, in Indonesian), e.g. "Mar" or "JUNI"

__END__

=pod

=encoding UTF-8

=head1 NAME

Sah::Schema::date::month_name::id - Month name (abbreviated or full, in Indonesian), e.g. "Mar" or "JUNI"

=head1 VERSION

This document describes version 0.008 of Sah::Schema::date::month_name::id (from Perl distribution Sah-Schemas-Date-ID), released on 2022-10-20.

=head1 SYNOPSIS

=head2 Sample data and validation results against this schema

 ""  # INVALID

 "jan"  # valid

 "FEBRUARI"  # valid

 "march"  # INVALID (English)

 0  # INVALID

 1  # INVALID

 12  # INVALID

 13  # INVALID

=head2 Using with Data::Sah

To check data against this schema (requires L<Data::Sah>):

 use Data::Sah qw(gen_validator);
 my $validator = gen_validator("date::month_name::id*");
 say $validator->($data) ? "valid" : "INVALID!";

The above schema returns a boolean result (true if data is valid, false if
otherwise). To return an error message string instead (empty string if data is
valid, a non-empty error message otherwise):

 my $validator = gen_validator("date::month_name::id", {return_type=>'str_errmsg'});
 my $errmsg = $validator->($data);
 
 # a sample valid data
 $data = "jan";
 my $errmsg = $validator->($data); # => ""
 
 # a sample invalid data
 $data = 1;
 my $errmsg = $validator->($data); # => "Must be one of [\"jan\",\"feb\",\"mar\",\"apr\",\"mei\",\"jun\",\"jul\",\"agu\",\"sep\",\"okt\",\"nov\",\"des\",\"januari\",\"februari\",\"maret\",\"april\",\"juni\",\"juli\",\"agustus\",\"september\",\"oktober\",\"november\",\"desember\"]"

Often a schema has coercion rule or default value, so after validation the
validated value is different. To return the validated (set-as-default, coerced,
prefiltered) value:

 my $validator = gen_validator("date::month_name::id", {return_type=>'str_errmsg+val'});
 my $res = $validator->($data); # [$errmsg, $validated_val]
 
 # a sample valid data
 $data = "jan";
 my $res = $validator->($data); # => ["","jan"]
 
 # a sample invalid data
 $data = 1;
 my $res = $validator->($data); # => ["Must be one of [\"jan\",\"feb\",\"mar\",\"apr\",\"mei\",\"jun\",\"jul\",\"agu\",\"sep\",\"okt\",\"nov\",\"des\",\"januari\",\"februari\",\"maret\",\"april\",\"juni\",\"juli\",\"agustus\",\"september\",\"oktober\",\"november\",\"desember\"]",1]

Data::Sah can also create validator that returns a hash of detailed error
message. Data::Sah can even create validator that targets other language, like
JavaScript, from the same schema. Other things Data::Sah can do: show source
code for validator, generate a validator code with debug comments and/or log
statements, generate human text from schema. See its documentation for more
details.

=head2 Using with Params::Sah

To validate function parameters against this schema (requires L<Params::Sah>):

 use Params::Sah qw(gen_validator);

 sub myfunc {
     my @args = @_;
     state $validator = gen_validator("date::month_name::id*");
     $validator->(\@args);
     ...
 }

=head2 Using with Perinci::CmdLine::Lite

To specify schema in L<Rinci> function metadata and use the metadata with
L<Perinci::CmdLine> (L<Perinci::CmdLine::Lite>) to create a CLI:

 # in lib/MyApp.pm
 package
   MyApp;
 our %SPEC;
 $SPEC{myfunc} = {
     v => 1.1,
     summary => 'Routine to do blah ...',
     args => {
         arg1 => {
             summary => 'The blah blah argument',
             schema => ['date::month_name::id*'],
         },
         ...
     },
 };
 sub myfunc {
     my %args = @_;
     ...
 }
 1;

 # in myapp.pl
 package
   main;
 use Perinci::CmdLine::Any;
 Perinci::CmdLine::Any->new(url=>'/MyApp/myfunc')->run;

 # in command-line
 % ./myapp.pl --help
 myapp - Routine to do blah ...
 ...

 % ./myapp.pl --version

 % ./myapp.pl --arg1 ...


=head2 Using with Type::Tiny

To create a type constraint and type library from a schema:

 package My::Types {
     use Type::Library -base;
     use Type::FromSah qw( sah2type );

     __PACKAGE__->add_type(
         sah2type('$sch_name*', name=>'DateMonthNameId')
     );
 }

 use My::Types qw(DateMonthNameId);
 DateMonthNameId->assert_valid($data);

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-Schemas-Date-ID>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-Schemas-Date-ID>.

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
