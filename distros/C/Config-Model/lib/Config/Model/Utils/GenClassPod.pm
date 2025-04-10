#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Utils::GenClassPod 2.155;

# ABSTRACT: generate pod documentation from configuration models

use strict;
use warnings;
use 5.020;
use parent qw(Exporter);

use feature qw/postderef signatures/;
no warnings qw/experimental::postderef experimental::signatures/;

# function is used in one liner script, so auto export is easier to use
## no critic (Modules::ProhibitAutomaticExportation)
our @EXPORT = qw(gen_class_pod);

use Path::Tiny ;
use Config::Model ;             # to generate doc

sub gen_class_pod (@models) {
    # make sure that doc is generated from models from ./lib and not
    # installed models
    my $local_model_dir = path("lib/Config/Model/models") -> absolute;
    my $cm = Config::Model -> new(model_dir => $local_model_dir->stringify ) ;
    my %done;

    if (not scalar @models) {
        @models = map { /^\s*model\s*=\s*([\w:-]+)/ ? ($1) : (); }
        map  { $_->lines; }
        map  { $_->children; }
        path ("lib/Config/Model/")->children(qr/\.d$/);
    }

    foreach my $model (@models) {
        # %done avoid generating doc several times (generate_doc scan docs for
        # classes referenced by the model with config_class_name parameter)
        print "Checking doc for model $model\n";
        $cm->load($model) ;
        $cm->generate_doc ($model,'lib', \%done) ;
    }
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Utils::GenClassPod - generate pod documentation from configuration models

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 use Config::Model::Utils::GenClassPod;
 gen_class_pod;

 # or

 gen_class_pod('Foo','Bar',...)

=head1 DESCRIPTION

This module provides a single exported function: C<gen_class_pod>.

This function scans C<./lib/Config/Model/models/*.d>
and generate pod documentation for each file found there using
L<Config::Model::generate_doc|Config::Model/"generate_doc ( top_class_name , directory , [ \%done ] )">

You can also pass one or more class names. C<gen_class_pod> writes
the documentation for each passed class and all other classes used by
the passed classes.

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
