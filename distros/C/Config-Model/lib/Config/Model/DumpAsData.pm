#
# This file is part of Config-Model
#
# This software is Copyright (c) 2005-2022 by Dominique Dumont.
#
# This is free software, licensed under:
#
#   The GNU Lesser General Public License, Version 2.1, February 1999
#
package Config::Model::DumpAsData 2.155;

use Carp;
use strict;
use warnings;
use 5.10.1;

use Config::Model::Exception;
use Config::Model::ObjTreeScanner;

sub new {
    bless {}, shift;
}

sub dump_as_data {
    my $self = shift;

    my %args      = @_;
    my $dump_node = delete $args{node}
        || croak "dump_as_data: missing 'node' parameter";
    my $mode = delete $args{mode} // '';
    my $skip_aw = delete $args{skip_auto_write} || '';
    my $auto_v  = delete $args{auto_vivify}     || 0;
    my $ordered_hash_as_list = delete $args{ordered_hash_as_list};
    my $to_boolean = delete $args{to_boolean} // sub {return $_[0] };
    $ordered_hash_as_list = 1 unless defined $ordered_hash_as_list;

    # mode and full_dump params are both accepted
    my $full = delete $args{full_dump} || 0;
    carp "dump_as_data: full_dump parameter is deprecated. Please use 'mode => user' instead"
        if $full;

    my $fetch_mode =
          $full           ? 'user'
        : $mode eq 'full' ? 'user'
        : $mode           ? $mode
        :                   'custom';

    my $std_cb = sub {
        my ( $scanner, $data_r, $obj, $element, $index, $value_obj ) = @_;
        my $v = $value_obj->fetch(mode => $fetch_mode);
        # transform boolean type in boolean object
        $$data_r = $value_obj->value_type eq 'boolean' ? $to_boolean->($v) : $v;
    };

    my $check_list_element_cb = sub {
        my ( $scanner, $data_r, $node, $element_name, @check_items ) = @_;
        my $a_ref = $node->fetch_element($element_name)->get_checked_list;

        # don't store empty checklist
        $$data_r = $a_ref if @$a_ref;
    };

    my $hash_element_cb = sub {
        my ( $scanner, $data_ref, $node, $element_name, @keys ) = @_;

        my $force_write = $node->fetch_element($element_name)->write_empty_value;

        # resume exploration but pass a ref on $data_ref hash element
        # instead of data_ref
        my %h;
        my @res;
        foreach my $k (@keys) {
            my $v;
            $scanner->scan_hash( \$v, $node, $element_name, $k );

            # don't create the key if $v is undef
            if (defined $v or $force_write) {
                $h{$k} = $v;
                push @res , $k, $v;
            }
        } ;

        my $ordered_hash = $node->fetch_element($element_name)->ordered;

        if ( $ordered_hash and $ordered_hash_as_list ) {
            $$data_ref = \@res if @res;
        }
        else {
            $h{'__'.$element_name.'_order'} = \@keys if $ordered_hash and @keys;
            $$data_ref = \%h if scalar %h;
        }
    };

    my $list_element_cb = sub {
        my ( $scanner, $data_ref, $node, $element_name, @idx ) = @_;

        # resume exploration but pass a ref on $data_ref hash element
        # instead of data_ref
        my @a;
        foreach my $i (@idx) {
            my $v;
            $scanner->scan_hash( \$v, $node, $element_name, $i );
            push @a, $v if defined $v;
        }
        $$data_ref = \@a if scalar @a;
    };

    my $node_content_cb = sub {
        my ( $scanner, $data_ref, $node, @element ) = @_;
        my %h;
        foreach my $e (@element) {
            my $v;
            $scanner->scan_element( \$v, $node, $e );
            $h{$e} = $v if defined $v;
        }
        $$data_ref = \%h if scalar %h;
    };

    my $node_element_cb = sub {
        my ( $scanner, $data_ref, $node, $element_name, $key, $next ) = @_;

        return if $skip_aw and $next->is_auto_write_for_type($skip_aw);

        $scanner->scan_node( $data_ref, $next );
    };

    my @scan_args = (
        check      => delete $args{check}      || 'yes',
        fallback   => 'all',
        auto_vivify           => $auto_v,
        list_element_cb       => $list_element_cb,
        check_list_element_cb => $check_list_element_cb,
        hash_element_cb       => $hash_element_cb,
        leaf_cb               => $std_cb,
        node_element_cb       => $node_element_cb,
        node_content_cb       => $node_content_cb,
    );

    my @left = keys %args;
    croak "DumpAsData: unknown parameter:@left" if @left;

    # perform the scan
    my $view_scanner = Config::Model::ObjTreeScanner->new(@scan_args);

    my $obj_type = $dump_node->get_type;
    my $result;
    my $p = $dump_node->parent;
    my $e = $dump_node->element_name;
    my $i = $dump_node->index_value;    # defined only for hash and list

    if ( $obj_type =~ /node/ ) {
        $view_scanner->scan_node( \$result, $dump_node );
    }
    elsif ( defined $i ) {
        $view_scanner->scan_hash( \$result, $p, $e, $i );
    }
    elsif ($obj_type eq 'list'
        or $obj_type eq 'hash'
        or $obj_type eq 'leaf'
        or $obj_type eq 'check_list' ) {
        $view_scanner->scan_element( \$result, $p, $e );
    }
    else {
        croak "dump_as_data: unexpected type: $obj_type";
    }

    return $result;
}

