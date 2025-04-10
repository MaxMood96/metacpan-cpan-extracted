package Chart::Plotly::Trace::Icicle::Hoverlabel::Font;
use Moose;
use MooseX::ExtraArgs;
use Moose::Util::TypeConstraints qw(enum union);
if ( !defined Moose::Util::TypeConstraints::find_type_constraint('PDL') ) {
    Moose::Util::TypeConstraints::type('PDL');
}

our $VERSION = '0.042';    # VERSION

# ABSTRACT: This attribute is one of the possible options for the trace icicle.

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

has color => ( is  => "rw",
               isa => "Str|ArrayRef[Str]", );

has colorsrc => ( is            => "rw",
                  isa           => "Str",
                  documentation => "Sets the source reference on Chart Studio Cloud for `color`.",
);

has description => ( is      => "ro",
                     default => "Sets the font used in hover labels.", );

has family => (
    is            => "rw",
    isa           => "Str|ArrayRef[Str]",
    documentation =>
      "HTML font family - the typeface that will be applied by the web browser. The web browser will only be able to apply a font if it is available on the system which it operates. Provide multiple font families, separated by commas, to indicate the preference in which to apply fonts if they aren't available on the system. The Chart Studio Cloud (at https://chart-studio.plotly.com or on-premise) generates images on a server, where only a select number of fonts are installed and supported. These include *Arial*, *Balto*, *Courier New*, *Droid Sans*,, *Droid Serif*, *Droid Sans Mono*, *Gravitas One*, *Old Standard TT*, *Open Sans*, *Overpass*, *PT Sans Narrow*, *Raleway*, *Times New Roman*.",
);

has familysrc => ( is            => "rw",
                   isa           => "Str",
                   documentation => "Sets the source reference on Chart Studio Cloud for `family`.",
);

has size => ( is  => "rw",
              isa => "Num|ArrayRef[Num]", );

has sizesrc => ( is            => "rw",
                 isa           => "Str",
                 documentation => "Sets the source reference on Chart Studio Cloud for `size`.",
);

__PACKAGE__->meta->make_immutable();
1;

__END__

=pod

=encoding utf-8

=head1 NAME

Chart::Plotly::Trace::Icicle::Hoverlabel::Font - This attribute is one of the possible options for the trace icicle.

=head1 VERSION

version 0.042

