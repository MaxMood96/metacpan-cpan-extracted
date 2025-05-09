package Dist::Zilla::Plugin::PERLANCAR::EnsurePrereqToSpec;

use 5.010001;
use strict;
use warnings;

use Moose;
use namespace::autoclean;

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2022-02-16'; # DATE
our $DIST = 'Dist-Zilla-Plugin-PERLANCAR-EnsurePrereqToSpec'; # DIST
our $VERSION = '0.064'; # VERSION

with (
    'Dist::Zilla::Role::AfterBuild',
    'Dist::Zilla::Role::Rinci::CheckDefinesMeta',
    'Dist::Zilla::Role::ModuleMetadata',
    'Dist::Zilla::Role::FileFinderUser' => {
        default_finders => [':InstallModules'],
    },
);

sub _prereq_check {
    my ($self, $prereqs_hash, $mod, $wanted_phase, $wanted_rel) = @_;

    #use DD; dd $prereqs_hash;

    my $num_any = 0;
    my $num_wanted = 0;
    for my $phase (keys %$prereqs_hash) {
        for my $rel (keys %{ $prereqs_hash->{$phase} }) {
            if (exists $prereqs_hash->{$phase}{$rel}{$mod}) {
                $num_any++;
                $num_wanted++ if $phase eq $wanted_phase && $rel eq $wanted_rel;
            }
        }
    }
    ($num_any, $num_wanted);
}

sub _prereq_only_in {
    my ($self, $prereqs_hash, $mod, $wanted_phase, $wanted_rel) = @_;

    my ($num_any, $num_wanted) = $self->_prereq_check(
        $prereqs_hash, $mod, $wanted_phase, $wanted_rel,
    );
    $num_wanted == 1 && $num_any == 1;
}

sub _has_prereq {
    my ($self, $prereqs_hash, $mod, $wanted_phase, $wanted_rel) = @_;

    my ($num_any, $num_wanted) = $self->_prereq_check(
        $prereqs_hash, $mod, $wanted_phase, $wanted_rel,
    );
    $num_wanted == 1;
}

sub _prereq_none {
    my ($self, $prereqs_hash, $mod) = @_;

    my ($num_any, $num_wanted) = $self->_prereq_check(
        $prereqs_hash, $mod, 'whatever', 'whatever',
    );
    $num_any == 0;
}

my $_cache_packages;
sub _module_in_cur_dist {
    my ($self, $mod) = @_;

    unless ($_cache_packages) {
        $_cache_packages = {};
        for my $file (@{ $self->found_files }) {
            $self->log_fatal([ 'Could not decode %s: %s', $file->name, $file->added_by ])
                if $file->can('encoding') and $file->encoding eq 'bytes';

            my @packages = $self->module_metadata_for_file($file)->packages_inside;
            $_cache_packages->{$_}++ for @packages;
        }
    }
    $_cache_packages->{$mod};
}

sub after_build {
    my $self = shift;

    my $prereqs_hash = $self->zilla->prereqs->as_string_hash;
    my $curdist = $self->zilla->name;

    # Rinci
    if ($self->check_dist_defines_rinci_meta || -f ".tag-implements-Rinci") {
        $self->log_fatal(["Dist defines Rinci metadata or implements Rinci, but there is no prereq phase=develop rel=x_spec to Rinci"])
            unless $self->_prereq_only_in($prereqs_hash, "Rinci", "develop", "x_spec") || $self->_module_in_cur_dist('Rinci');
    } else {
        $self->log_fatal(["Dist does not define Rinci metadata, but there is a phase=develop rel=xpec prereq to Rinci"])
            if $self->_has_prereq($prereqs_hash, "Rinci", "develop", "x_spec");
    }

    # ColorTheme
    if (grep { $_->name =~ m!(?:\A|/)ColorTheme/.+\.pm! } @{ $self->found_files }) {
        $self->log_fatal(["Dist has ColorTheme/* .pm file but there is no prereq phase=develop, rel=x_spec to ColorTheme"])
            unless $self->_prereq_only_in($prereqs_hash, "ColorTheme", "develop", "x_spec") || $self->_module_in_cur_dist('ColorTheme');
    } else {
        # other dists can actually declare following the spec

        #$self->log_fatal(["Dist does not have ColorTheme/* .pm file, but there is a phase=develop rel=xpec prereq to ColorTheme"])
        #    if $self->_has_prereq($prereqs_hash, "ColorTheme", "develop", "x_spec");
    }

    # BorderStyle
    if (grep { $_->name =~ m!(?:\A|/)BorderStyle/.+\.pm! } @{ $self->found_files }) {
        $self->log_fatal(["Dist has BorderStyle/* .pm file but there is no prereq phase=develop, rel=x_spec to BorderStyle"])
            unless $self->_prereq_only_in($prereqs_hash, "BorderStyle", "develop", "x_spec") || $self->_module_in_cur_dist('BorderStyle');
    } else {
        # other dists can actually declare following the spec, e.g.
        # Text-Table-TinyBorderStyle, etc.

        #$self->log_fatal(["Dist does not have BorderStyle/* .pm file, but there is a phase=develop rel=xpec prereq to BorderStyle"])
        #    if $self->_has_prereq($prereqs_hash, "BorderStyle", "develop", "x_spec");
    }

}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Ensure prereq to spec modules

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::PERLANCAR::EnsurePrereqToSpec - Ensure prereq to spec modules

=head1 VERSION

This document describes version 0.064 of Dist::Zilla::Plugin::PERLANCAR::EnsurePrereqToSpec (from Perl distribution Dist-Zilla-Plugin-PERLANCAR-EnsurePrereqToSpec), released on 2022-02-16.

=head1 SYNOPSIS

In C<dist.ini>:

 [PERLANCAR::EnsurePrereqToSpec]

=head1 DESCRIPTION

I like to specify prerequisite to spec modules such as L<Rinci>, L<Riap>,
L<Sah>, L<Setup>, etc as (phase=develop, rel=x_spec) dependency, to express that
a distribution conforms to such specification(s).

Currently only these spec is checked:

=over

=item * L<Rinci>

When a package contains Rinci metadata (C<%SPEC>).

=item * L<ColorTheme>

When there is a ColorTheme/* source files.

=item * L<BorderStyle>

When there is a BorderStyle/* source files.

=back

=for Pod::Coverage .+

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Dist-Zilla-Plugin-PERLANCAR-EnsurePrereqToSpec>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Dist-Zilla-Plugin-PERLANCAR-EnsurePrereqToSpec>.

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
L<Dist::Zilla::PluginBundle::Author::PERLANCAR>, and sometimes one or two other
Dist::Zilla plugin and/or Pod::Weaver::Plugin. Any additional steps required
beyond that are considered a bug and can be reported to me.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022, 2020, 2018, 2017, 2016, 2015 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-PERLANCAR-EnsurePrereqToSpec>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
