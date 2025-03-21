package Dist::Zilla::Plugin::Module::Features;

use 5.010001;
use strict;
use warnings;

use Moose;
with 'Dist::Zilla::Role::BeforeBuild';
with 'Dist::Zilla::Role::AfterBuild';
with 'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [':InstallModules'],
};
with 'Dist::Zilla::Role::FileGatherer';
#with 'Dist::Zilla::Role::ModuleFeatures::CheckDefinesOrDeclaresFeatures';
with 'Dist::Zilla::Role::PrereqSource';
with 'Dist::Zilla::Role::RequireFromBuild';
use namespace::autoclean;

use File::Spec::Functions qw(catfile);
use PMVersions::Util qw(version_from_pmversions);

our $AUTHORITY = 'cpan:PERLANCAR'; # AUTHORITY
our $DATE = '2021-11-29'; # DATE
our $DIST = 'Dist-Zilla-Plugin-Module-Features'; # DIST
our $VERSION = '0.005'; # VERSION

my %feature_decls; # key = module name
my %features_defs; # key = module name
my @definer_modules;
sub _load_modules {
    my $self = shift;

    for my $file (@{ $self->found_files }) {
        next unless $file->name =~ m!^lib/(.+\.pm)$!;
        my $mod_pm = $1;
        $self->require_from_build($mod_pm);
        (my $mod = $mod_pm) =~ s/\.pm$//; $mod =~ s!/!::!g;
        no strict 'refs'; ## no critic: TestingAndDebugging::RequireUseStrict
        my $feature_decl = \%{"$mod\::FEATURES"};
        if (keys %$feature_decl) {
            $feature_decls{$mod} = $feature_decl;
        }
        if ($mod =~ /\AModule::Features::/) {
            my $features_def = \%{"$mod\::FEATURES_DEF"};
            if (keys %$features_def) {
                $features_defs{$mod} = $features_def;
            } else {
                $self->log_fatal(["$mod does not contain features definition (\%FEATURES_DEF)"]);
            }
        }
    }
    #use DD; dd \%feature_decls;
    for my $mod (sort keys %feature_decls) {
        my $feature_decl = $feature_decls{$mod};
        for my $fset (sort keys %{$feature_decl->{features}}) {
            my $defmod = "Module::Features::$fset";
            push @definer_modules, $defmod unless grep { $_ eq $defmod } @definer_modules;
        }
    }

    #use DD; dd \%features_defs; dd \%feature_decls;
}

