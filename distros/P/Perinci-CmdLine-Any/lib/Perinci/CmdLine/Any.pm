package Perinci::CmdLine::Any;

use strict;
# IFUNBUILT
# use warnings;
# END IFUNBUILT

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-10-19'; # DATE
our $DIST = 'Perinci-CmdLine-Any'; # DIST
our $VERSION = '0.154'; # VERSION

my %Opts = (
    -prefer_lite => 1,
);

sub import {
    my ($class, %args) = @_;
    $Opts{$_} = $args{$_} for keys %args;
}

sub new {
    my $class = shift;

    my @mods;
    my $env = $ENV{PERINCI_CMDLINE_ANY};
    if ($env) {
        if ($env eq 'classic') {
            $env = 'Perinci::CmdLine::Classic';
        } elsif ($env eq 'lite') {
            $env = 'Perinci::CmdLine::Lite';
        }
        @mods = ($env);
    } elsif ($Opts{-prefer_lite}) {
        @mods = qw(Perinci::CmdLine::Lite Perinci::CmdLine::Classic);
    } else {
        @mods = qw(Perinci::CmdLine::Classic Perinci::CmdLine::Lite);
    }

    for my $i (1..@mods) {
        my $mod = $mods[$i-1];
        (my $modpm = "$mod.pm") =~ s!::!/!g;
        if ($i == @mods) {
            require $modpm;
            return $mod->new(@_);
        } else {
            my $res;
            eval {
                require $modpm;
                $res = $mod->new(@_);
            };
            if ($@) {
                warn "Can't load $mod: $@";
                next;
            } else {
                return $res;
            }
        }
    }
}

1;
# ABSTRACT: Choose Perinci::CmdLine implementation (::Lite or ::Classic)

__END__

=pod

=encoding UTF-8

=head1 NAME

Perinci::CmdLine::Any - Choose Perinci::CmdLine implementation (::Lite or ::Classic)

=head1 VERSION

This document describes version 0.154 of Perinci::CmdLine::Any (from Perl distribution Perinci-CmdLine-Any), released on 2022-10-19.

=head1 SYNOPSIS

In your command-line script (this will pick ::Lite first):

 #!perl
 use Perinci::CmdLine::Any;
 Perinci::CmdLine::Any->new(url => '/Package/func')->run;

In your command-line script (this will pick ::Classic first, and falls back to
::Lite):

 #!perl
 use Perinci::CmdLine::Any -prefer_lite=>0;
 Perinci::CmdLine::Any->new(url => '/Package/func')->run;

=head1 DESCRIPTION

This module lets you use L<Perinci::CmdLine::Lite> or
L<Perinci::CmdLine::Classic>.

If you want to force using a specific class, you can set the
C<PERINCI_CMDLINE_ANY> environment variable, e.g. the command below will only
try to use Perinci::CmdLine::Classic:

 % PERINCI_CMDLINE_ANY=Perinci::CmdLine::Classic yourapp.pl
 % PERINCI_CMDLINE_ANY=classic yourapp.pl

If you want to prefer to Perinci::CmdLine::Classic (but user will still be able
to override using C<PERINCI_CMDLINE_ANY>):

 use Perinci::CmdLine::Any -prefer_lite => 0;

=for Pod::Coverage ^(new)$

=head1 ENVIRONMENT

=head2 PERINCI_CMDLINE_ANY => str

Either specify module name, or C<lite> or C<classic>.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Perinci-CmdLine-Any>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Perinci-CmdLine-Any>.

=head1 SEE ALSO

L<Perinci::CmdLine::Lite>, L<Perinci::CmdLine::Classic>

Another alternative backend, but not available through Perinci::CmdLine::Any
since it works by generating script instead: L<Perinci::CmdLine::Inline>

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

This software is copyright (c) 2022, 2021, 2019, 2017, 2016, 2015, 2014 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perinci-CmdLine-Any>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
