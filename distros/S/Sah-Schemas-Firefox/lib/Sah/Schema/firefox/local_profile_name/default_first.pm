package Sah::Schema::firefox::local_profile_name::default_first;

use strict;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2023-06-14'; # DATE
our $DIST = 'Sah-Schemas-Firefox'; # DIST
our $VERSION = '0.008'; # VERSION

our $schema = ["firefox::local_profile_name" => {
    summary => 'Firefox profile name, must exist in local Firefox installation, default to first',
    'x.perl.default_value_rules' => ['Firefox::first_local_profile_name'],
    description => <<'_',

This is like `firefox::local_profile_name` schema, but adds a default value rule
to pick the first profile in the local Firefox installation.

_
    examples => [
        {
            value   => '',
            valid   => 0,
            test    => 0,
        },
        {
            summary => 'Assuming the profile named "default" exists in local Firefox installation and is the first one',
            value   => 'default',
            valid   => 1,
            test    => 0,
        },
    ],
}];

1;
# ABSTRACT: Firefox profile name, must exist in local Firefox installation, default to first

__END__

=pod

=encoding UTF-8

=head1 NAME

Sah::Schema::firefox::local_profile_name::default_first - Firefox profile name, must exist in local Firefox installation, default to first

=head1 VERSION

This document describes version 0.008 of Sah::Schema::firefox::local_profile_name::default_first (from Perl distribution Sah-Schemas-Firefox), released on 2023-06-14.

=head1 SYNOPSIS

=head2 Sample data and validation results against this schema

 ""  # INVALID

 "default"  # valid (Assuming the profile named "default" exists in local Firefox installation and is the first one)

=head2 Using with Data::Sah

To check data against this schema (requires L<Data::Sah>):

 use Data::Sah qw(gen_validator);
 my $validator = gen_validator("firefox::local_profile_name::default_first*");
 say $validator->($data) ? "valid" : "INVALID!";

The above schema returns a boolean result (true if data is valid, false if
otherwise). To return an error message string instead (empty string if data is
valid, a non-empty error message otherwise):

 my $validator = gen_validator("firefox::local_profile_name::default_first", {return_type=>'str_errmsg'});
 my $errmsg = $validator->($data);
 
 # a sample valid data
 $data = "default";
 my $errmsg = $validator->($data); # => "No such Firefox profile 'default'"
 
 # a sample invalid data
 $data = "";
 my $errmsg = $validator->($data); # => "No such Firefox profile ''"

Often a schema has coercion rule or default value, so after validation the
validated value is different. To return the validated (set-as-default, coerced,
prefiltered) value:

 my $validator = gen_validator("firefox::local_profile_name::default_first", {return_type=>'str_errmsg+val'});
 my $res = $validator->($data); # [$errmsg, $validated_val]
 
 # a sample valid data
 $data = "default";
 my $res = $validator->($data); # => ["No such Firefox profile 'default'","default"]
 
 # a sample invalid data
 $data = "";
 my $res = $validator->($data); # => ["No such Firefox profile ''",""]

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
     state $validator = gen_validator("firefox::local_profile_name::default_first*");
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
             schema => ['firefox::local_profile_name::default_first*'],
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

 % validate-with-sah '"firefox::local_profile_name::default_first*"' '"data..."'

C<validate-with-sah> has several options for, e.g. validating multiple data,
showing the generated validator code (Perl/JavaScript/etc), or loading
schema/data from file. See its manpage for more details.


=head2 Using with Type::Tiny

To create a type constraint and type library from a schema:

 package My::Types {
     use Type::Library -base;
     use Type::FromSah qw( sah2type );

     __PACKAGE__->add_type(
         sah2type('firefox::local_profile_name::default_first*', name=>'FirefoxLocalProfileNameDefaultFirst')
     );
 }

 use My::Types qw(FirefoxLocalProfileNameDefaultFirst);
 FirefoxLocalProfileNameDefaultFirst->assert_valid($data);

=head1 DESCRIPTION

This is like C<firefox::local_profile_name> schema, but adds a default value rule
to pick the first profile in the local Firefox installation.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Sah-Schemas-Firefox>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Sah-Schemas-Firefox>.

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

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sah-Schemas-Firefox>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