# either provide filename or filename+filecontent
sub _get_abstract_from_def_or_decl {
    my ($self, $filename, $filecontent) = @_;

    $self->log_debug("Trying to get abstract from ".($filename ? "file $filename" : "file content"));

    local @INC = @INC;
    unshift @INC, 'lib';

    unless (defined $filecontent) {
        $filecontent = do {
            open my($fh), "<", $filename or die "Can't open $filename: $!";
            local $/;
            ~~<$fh>;
        };
    }

    unless ($filecontent =~ m{^#[ \t]*ABSTRACT:[ \t]*([^\n]*)[ \t]*$}m) {
        $self->log_debug(["Skipping %s: no # ABSTRACT", $filename]);
        return undef; ## no critic: Subroutines::ProhibitExplicitReturnUndef
    }

    my $abstract = $1;
    if ($abstract =~ /\S/) {
        $self->log_debug(["Skipping %s: Abstract already filled (%s)", $filename, $abstract]);
        return $abstract;
    }

    my $pkg;
    if (!defined($filecontent)) {
        (my $mod_p = $filename) =~ s!^lib/!!;
        require $mod_p;

        # find out the package of the file
        ($pkg = $mod_p) =~ s/\.pm\z//; $pkg =~ s!/!::!g;
    } else {
        eval $filecontent; ## no critic: BuiltinFunctions::ProhibitStringyEval
        die if $@;
        if ($filecontent =~ /\bpackage\s+(\w+(?:::\w+)*)/s) {
            $pkg = $1;
        } else {
            die "Can't extract package name from file content";
        }
    }

    my $summary;
    no strict 'refs'; ## no critic: TestingAndDebugging::RequireUseStrict
    if (defined($summary = ${"$pkg\::FEATURES"}{summary})) {
        $self->log_debug("Using abstract from declaration summary: $summary");
        return $summary;
    } elsif (defined($summary = ${"$pkg\::FEATURES_DEF"}{summary})) {
        $self->log_debug("Using abstract from features definition summary: $summary");
        return $summary;
    }
    undef;
}

# dzil also wants to get abstract for main module to put in dist's
# META.{yml,json}
sub before_build {
   my $self  = shift;
   my $name  = $self->zilla->name;
   my $class = $name; $class =~ s{ [\-] }{::}gmx;
   my $filename = $self->zilla->_main_module_override ||
       catfile( 'lib', split m{ [\-] }mx, "${name}.pm" );

   $self->_load_modules;

   $filename or die 'No main module specified';
   -f $filename or die "Path ${filename} does not exist or not a file";
   my $abstract = $self->_get_abstract_from_def_or_decl($filename);
   return unless $abstract;

   $self->zilla->abstract($abstract);
   return;
}

sub register_prereqs {
    my ($self) = @_;
    $self->zilla->register_prereqs(
        {
            type  => 'requires',
            phase => 'develop',
        },
        'Test::Module::Features' => version_from_pmversions('Test::Module::Features') // '0.001',
    );

    for my $defmod (@definer_modules) {
        $self->zilla->register_prereqs(
            {
                type  => 'x_features_from',
                phase => 'develop',
            },
            $defmod => version_from_pmversions($defmod) // '0',
        );
    }
}

sub gather_files {
    my ($self) = @_;

    #return unless $self->check_dist_defines_module_features;

    my $filename = "xt/release/module-features.t";
    my $filecontent = <<_;
#!perl

# This file was automatically generated by ${\(__PACKAGE__)}.

use Test::More;

eval "use Test::Module::Features 0.001";
plan skip_all => "Test::Module::Features 0.001+ required for testing module features"
  if \$@;

module_features_in_all_modules_ok();
_

    $self->log(["Adding %s ...", $filename]);
    require Dist::Zilla::File::InMemory;
    $self->add_file(
        Dist::Zilla::File::InMemory->new({
            name => $filename,
            content => $filecontent,
        })
      );
}

sub after_build {
    my $self = shift;

    my $prereqs_hash = $self->zilla->prereqs->as_string_hash;

    # XXX only require spec prereq to Module::Features when there's a module
    # that has feature set specification or features declaration

    # check that Module::Features is mentioned phase=develop rel=x_spec
    unless (exists $prereqs_hash->{develop}{x_spec}{'Module::Features'}) {
        unless (-f "lib/Module/Features.pm") { # exception for Module-Features dist
            $self->log_fatal(["Module::Features not specified as prerequisite (phase=develop, rel=x_spec)"]);
        }
    }
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Plugin to use when building Module::Features::* distribution

__END__

=pod

=encoding UTF-8

=head1 NAME

Dist::Zilla::Plugin::Module::Features - Plugin to use when building Module::Features::* distribution

=head1 VERSION

This document describes version 0.005 of Dist::Zilla::Plugin::Module::Features (from Perl distribution Dist-Zilla-Plugin-Module-Features), released on 2021-11-29.

=head1 SYNOPSIS

In F<dist.ini>:

 [Module::Features]

=head1 DESCRIPTION

This plugin is to be used when building C<Module::Features::*> distribution as
well as distribution that has a module that declares features. It currently does
the following:

=over

=item * Create C<xt/release/module-features.t> test file which uses L<Test::Module::Features> to test your features declarations or feature set specifications

=item * Make sure that L<Module::Features> is added as a (phase=develop, rel=x_spec) prerequisite

This is a way to express that the module I<follows the specification> specified
in L<Module::Features>. This recommendation is per Module::Features spec.

=item * For a feature declarer module, make sure that the appropriate C<Module::Features::*> modules are added as (phase=develop, rel=x_features_from) prerequisites

This is a way to express that the module declares features defined in the
associated C<Module::Features::*> modules. This recommendation is per
Module::Features spec.

=back

=for Pod::Coverage .+

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Dist-Zilla-Plugin-Module-Features>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-Dist-Zilla-Plugin-Module-Features>.

=head1 SEE ALSO

L<Module::Features>

L<Pod::Weaver::Plugin::Module::Features>

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

This software is copyright (c) 2021 by perlancar <perlancar@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-Module-Features>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=cut
