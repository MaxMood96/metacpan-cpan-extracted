package Sah::Schema::perl::pod_filename;

use strict;
use warnings;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2024-02-16'; # DATE
our $DIST = 'Sah-SchemaBundle-Perl'; # DIST
our $VERSION = '0.050'; # VERSION

our $schema = [str => {
    summary => 'A .pod filename, e.g. /path/Foo.pod',
    description => <<'_',

Use this schema if you want to accept a filesystem path containing Perl POD. The
value of this schema is in the convenience of CLI completion, as well as
coercion from POD name.

String containing filename of a Perl .pod file. For convenience, when value is
in the form of:

    Foo
    Foo.pod
    Foo::Bar
    Foo/Bar
    Foo/Bar.pod

and a matching .pod file is found in `@INC`, then it will be coerced (converted)
into the filesystem path of that .pod file, e.g.:

    /home/ujang/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/Foo/Bar.pod

To prevent such coercion, you can use prefixing path, e.g.:

    ./Foo::Bar
    ../Foo/Bar
    /path/to/Foo/Bar

This schema comes with convenience completion too.

_
    'x.perl.coerce_rules' => [
        'From_str::convert_perl_pod_to_path',
    ],
    'x.completion' => sub {
        require Complete::File;
        require Complete::Module;
        require Complete::Util;

        my %args = @_;
        my $word = $args{word};

        my @answers;
        push @answers, Complete::File::complete_file(word => $word);
        if ($word =~ m!\A\w*((?:::|/)\w+)*\z!) {
            push @answers, Complete::Module::complete_module(
                word => $word, find_pod=>1, find_pm=>0, find_pmc=>0);
        }

        Complete::Util::combine_answers(@answers);
    },

}];

1;
# ABSTRACT: A .pod filename, e.g. /path/Foo.pod

__END__

=pod

=encoding UTF-8

=head1 NAME

Sah::Schema::perl::pod_filename - A .pod filename, e.g. /path/Foo.pod

=head1 VERSION

This document describes version 0.050 of Sah::Schema::perl::pod_filename (from Perl distribution Sah-SchemaBundle-Perl), released on 2024-02-16.

=head1 SAH SCHEMA DEFINITION

 [
   "str",
   {
     "summary" => "A .pod filename, e.g. /path/Foo.pod",
     "x.completion" => sub {
       package Sah::Schema::perl::pod_filename;
       use warnings;
       use strict;
       no feature ':all';
       use feature ':5.10';
       require Complete::File;
       require Complete::Module;
       require Complete::Util;
       my(%args) = @_;
       my $word = $args{'word'};
       my @answers;
       push @answers, Complete::File::complete_file('word', $word);
       if ($word =~ m[\A\w*((?:::|/)\w+)*\z]) {
       push @answers, Complete::Module::complete_module('word', $word, 'find_pod', 1, 'find_pm', 0, 'find_pmc', 0);
       }
       Complete::Util::combine_answers(@answers);
     },
     "x.perl.coerce_rules" => ["From_str::convert_perl_pod_to_path"],
   },
 ]

Base type: L<str|Data::Sah::Type::str>

Used completion: L<CODE(0x55f2611d8590)|Perinci::Sub::XCompletion::CODE(0x55f2611d8590)>

=head1 SYNOPSIS

=head2 Using with Data::Sah

To check data against this schema (requires L<Data::Sah>):

 use Data::Sah qw(gen_validator);
 my $validator = gen_validator("perl::pod_filename*");
 say $validator->($data) ? "valid" : "INVALID!";

The above validator returns a boolean result (true if data is valid, false if
otherwise). To return an error message string instead (empty string if data is
valid, a non-empty error message otherwise):

 my $validator = gen_validator("perl::pod_filename", {return_type=>'str_errmsg'});
 my $errmsg = $validator->($data);

Often a schema has coercion rule or default value rules, so after validation the
validated value will be different from the original. To return the validated
(set-as-default, coerced, prefiltered) value:

 my $validator = gen_validator("perl::pod_filename", {return_type=>'str_errmsg+val'});
 my $res = $validator->($data); # [$errmsg, $validated_val]

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
     state $validator = gen_validator("perl::pod_filename*");
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
             schema => ['perl::pod_filename*'],
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

=head2 Using on the CLI with validate-with-sah

To validate some data on the CLI, you can use L<validate-with-sah> utility.
Specify the schema as the first argument (encoded in Perl syntax) and the data
to validate as the second argument (encoded in Perl syntax):

 % validate-with-sah '"perl::pod_filename*"' '"data..."'

C<validate-with-sah> has several options for, e.g. validating multiple data,
showing the generated validator code (Perl/JavaScript/etc), or loading
schema/data from file. See its manpage for more details.


=head2 Using with Type::Tiny

To create a type constraint and type library from a schema (requires
L<Type::Tiny> as well as L<Type::FromSah>):

 package My::Types {
     use Type::Library -base;
     use Type::FromSah qw( sah2type );

     __PACKAGE__->add_type(
         sah2type('perl::pod_filename*', name=>'PerlPodFilename')
     );
 }

 use My::Types qw(PerlPodFilename);
 PerlPodFilename->assert_valid($data);

=head1 DESCRIPTION

Use this schema if you want to accept a filesystem path containing Perl POD. The
value of this schema is in the convenience of CLI completion, as well as
coercion from POD name.

String containing filename of a Perl .pod file. For convenience, when value is
in the form of:

 Foo
 Foo.pod
 Foo::Bar
 Foo/Bar
 Foo/Bar.pod

and a matching .pod file is found in C<@INC>, then it will be coerced (converted)
into the filesystem path of that .pod file, e.g.:

 /home/ujang/perl5/perlbrew/perls/perl-5.24.0/lib/site_perl/5.24.0/Foo/Bar.pod

To prevent such coercion, you can use prefixing path, e.g.:

 ./Foo::Bar
 ../Foo/Bar
 /path/to/Foo/Bar

This schema comes with convenience completion too.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-SchemaBundle-Perl>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-SchemaBundle-Perl>.

=head1 SEE ALSO

L<Sah::Schema::perl::filename>

L<Sah::Schema::perl::pod_or_pm_filename>

L<Sah::Schema::perl::pm_filename>

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

This software is copyright (c) 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sah-SchemaBundle-Perl>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
