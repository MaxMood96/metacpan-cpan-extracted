package Chart::Plotly::Trace::Contourcarpet::Contours;
use Moose;
use MooseX::ExtraArgs;
use Moose::Util::TypeConstraints qw(enum union);
if ( !defined Moose::Util::TypeConstraints::find_type_constraint('PDL') ) {
    Moose::Util::TypeConstraints::type('PDL');
}

use Chart::Plotly::Trace::Contourcarpet::Contours::ImpliedEdits;
use Chart::Plotly::Trace::Contourcarpet::Contours::Labelfont;

our $VERSION = '0.042';    # VERSION

# ABSTRACT: This attribute is one of the possible options for the trace contourcarpet.

sub TO_JSON {
    my $self       = shift;
    my $extra_args = $self->extra_args // {};
    my $meta       = $self->meta;
    my %hash       = %$self;
    for my $name ( sort keys %hash ) {
        my $attr = $meta->get_attribute($name);
        if ( defined $attr ) {
            my $value = $hash{$name};
            my $type  = $attr->type_constraint;
            if ( $type && $type->equals('Bool') ) {
                $hash{$name} = $value ? \1 : \0;
            }
        }
    }
    %hash = ( %hash, %$extra_args );
    delete $hash{'extra_args'};
    if ( $self->can('type') && ( !defined $hash{'type'} ) ) {
        $hash{type} = $self->type();
    }
    return \%hash;
}

has coloring => (
    is            => "rw",
    isa           => enum( [ "fill", "lines", "none" ] ),
    documentation =>
      "Determines the coloring method showing the contour values. If *fill*, coloring is done evenly between each contour level If *lines*, coloring is done on the contour lines. If *none*, no coloring is applied on this trace.",
);

has end => ( is            => "rw",
             isa           => "Num",
             documentation => "Sets the end contour level value. Must be more than `contours.start`",
);

has impliedEdits => ( is  => "rw",
                      isa => "Maybe[HashRef]|Chart::Plotly::Trace::Contourcarpet::Contours::ImpliedEdits", );

has labelfont => ( is  => "rw",
                   isa => "Maybe[HashRef]|Chart::Plotly::Trace::Contourcarpet::Contours::Labelfont", );

has labelformat => (
    is            => "rw",
    isa           => "Str",
    documentation =>
      "Sets the contour label formatting rule using d3 formatting mini-languages which are very similar to those in Python. For numbers, see: https://github.com/d3/d3-format/tree/v1.4.5#d3-format.",
);

has operation => (
    is            => "rw",
    isa           => enum( [ "=", "<", ">=", ">", "<=", "[]", "()", "[)", "(]", "][", ")(", "](", ")[" ] ),
    documentation =>
      "Sets the constraint operation. *=* keeps regions equal to `value` *<* and *<=* keep regions less than `value` *>* and *>=* keep regions greater than `value` *[]*, *()*, *[)*, and *(]* keep regions inside `value[0]` to `value[1]` *][*, *)(*, *](*, *)[* keep regions outside `value[0]` to value[1]` Open vs. closed intervals make no difference to constraint display, but all versions are allowed for consistency with filter transforms.",
);

has showlabels => ( is            => "rw",
                    isa           => "Bool",
                    documentation => "Determines whether to label the contour lines with their values.",
);

has showlines => (
    is            => "rw",
    isa           => "Bool",
    documentation =>
      "Determines whether or not the contour lines are drawn. Has an effect only if `contours.coloring` is set to *fill*.",
);

has size => ( is            => "rw",
              isa           => "Num",
              documentation => "Sets the step between each contour level. Must be positive.",
);

has start => ( is            => "rw",
               isa           => "Num",
               documentation => "Sets the starting contour level value. Must be less than `contours.end`",
);

has value => (
    is            => "rw",
    isa           => "Any",
    documentation =>
      "Sets the value or values of the constraint boundary. When `operation` is set to one of the comparison values (=,<,>=,>,<=) *value* is expected to be a number. When `operation` is set to one of the interval values ([],(),[),(],][,)(,](,)[) *value* is expected to be an array of two numbers where the first is the lower bound and the second is the upper bound.",
);

__PACKAGE__->meta->make_immutable();
1;

__END__

=pod

=encoding utf-8

=head1 NAME