=head1 SYNOPSIS

 use Chart::Plotly;
 use Chart::Plotly::Plot;
 use JSON;
 use Chart::Plotly::Trace::Icicle;
 
 # Example from https://github.com/plotly/plotly.js/blob/9a57346d35f28a7969beea9e0fc35e13932275c6/test/image/mocks/icicle_coffee.json
 my $trace1 = Chart::Plotly::Trace::Icicle->new({'parents' => ['', '', 'Aromas', 'Aromas', 'Aromas', 'Tastes', 'Tastes', 'Tastes', 'Tastes', 'Aromas-Enzymatic', 'Aromas-Enzymatic', 'Aromas-Enzymatic', 'Aromas-Sugar Browning', 'Aromas-Sugar Browning', 'Aromas-Sugar Browning', 'Aromas-Dry Distillation', 'Aromas-Dry Distillation', 'Aromas-Dry Distillation', 'Tastes-Bitter', 'Tastes-Bitter', 'Tastes-Salt', 'Tastes-Salt', 'Tastes-Sweet', 'Tastes-Sweet', 'Tastes-Sour', 'Tastes-Sour', 'Enzymatic-Flowery', 'Enzymatic-Flowery', 'Enzymatic-Fruity', 'Enzymatic-Fruity', 'Enzymatic-Herby', 'Enzymatic-Herby', 'Sugar Browning-Nutty', 'Sugar Browning-Nutty', 'Sugar Browning-Carmelly', 'Sugar Browning-Carmelly', 'Sugar Browning-Chocolatey', 'Sugar Browning-Chocolatey', 'Dry Distillation-Resinous', 'Dry Distillation-Resinous', 'Dry Distillation-Spicy', 'Dry Distillation-Spicy', 'Dry Distillation-Carbony', 'Dry Distillation-Carbony', 'Bitter-Pungent', 'Bitter-Pungent', 'Bitter-Harsh', 'Bitter-Harsh', 'Salt-Sharp', 'Salt-Sharp', 'Salt-Bland', 'Salt-Bland', 'Sweet-Mellow', 'Sweet-Mellow', 'Sweet-Acidy', 'Sweet-Acidy', 'Sour-Winey', 'Sour-Winey', 'Sour-Soury', 'Sour-Soury', 'Flowery-Floral', 'Flowery-Floral', 'Flowery-Fragrant', 'Flowery-Fragrant', 'Fruity-Citrus', 'Fruity-Citrus', 'Fruity-Berry-like', 'Fruity-Berry-like', 'Herby-Alliaceous', 'Herby-Alliaceous', 'Herby-Leguminous', 'Herby-Leguminous', 'Nutty-Nut-like', 'Nutty-Nut-like', 'Nutty-Malt-like', 'Nutty-Malt-like', 'Carmelly-Candy-like', 'Carmelly-Candy-like', 'Carmelly-Syrup-like', 'Carmelly-Syrup-like', 'Chocolatey-Chocolate-like', 'Chocolatey-Chocolate-like', 'Chocolatey-Vanilla-like', 'Chocolatey-Vanilla-like', 'Resinous-Turpeny', 'Resinous-Turpeny', 'Resinous-Medicinal', 'Resinous-Medicinal', 'Spicy-Warming', 'Spicy-Warming', 'Spicy-Pungent', 'Spicy-Pungent', 'Carbony-Smokey', 'Carbony-Smokey', 'Carbony-Ashy', 'Carbony-Ashy', ], 'pathbar' => {'visible' => JSON::false, }, 'textinfo' => 'label+percent parent', 'ids' => ['Aromas', 'Tastes', 'Aromas-Enzymatic', 'Aromas-Sugar Browning', 'Aromas-Dry Distillation', 'Tastes-Bitter', 'Tastes-Salt', 'Tastes-Sweet', 'Tastes-Sour', 'Enzymatic-Flowery', 'Enzymatic-Fruity', 'Enzymatic-Herby', 'Sugar Browning-Nutty', 'Sugar Browning-Carmelly', 'Sugar Browning-Chocolatey', 'Dry Distillation-Resinous', 'Dry Distillation-Spicy', 'Dry Distillation-Carbony', 'Bitter-Pungent', 'Bitter-Harsh', 'Salt-Sharp', 'Salt-Bland', 'Sweet-Mellow', 'Sweet-Acidy', 'Sour-Winey', 'Sour-Soury', 'Flowery-Floral', 'Flowery-Fragrant', 'Fruity-Citrus', 'Fruity-Berry-like', 'Herby-Alliaceous', 'Herby-Leguminous', 'Nutty-Nut-like', 'Nutty-Malt-like', 'Carmelly-Candy-like', 'Carmelly-Syrup-like', 'Chocolatey-Chocolate-like', 'Chocolatey-Vanilla-like', 'Resinous-Turpeny', 'Resinous-Medicinal', 'Spicy-Warming', 'Spicy-Pungent', 'Carbony-Smokey', 'Carbony-Ashy', 'Pungent-Creosol', 'Pungent-Phenolic', 'Harsh-Caustic', 'Harsh-Alkaline', 'Sharp-Astringent', 'Sharp-Rough', 'Bland-Neutral', 'Bland-Soft', 'Mellow-Delicate', 'Mellow-Mild', 'Acidy-Nippy', 'Acidy-Piquant', 'Winey-Tangy', 'Winey-Tart', 'Soury-Hard', 'Soury-Acrid', 'Floral-Coffee Blossom', 'Floral-Tea Rose', 'Fragrant-Cardamon Caraway', 'Fragrant-Coriander Seeds', 'Citrus-Lemon', 'Citrus-Apple', 'Berry-like-Apricot', 'Berry-like-Blackberry', 'Alliaceous-Onion', 'Alliaceous-Garlic', 'Leguminous-Cucumber', 'Leguminous-Garden Peas', 'Nut-like-Roasted Peanuts', 'Nut-like-Walnuts', 'Malt-like-Balsamic Rice', 'Malt-like-Toast', 'Candy-like-Roasted Hazelnut', 'Candy-like-Roasted Almond', 'Syrup-like-Honey', 'Syrup-like-Maple Syrup', 'Chocolate-like-Bakers', 'Chocolate-like-Dark Chocolate', 'Vanilla-like-Swiss', 'Vanilla-like-Butter', 'Turpeny-Piney', 'Turpeny-Blackcurrant-like', 'Medicinal-Camphoric', 'Medicinal-Cineolic', 'Warming-Cedar', 'Warming-Pepper', 'Pungent-Clove', 'Pungent-Thyme', 'Smokey-Tarry', 'Smokey-Pipe Tobacco', 'Ashy-Burnt', 'Ashy-Charred', ], 'labels' => ['Aromas', 'Tastes', 'Enzymatic', 'Sugar Browning', 'Dry Distillation', 'Bitter', 'Salt', 'Sweet', 'Sour', 'Flowery', 'Fruity', 'Herby', 'Nutty', 'Carmelly', 'Chocolatey', 'Resinous', 'Spicy', 'Carbony', 'Pungent', 'Harsh', 'Sharp', 'Bland', 'Mellow', 'Acidy', 'Winey', 'Soury', 'Floral', 'Fragrant', 'Citrus', 'Berry-like', 'Alliaceous', 'Leguminous', 'Nut-like', 'Malt-like', 'Candy-like', 'Syrup-like', 'Chocolate-like', 'Vanilla-like', 'Turpeny', 'Medicinal', 'Warming', 'Pungent', 'Smokey', 'Ashy', 'Creosol', 'Phenolic', 'Caustic', 'Alkaline', 'Astringent', 'Rough', 'Neutral', 'Soft', 'Delicate', 'Mild', 'Nippy', 'Piquant', 'Tangy', 'Tart', 'Hard', 'Acrid', 'Coffee Blossom', 'Tea Rose', 'Cardamon Caraway', 'Coriander Seeds', 'Lemon', 'Apple', 'Apricot', 'Blackberry', 'Onion', 'Garlic', 'Cucumber', 'Garden Peas', 'Roasted Peanuts', 'Walnuts', 'Balsamic Rice', 'Toast', 'Roasted Hazelnut', 'Roasted Almond', 'Honey', 'Maple Syrup', 'Bakers', 'Dark Chocolate', 'Swiss', 'Butter', 'Piney', 'Blackcurrant-like', 'Camphoric', 'Cineolic', 'Cedar', 'Pepper', 'Clove', 'Thyme', 'Tarry', 'Pipe Tobacco', 'Burnt', 'Charred', ], });
 
 
 my $plot = Chart::Plotly::Plot->new(
     traces => [$trace1, ],
     layout => 
         {'margin' => {'t' => 0, 'l' => 0, 'b' => 0, 'r' => 0, }, 'shapes' => [{'x0' => 0, 'y1' => 1, 'y0' => 0, 'x1' => 1, 'type' => 'rect', 'layer' => 'below', }, ], 'height' => 500, 'width' => 500, }
 ); 
 
 Chart::Plotly::show_plot($plot);