sub dump_annotations_as_pod {
    my $self = shift;

    my %args      = @_;
    my $dump_node = delete $args{node}
        || croak "dump_annotations_as_pod: missing 'node' parameter";

    my $annotation_to_pod = sub {
        my $obj  = shift;
        my $path = shift || $obj->location;
        my $a    = $obj->annotation;
        if ($a) {
            chomp $a;
            return "=item $path\n\n$a\n\n";
        }
        else {
            return '';
        }
    };

    my $std_cb = sub {
        my ( $scanner, $data_r, $obj, $element, $index, $value_obj ) = @_;
        $$data_r .= $annotation_to_pod->($value_obj);
    };

    my $hash_element_cb = sub {
        my ( $scanner, $data_ref, $node, $element_name, @keys ) = @_;
        my $h      = $node->fetch_element($element_name);
        my $h_path = $h->location . ':';
        foreach (@keys) {
            $$data_ref .= $annotation_to_pod->( $h->fetch_with_id($_), $h_path . $_ );
            $scanner->scan_hash( $data_ref, $node, $element_name, $_ );
        }
    };

    my $node_content_cb = sub {
        my ( $scanner, $data_ref, $node, @element ) = @_;
        my $node_path = $node->location;
        $node_path .= ' ' if $node_path;
        foreach (@element) {
            $$data_ref .= $annotation_to_pod->(
                $node->fetch_element( name => $_, check => 'no' ),
                $node_path . $_
            );
            $scanner->scan_element( $data_ref, $node, $_ );
        }
    };

    my @scan_args = (
        check      => delete $args{check}      || 'yes',
        fallback   => 'all',
        leaf_cb    => $std_cb,
        node_content_cb => $node_content_cb,
        hash_element_cb => $hash_element_cb,
        list_element_cb => $hash_element_cb,
    );

    my @left = keys %args;
    croak "dump_annotations_as_pod: unknown parameter:@left" if @left;

    # perform the scan
    my $view_scanner = Config::Model::ObjTreeScanner->new(@scan_args);

    my $obj_type = $dump_node->get_type;
    my $result   = '';

    my $a = $dump_node->annotation;
    my $l = $dump_node->location;
    $result .= "=item $l\n\n$a\n\n" if $a;

    if ( $obj_type =~ /node/ ) {
        $view_scanner->scan_node( \$result, $dump_node );
    }
    else {
        croak "dump_annotations_as_pod: unexpected type: $obj_type";
    }

    return '' unless $result;
    return "=head1 Annotations\n\n=over\n\n" . $result . "=back\n\n";
}

1;

