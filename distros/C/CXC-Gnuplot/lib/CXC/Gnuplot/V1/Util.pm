package CXC::Gnuplot::V1::Util;

use v5.38;
our $VERSION = 'v0.29.3';

use experimental 'declared_refs', 'for_list', 'builtin', 'try';

use Exporter::Shiny
  'flatten_array',
  'render_set',
  'gnuplot_color',
  'gnuplot_color_names',
  'maybe_quote',
  'pvalidate',
  'pvalidate_xy_pair',
  'quote',
  'render_opts',
  'to_hash_r',
  'clone_object',
  ;

# use namespace::autoclean;
use Hash::Merge;
use Ref::Util 'is_plain_arrayref', 'is_plain_hashref', 'is_plain_ref', 'is_ref', 'is_blessed_ref';
use builtin::compat 'blessed', 'load_module', 'trim', 'is_bool', 'true', 'false';
use CXC::Data::Visitor 'visit', 'VISIT_ALL', 'RESULT_CONTINUE';
use B ();

use constant BASE => __PACKAGE__ =~ s/[^:]+$//r;

my sub croak {
    require Carp;
    goto \&Carp::croak;
}

my sub rewrite_prefix ( $module ) {
    state $root = ( __PACKAGE__ =~ s/::Util//r ) . q{::};
    return
        defined $module
      ? substr( $module, 0, 1 ) eq q{+}
          ? $module
          : $root . $module
      : undef;
}

# not very efficient





sub flatten_array ( $array ) {
    return is_plain_arrayref( $array )
      ? [ map { is_plain_arrayref( $_ ) ? __SUB__->( $_ )->@* : $_; } $array->@* ]
      : [$array];
}





sub render_set( $set, $format ) {
    ## no critic(NamingConventions::ProhibitAmbiguousNames)
    my \@set = $set;
    return
        $format eq 'array'         ? @set
      : $format eq 'flatten_array' ? map { flatten_array( $_ ) } @set
      : $format eq 'string'        ? map { join q{ }, flatten_array( $_ )->@* } @set
      :                              croak( 'unknown format: ' . $format );

}





sub maybe_quote( $str ) {
    return $str =~ /^(['"]).*(\1)$/ ? $str : B::cstring( $str );
}





sub quote( $str ) {
    return B::cstring( $str );
}

## no critic (NamingConventions::ProhibitAmbiguousNames )
my sub merge ( $left, $right ) {
    state $merger = do {
        my $obj = Hash::Merge->new;
        $obj->add_behavior_spec( {
                'SCALAR' => {
                    'SCALAR' => sub { $_[1] },
                    'ARRAY'  => sub { $_[1] },
                    'HASH'   => sub { $_[1] },
                },
                'ARRAY' => {
                    'SCALAR' => sub { $_[1] },
                    'ARRAY'  => sub { $_[1] },
                    'HASH'   => sub { $_[1] },
                },
                'HASH' => {
                    'SCALAR' => sub { $_[1] },
                    'ARRAY'  => sub { $_[1] },
                    'HASH'   => sub ( $left, $right ) {
                        my \%left  = $left;
                        my \%right = $right;

                        # delete the specified entries from $left
                        if ( defined( my $delete = delete $right{-delete} ) ) {
                            # delete everything
                            if ( is_bool( $delete ) ) {
                                %left = () if $delete;
                            }
                            else {
                                # delete specific keys
                                delete @left{ is_plain_arrayref( $delete ) ? $delete->@* : $delete };
                            }
                        }

                        if ( defined( my $overwrite = delete $right{-overwrite} ) ) {

                            # overwrite keys in $left with keys in $right
                            # removing them from %right so they can't be merged
                            my @keys
                              = is_bool( $overwrite )           ? ( $overwrite ? keys %right : () )
                              : is_plain_arrayref( $overwrite ) ? $overwrite->@*
                              :                                   ( $overwrite );
                            @left{@keys} = delete @right{@keys};
                        }


                        return \%left unless keys %right;

                        # merge what's left
                        # _merge_hashes is part of the public API
                        ## no critic ( Subroutines::ProtectPrivateSubs )
                        Hash::Merge::_merge_hashes( \%left, \%right );
                    },
                },
            },
            __PACKAGE__,
        );
        # this is on by default, but let's make it explicit
        $obj->set_clone_behavior( true );
        $obj;
    };

    $merger->merge( $left, $right );
}





sub clone_object ( $object, $new_attr ) {

    my $class = blessed( $object );
    my %new   = $new_attr->%*;
    my \%old  = $object->to_hash;
    my \%attr = merge( \%old, \%new );

    return $class->new( %attr );
}







sub pvalidate ( $name, $type, $value_ref ) {

    return if !defined $value_ref->$*;

    try {
        if ( $type isa Type::Tiny ) {
            if ( $type->has_coercion ) {
                $value_ref->$* = $type->assert_coerce( $value_ref->$* );
            }
            else {
                $type->assert_valid( $value_ref->$* );
            }
        }

        elsif ( !is_ref $type ) {
            my $class = BASE . $type;
            return if $value_ref->$* isa $class;
            load_module( $class );

            $value_ref->$* = $class->new( $value_ref->$* );
        }
    }
    catch ( $e ) {
        croak( qq{unable to validate or coerce "$name" parameter: $e} );
    };
}





sub pvalidate_xy_pair ( $name, $type, $value_ref ) {

    my $value = $value_ref->$*;

    return if !defined $value;

    pvalidate( $name => $type, $value_ref );
    $value_ref->$* = $value = { x => $value }
      unless is_plain_hashref( $value );

    defined $value->{x}
      or croak( qq{must specify an "x" $name} );

}


my sub _colors {

    state @colors = do {
        require File::ShareDir::Tarball;
        require Path::Tiny;
        require CXC::Gnuplot::V1::Color;

        # the share/gnuplot_colors file is derived from the gnuplot 'show colors' command
        my $file
          = Path::Tiny::path( File::ShareDir::Tarball::dist_file( 'CXC-Gnuplot', 'gnuplot_colors' ) );

        ## no critic (BuiltinFunctions::ProhibitComplexMappings)
        map {
            my %color;
            @color{ 'name', 'rgb', 'r', 'g', 'b' } = split /[\h=]+/;
            CXC::Gnuplot::V1::Color->new( %color );
        } grep length, map trim( $_ ), $file->lines;
    };

    return @colors;

}





sub gnuplot_color_names {
    state @names = map { $_->name } _colors;
    return @names;
}





sub gnuplot_color ( $name ) {
    state %color = map { $_->name => $_ } _colors;
    return $color{$name};
}





sub to_hash_r ( $hash ) {

    visit(
        $hash,
        sub ( $kydx, $vref, $context, $metadata ) {

            # make copies of containers.
            if ( is_plain_arrayref $vref->$* ) {
                $vref->$* = [ $vref->$*->@* ];
                return RESULT_CONTINUE;
            }

            if ( is_plain_hashref $vref->$* ) {
                $vref->$* = { $vref->$*->%* };
                return RESULT_CONTINUE;
            }

            return RESULT_CONTINUE
              unless is_blessed_ref $vref->$*;
            my $obj = $vref->$*;
            my $mth = $obj->can( 'to_hash' );

            croak( 'no means of converting object to hash at: ' . join( q{.}, $metadata->{path}->@* ) )
              if !defined $mth;

            $vref->$* = $obj->$mth;
            return RESULT_CONTINUE;
        },
        visit => VISIT_ALL,
    );

    $hash;
}





sub render_opts ( $label, $value ) {

    !defined $value and return ();

    !is_blessed_ref $value
      and croak( 'value is not an object' );

    my @opts = ( is_plain_arrayref( $label ) ? $label->@* : $label, $value->opts );

    return \@opts;
}

1;

__END__

=pod

=for :stopwords Diab Jerius Smithsonian Astrophysical Observatory pvalidate

=head1 NAME

CXC::Gnuplot::V1::Util

=head1 VERSION

version v0.29.3

=head1 SUBROUTINES

=head2 flatten_array ( $array )

=head2 render_set

=head2 maybe_quote ( $str )

=head2 quote ( $str )

=head2 clone_object ( $object, $new_attr )

=head2 pvalidate ( $name, $type | $class, \$value )

=head2 pvalidate_xy_pair ( $name, $type, $value )

=head2 gnuplot_color_names

=head2 gnuplot_color ( $name )

=head2 to_hash_r ($hash )

=head2 render_opts

=head1 INTERNALS

=head1 SUPPORT

=head2 Bugs

Please report any bugs or feature requests to bug-cxc-gnuplot@rt.cpan.org  or through the web interface at: L<https://rt.cpan.org/Public/Dist/Display.html?Name=CXC-Gnuplot>

=head2 Source

Source is available at

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot

and may be cloned from

  https://codeberg.org/CXC-Optics/p5-CXC-Gnuplot.git

=head1 SEE ALSO

Please see those modules/websites for more information related to this module.

=over 4

=item *

L<CXC::Gnuplot|CXC::Gnuplot>

=back

=head1 AUTHOR

Diab Jerius <djerius@cfa.harvard.edu>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2024 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