=head1 DESCRIPTION

This attribute is part of the possible options for the trace icicle.

This file has been autogenerated from the official plotly.js source.

If you like Plotly, please support them: L<https://plot.ly/> 
Open source announcement: L<https://plot.ly/javascript/open-source-announcement/>

Full reference: L<https://plot.ly/javascript/reference/#icicle>

=head1 DISCLAIMER

This is an unofficial Plotly Perl module. Currently I'm not affiliated in any way with Plotly. 
But I think plotly.js is a great library and I want to use it with perl.

=head1 METHODS

=head2 TO_JSON

Serialize the trace to JSON. This method should be called only by L<JSON> serializer.

=head1 ATTRIBUTES

=over

=item * color

=item * colorsrc

Sets the source reference on Chart Studio Cloud for `color`.

=item * description

=item * family

HTML font family - the typeface that will be applied by the web browser. The web browser will only be able to apply a font if it is available on the system which it operates. Provide multiple font families, separated by commas, to indicate the preference in which to apply fonts if they aren't available on the system. The Chart Studio Cloud (at https://chart-studio.plotly.com or on-premise) generates images on a server, where only a select number of fonts are installed and supported. These include *Arial*, *Balto*, *Courier New*, *Droid Sans*,, *Droid Serif*, *Droid Sans Mono*, *Gravitas One*, *Old Standard TT*, *Open Sans*, *Overpass*, *PT Sans Narrow*, *Raleway*, *Times New Roman*.

=item * familysrc

Sets the source reference on Chart Studio Cloud for `family`.

=item * size

=item * sizesrc

Sets the source reference on Chart Studio Cloud for `size`.

=back

=head1 AUTHOR

Pablo Rodríguez González <pablo.rodriguez.gonzalez@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2022 by Pablo Rodríguez González.

This is free software, licensed under:

  The MIT (X11) License

=cut