# ABSTRACT: Dump configuration content as a perl data structure

__END__

=pod

=encoding UTF-8

=head1 NAME

Config::Model::DumpAsData - Dump configuration content as a perl data structure

=head1 VERSION

version 2.155

=head1 SYNOPSIS

 use Config::Model ;
 use Data::Dumper ;

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
 $root->fetch_element('bar')->store('bla bla') ;
 $root->fetch_element('baz')->fetch_with_id('en')->store('hello') ;

 # put more data the easy way
 my $steps = 'baz:fr=bonjour baz:hr="dobar dan"';
 $root->load( steps => $steps ) ;

 print Dumper($root->dump_as_data);
 # $VAR1 = {
 #         'bar' => 'bla bla',
 #         'baz' => {
 #                    'en' => 'hello',
 #                    'fr' => 'bonjour',
 #                    'hr' => 'dobar dan'
 #                  },
 #         'foo' => 'yada'
 #       };

=head1 DESCRIPTION

This module is used directly by L<Config::Model::Node> to dump the content
of a configuration tree in perl data structure.

The perl data structure is a hash of hash. Only
L<CheckList|Config::Model::CheckList> content is stored in an array ref.

User can pass a sub reference to apply to values of boolean type. This
sub can be used to convert the value to an object representing a
boolean like L<boolean>. (since 2.129)

Note that undefined values are skipped for list element. I.e. if a
list element contains C<('a',undef,'b')>, the data structure then
contains C<'a','b'>.

=head1 CONSTRUCTOR

=head2 new

No parameter. The constructor should be used only by
L<Config::Model::Node>.

=head1 Methods

=head2 dump_as_data

Return a perl data structure

Parameters are:

=over

=item node

Reference to a L<Config::Model::Node> object. Mandatory

=item full_dump

Also dump default values in the data structure. Useful if the dumped
configuration data is used by the application. This parameter is
deprecated in favor of mode parameter.

=item mode

Note that C<mode> parameter is also accepted and overrides
C<full_dump> parameter. See L<Config::Model::Value/fetch> for
details on C<mode>.

=item skip_auto_write

Skip node that have a C<perl write> capability in their model. See
L<Config::Model::BackendMgr>.

This option must be used when using DumpAsData: to write back
configuration data. When a configuration model contains several
backends (one at the tree root and others in tree nodes), setting this
option ensure that the "root" configuration file does not contain data
duplicated in configuration file of others tree nodes.

=item auto_vivify

Scan and create data for nodes elements even if no actual data was
stored in them. This may be useful to trap missing mandatory values.

=item ordered_hash_as_list

By default, ordered hash (i.e. the order of the keys are important)
are dumped as Perl list. This is the faster way to dump such hashed
while keeping the key order. But it's the less readable way.

When this parameter is 1 (default), the ordered hash is dumped as a
list:

  my_hash => [ A => 'foo', B => 'bar', C => 'baz' ]

When this parameter is set as 0, the ordered hash is dumped with a
special key that specifies the order of keys. E.g.:

  my_hash => {
   __my_hash_order => [ 'A', 'B', 'C' ] ,
   B => 'bar', A => 'foo', C => 'baz'
  }

=item to_boolean

Sub reference to map a value of type boolean to a boolean class (since
2.129). For instance:

 to_boolean => sub { boolean($_[0]); }

Default is C<sub { return $_[0] }>

=back

=head1 Methods

=head2 dump_annotations_as_pod

Return a string formatted in pod (See L<perlpod>) with the annotations.

Parameters are:

=over

=item node

Reference to a L<Config::Model::Node> object. Mandatory

=item check_list

Yes, no or skip

=back

=head1 AUTHOR

Dominique Dumont, (ddumont at cpan dot org)

=head1 SEE ALSO

L<Config::Model>,L<Config::Model::Node>,L<Config::Model::ObjTreeScanner>

=head1 AUTHOR

Dominique Dumont

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2005-2022 by Dominique Dumont.

This is free software, licensed under:

  The GNU Lesser General Public License, Version 2.1, February 1999

=cut