Chart::Plotly::Trace::Contourcarpet::Contours - This attribute is one of the possible options for the trace contourcarpet.

=head1 VERSION

version 0.042

=head1 SYNOPSIS

 use Chart::Plotly qw(show_plot);
 use Chart::Plotly::Trace::Carpet;
 use Chart::Plotly::Trace::Contourcarpet;
 # Example data from: https://plot.ly/javascript/carpet-contour/#add-contours
 my $contourcarpet = Chart::Plotly::Trace::Contourcarpet->new(
     a           => [ 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 ],
     b           => [ 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6 ],
     z           => [ 1, 1.96, 2.56, 3.0625, 4, 5.0625, 1, 7.5625, 9, 12.25, 15.21, 14.0625 ],
     autocontour => 0,
     contours    => {
         start => 1,
         end   => 14,
         size  => 1
     },
     line        => {
         width     => 2,
         smoothing => 0
     },
     colorbar    => {
         len => 0.4,
         y   => 0.25
     }
 );
 
 my $carpet = Chart::Plotly::Trace::Carpet->new(
     a     => [ 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 ],
     b     => [ 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6 ],
     x     => [ 2, 3, 4, 5, 2.2, 3.1, 4.1, 5.1, 1.5, 2.5, 3.5, 4.5 ],
     y     => [ 1, 1.4, 1.6, 1.75, 2, 2.5, 2.7, 2.75, 3, 3.5, 3.7, 3.75 ],
     aaxis => {
         tickprefix     => "a = ",
         smoothing      => 0,
         minorgridcount => 9,
         type           => 'linear'
     },
     baxis => {
         tickprefix     => "b = ",
         smoothing      => 0,
         minorgridcount => 9,
         type           => 'linear'
     }
 );
 
 show_plot([ $contourcarpet, $carpet ]);

=head1 DESCRIPTION

This attribute is part of the possible options for the trace contourcarpet.

This file has been autogenerated from the official plotly.js source.

If you like Plotly, please support them: L<https://plot.ly/> 
Open source announcement: L<https://plot.ly/javascript/open-source-announcement/>

Full reference: L<https://plot.ly/javascript/reference/#contourcarpet>

=head1 DISCLAIMER

This is an unofficial Plotly Perl module. Currently I'm not affiliated in any way with Plotly. 
But I think plotly.js is a great library and I want to use it with perl.

=head1 METHODS

=head2 TO_JSON

Serialize the trace to JSON. This method should be called only by L<JSON> serializer.

=head1 ATTRIBUTES

=over

=item * coloring

Determines the coloring method showing the contour values. If *fill*, coloring is done evenly between each contour level If *lines*, coloring is done on the contour lines. If *none*, no coloring is applied on this trace.

=item * end

Sets the end contour level value. Must be more than `contours.start`

=item * impliedEdits

=item * labelfont

=item * labelformat

Sets the contour label formatting rule using d3 formatting mini-languages which are very similar to those in Python. For numbers, see: https://github.com/d3/d3-format/tree/v1.4.5#d3-format.

=item * operation

Sets the constraint operation. *=* keeps regions equal to `value` *<* and *<=* keep regions less than `value` *>* and *>=* keep regions greater than `value` *[]*, *()*, *[)*, and *(]* keep regions inside `value[0]` to `value[1]` *][*, *)(*, *](*, *)[* keep regions outside `value[0]` to value[1]` Open vs. closed intervals make no difference to constraint display, but all versions are allowed for consistency with filter transforms.

=item * showlabels

Determines whether to label the contour lines with their values.

=item * showlines

Determines whether or not the contour lines are drawn. Has an effect only if `contours.coloring` is set to *fill*.

=item * size

Sets the step between each contour level. Must be positive.

=item * start

Sets the starting contour level value. Must be less than `contours.end`

=item * value

Sets the value or values of the constraint boundary. When `operation` is set to one of the comparison values (=,<,>=,>,<=) *value* is expected to be a number. When `operation` is set to one of the interval values ([],(),[),(],][,)(,](,)[) *value* is expected to be an array of two numbers where the first is the lower bound and the second is the upper bound.

=back

=head1 AUTHOR

Pablo Rodríguez González <pablo.rodriguez.gonzalez@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Pablo Rodríguez González.

This is free software, licensed under:

  The MIT (X11) License

=cut
