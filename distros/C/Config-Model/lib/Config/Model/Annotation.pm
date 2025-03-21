#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::Annotation 2.155;

use Mouse;
use English;
use Mouse::Util::TypeConstraints;

use Path::Tiny;
use Data::Dumper;

use Config::Model::TypeConstraints;
use Config::Model::Exception;
use Config::Model::Node;
use Config::Model::ObjTreeScanner;

use strict ;
use warnings;

use Carp qw/croak confess cluck/;

#my $logger = get_logger("Annotation") ;

has 'instance' => ( is => 'ro', isa => 'Config::Model::Instance', required => 1 );
has 'config_class_name' => ( is => 'ro', isa => 'Str', required => 1 );
has 'file' => ( is => 'ro', isa => 'Path::Tiny', lazy => 1, builder => '_set_file' );
has 'dir' => ( is => 'ro', isa => 'Path::Tiny', lazy => 1, builder => '_set_dir' );

has 'root_dir' => (
    is => 'ro',
    isa => 'Config::Model::TypeContraints::Path',
    coerce => 1
);

sub _set_file {
    my $self = shift;
    return $self->dir->child( $self->config_class_name . '-note.pl');
}

sub _set_dir {
    my $self = shift;
    return
          $self->root_dir ? $self->root_dir->child('config-model')
        : $EUID           ? path("/var/lib/config-model")
        :                   path("~/.config-model");
}

sub save {
    my $self = shift;

    my $dir = $self->dir;
    $dir->mkpath;
    my $h    = $self->get_annotation_hash;
    $self->file->spew_utf8( Dumper($h) );
}

sub get_annotation_hash {
    my $self = shift;

    my %data;
    my $scanner = Config::Model::ObjTreeScanner->new(
        leaf_cb         => \&my_leaf_cb,
        hash_element_cb => \&my_hash_element_cb,
        list_element_cb => \&my_list_element_cb,
        node_element_cb => \&my_node_element_cb,
        fallback        => 'all',
    );
    my $root = $self->instance->config_root;

    $scanner->scan_node( \%data, $root );
    return \%data;
}

# WARNING: not a method
sub my_hash_element_cb {
    my ( $scanner, $data_ref, $node, $element_name, @keys ) = @_;

    # custom code using $data_ref
    store_note_in_data( $data_ref, $node->fetch_element($element_name) );

    # resume exploration
    map { $scanner->scan_hash( $data_ref, $node, $element_name, $_ ) } @keys;
}

# WARNING: not a method
sub my_node_element_cb {
    my ( $scanner, $data_ref, $node, $element_name, $key, $contained_node ) = @_;

    # your custom code using $data_ref
    store_note_in_data( $data_ref, $contained_node );

    # explore next node
    $scanner->scan_node( $data_ref, $contained_node );
}

# WARNING: not a method
sub my_list_element_cb {
    my ( $scanner, $data_ref, $node, $element_name, @idx ) = @_;

    # custom code using $data_ref
    store_note_in_data( $data_ref, $node->fetch_element($element_name) );

    # resume exploration (if needed)
    map { $scanner->scan_list( $data_ref, $node, $element_name, $_ ) } @idx;

    # note: scan_list and scan_hash are equivalent
}

# WARNING: not a method
sub my_leaf_cb {
    my ( $scanner, $data_ref, $node, $element_name, $index, $leaf_object ) = @_;
    store_note_in_data( $data_ref, $leaf_object );
}

# WARNING: not a method
sub store_note_in_data {
    my ( $data_ref, $obj ) = @_;

    my $note = $obj->annotation;
    return unless $note;

    my $key = $obj->location;
    $data_ref->{$key} = $note;
}

sub load {
    my $self = shift;
    my $f    = $self->file;
    return unless $f->exists;
    my $hash = do "./$f" || croak "can't do $f:$!";
    my $root = $self->instance->config_root;

    foreach my $path ( keys %$hash ) {
        my $obj = eval { $root->grab( step => $path, autoadd => 0 ) };
        next if $@;    # skip annotation of unknown elements
        $obj->annotation( $hash->{$path} );
    }
}

no Mouse;

__PACKAGE__->meta->make_immutable;

1;

# ABSTRACT: Read and write configuration annotations

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::Annotation - Read and write configuration annotations

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 use Config::Model ;

 # define configuration tree object
 my $model = Config::Model->new ;
 $model ->create_config_class (
    name => "MyClass",
    element => [
        [qw/foo bar/] => {
            type => 'leaf',
            value_type => 'string'
        },
        baz => {
            type => 'hash',
            index_type => 'string' ,
            cargo => {
                type => 'leaf',
                value_type => 'string',
            },
        },

    ],
 ) ;

 my $inst = $model->instance(root_class_name => 'MyClass' );

 my $root = $inst->config_root ;

 # put some data in config tree the hard way
 $root->fetch_element('foo')->store('yada') ;
 $root->fetch_element('baz')->fetch_with_id('en')->store('hello') ;

 # put annotation the hard way
 $root->fetch_element('foo')->annotation('english') ;
 $root->fetch_element('baz')->fetch_with_id('en')->annotation('also english') ;

 # put more data the easy way
 my $steps = 'baz:fr=bonjour#french baz:hr="dobar dan"#croatian';
 $root->load( steps => $steps ) ;

 # dump resulting tree with annotations
 print $root->dump_tree;

 # save annotations
 my $annotate_saver = Config::Model::Annotation
  -> new (
          config_class_name => 'MyClass',
          instance => $inst ,
	  root_dir => '/tmp/', # for test
         ) ;
 $annotate_saver->save ;

 # now check content of /tmp/config-model/MyClass-note.pl

=head1 DESCRIPTION

This module provides an object that read and write annotations (a bit
like comments) to and from a configuration tree and save them in a
file (not configuration file). This module can be used to save
annotation for configuration files that do not support comments.

THis module should not be used for configuration files that support
comments.

Depending on the effective id of the process, the annotation is
saved in:

=over

=item *

C<< /var/lib/config-model/<model_name>-note.yml >> for root (EUID == 0)

=item *

C<< ~/.config-model/<model_name>-note.yml >> for normal user (EUID > 0)

=back

=head1 CONSTRUCTOR

Quite standard. The constructor is passed a L<Config::Model::Instance>
object.

=head1 METHODS

=head2 save

Save annotations in a file (See L<DESCRIPTION>)

=head2 load

Loads annotations from a file (See L<DESCRIPTION>)

=head1 CAVEATS

This module is currently not used.

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model>,
L<Config::Model::Node>,
L<Config::Model::Loader>,
L<Config::Model::Searcher>,
L<Config::Model::Value>,

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
