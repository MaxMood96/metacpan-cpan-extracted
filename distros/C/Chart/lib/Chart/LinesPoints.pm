#
# line charts (plots)
# LinesPoints class connect the given x-/y-values by straight lines 
# and the x-/y-values are plotted by points.
#

use v5.12;

package Chart::LinesPoints;
our @ISA     = qw(Chart::Base);
our $VERSION = 'v2.403.9';

use Chart::Base;
use GD;
use Carp;



#>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  public methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<#

#>>>>>>>>>>>>>>>>>>>>>>>>>>>#
#  private methods go here  #
#<<<<<<<<<<<<<<<<<<<<<<<<<<<#

## @fn private _draw_data
# draw the data
sub _draw_data
{
    my $self      = shift;
    my $data      = $self->{'dataref'};
    my $misccolor = $self->_color_role_to_index('misc');
    my ( $x1, $x2, $x3, $y1, $y2, $y3, $mod, $abs_x_max, $abs_y_max );
    my ( $width, $height, $delta, $map, $t_x_min, $t_x_max, $t_y_min, $t_y_max );
    my ( $i, $j, $color, $brush, $zero_offset, $delta_num );
    my $repair_top_flag    = 0;
    my $repair_bottom_flag = 0;
    my $diff;

    # init the imagemap data field if they want it
    if ( $self->true( $self->{'imagemap'} ) )
    {
        $self->{'imagemap_data'} = [];
    }

    # find the delta value between data points, as well
    # as the mapping constant
    $width  = $self->{'curr_x_max'} - $self->{'curr_x_min'};
    $height = $self->{'curr_y_max'} - $self->{'curr_y_min'};
    $delta  = $width / ( $self->{'num_datapoints'} > 0 ? $self->{'num_datapoints'} : 1 );
    $diff   = ( $self->{'max_val'} - $self->{'min_val'} );
    $diff   = 1 if $diff == 0;
    $map    = $height / $diff;

    # get the base x-y values
    if ( $self->true( $self->{'xy_plot'} ) )
    {
        $x1 = $self->{'curr_x_min'};
    }
    else
    {
        $x1 = $self->{'curr_x_min'} + ( $delta / 2 );
    }
    if ( $self->{'min_val'} >= 0 )
    {
        $y1  = $self->{'curr_y_max'};
        $mod = $self->{'min_val'};
    }
    elsif ( $self->{'max_val'} <= 0 )
    {
        $y1  = $self->{'curr_y_min'};
        $mod = $self->{'max_val'};
    }
    else
    {
        $y1 = $self->{'curr_y_min'} + ( $map * $self->{'max_val'} );
        $mod = 0;
        $self->{'gd_obj'}->line( $self->{'curr_x_min'}, $y1, $self->{'curr_x_max'}, $y1, $misccolor );
    }

    #for a xy-plot, use this delta and maybe an offset for the zero-axes
    if ( $self->true( $self->{'xy_plot'} ) )
    {
        my ( $xmin, $xmax ) = ( $self->{'x_min_val'}, $self->{'x_max_val'} );
        if ( $self->{'xlabels'} )
        {
            ( $xmin, $xmax ) = @{ $self->{'xrange'} };
        }
        $diff      = $xmax - $xmin;
        $diff      = 1 if $diff == 0;
        $delta_num = $width / $diff;

        if ( $xmin <= 0 && $xmax >= 0 )
        {
            $zero_offset = abs($xmin) * abs($delta_num);
        }
        elsif ( $xmin > 0 || $xmax < 0 )
        {
            $zero_offset = -$xmin * $delta_num;
        }
        else
        {
            $zero_offset = 0;
        }
    }

    # draw the lines
    for $i ( 1 .. $self->{'num_datasets'} )
    {

        # get the color for this dataset, and set the brush
        $color = $self->_color_role_to_index( 'dataset' . ( $i - 1 ) );
        $brush = $self->_prepare_brush( $color, 'line', 'dataset' . ( $i - 1 ) );
        $self->{'gd_obj'}->setBrush($brush);

        # draw every line for this dataset
        for $j ( 1 .. $self->{'num_datapoints'} )
        {

            # don't try to draw anything if there's no data
            if ( defined( $data->[$i][$j] ) and defined( $data->[$i][ $j - 1 ] ) )
            {
                if ( $self->true( $self->{'xy_plot'} ) )
                {
                    $x2 = $x1 + $delta_num * $data->[0][ $j - 1 ] + $zero_offset;
                    $x3 = $x1 + $delta_num * $data->[0][$j] + $zero_offset;
                }
                else
                {
                    $x2 = $x1 + ( $delta * ( $j - 1 ) );
                    $x3 = $x1 + ( $delta * $j );
                }
                $y2 = $y1 - ( ( $data->[$i][ $j - 1 ] - $mod ) * $map );
                $y3 = $y1 - ( ( $data->[$i][$j] - $mod ) * $map );

                #set the flags, if the lines are out of the borders of the chart
                if ( ( $data->[$i][$j] > $self->{'max_val'} ) || ( $data->[$i][ $j - 1 ] > $self->{'max_val'} ) )
                {
                    $repair_top_flag = 1;
                }

                if (   ( $self->{'max_val'} <= 0 )
                    && ( ( $data->[$i][$j] > $self->{'max_val'} ) || ( $data->[$i][ $j - 1 ] > $self->{'max_val'} ) ) )
                {
                    $repair_top_flag = 1;
                }
                if ( ( $data->[$i][$j] < $self->{'min_val'} ) || ( $data->[$i][ $j - 1 ] < $self->{'min_val'} ) )
                {
                    $repair_bottom_flag = 1;
                }

                # draw the line
                # ----------------
                # stepline option added by G.ST. 2005/02
                #----------------
                if ( $self->true( $self->{'stepline'} ) )
                {
                    if ( $self->{'stepline_mode'} =~ /^begin$/i )
                    {
                        $self->{'gd_obj'}->line( $x2, $y2, $x3, $y2, gdBrushed );
                        $self->{'gd_obj'}->line( $x3, $y2, $x3, $y3, gdBrushed );
                    }
                    else
                    {
                        $self->{'gd_obj'}->line( $x2, $y2, $x2, $y3, gdBrushed );
                        $self->{'gd_obj'}->line( $x2, $y3, $x3, $y3, gdBrushed );
                    }
                }

                # -----------------------------------
                # end stepline option
                #------------------------------------
                else
                {
                    $self->{'gd_obj'}->line( $x2, $y2, $x3, $y3, gdBrushed );
                }
            }
        }

        # reset the brush for points
        $brush = $self->_prepare_brush( $color, 'point', 'dataset' . ( $i - 1 ) );
        $self->{'gd_obj'}->setBrush($brush);

        # draw every point for this dataset
        for $j ( 0 .. $self->{'num_datapoints'} )
        {

            # don't try to draw anything if there's no data
            if ( defined( $data->[$i][$j] ) )
            {
                if ( $self->true( $self->{'xy_plot'} ) )
                {
                    $x2 = $x1 + $delta_num * $data->[0][$j] + $zero_offset;
                    $x3 = $x2;
                }
                else
                {
                    $x2 = $x1 + ( $delta * $j );
                    $x3 = $x2;
                }
                $y2 = $y1 - ( ( $data->[$i][$j] - $mod ) * $map );
                $y3 = $y2;

                # draw the point
                $self->{'gd_obj'}->line( $x2, $y2, $x3, $y3, gdBrushed );

                # remember the imagemap data if they wanted it
                if ( $self->true( $self->{'imagemap'} ) )
                {
                    $self->{'imagemap_data'}->[$i][$j] = [ $x2, $y2 ];
                }
            }
            else
            {
                if ( $self->true( $self->{'imagemap'} ) )
                {
                    $self->{'imagemap_data'}->[$i][$j] = [ undef(), undef() ];
                }
            }
        }
    }

    # and finaly box it off
    $self->{'gd_obj'}
      ->rectangle( $self->{'curr_x_min'}, $self->{'curr_y_min'}, $self->{'curr_x_max'}, $self->{'curr_y_max'}, $misccolor );

    #get the width and the heigth of the complete picture
    ( $abs_x_max, $abs_y_max ) = $self->{'gd_obj'}->getBounds();

    #repair the chart, if the lines are out of the borders of the chart
    if ($repair_top_flag)
    {

        #overwrite the ugly mistakes
        #   $self->{'gd_obj'}->filledRectangle ($self->{'curr_x_min'}, 0,
        $self->{'gd_obj'}->filledRectangle(
            $self->{'curr_x_min'} - ( $self->{'brush_size'} / 2 ),
            0, $self->{'curr_x_max'},
            $self->{'curr_y_min'} - 2,
            $self->_color_role_to_index('background')
        );

        #save the actual x and y values
        $t_x_min = $self->{'curr_x_min'};
        $t_x_max = $self->{'curr_x_max'};
        $t_y_min = $self->{'curr_y_min'};
        $t_y_max = $self->{'curr_y_max'};

        #get back to the point, where everything began
        $self->{'curr_x_min'} = 0;
        $self->{'curr_y_min'} = 0;
        $self->{'curr_x_max'} = $abs_x_max;
        $self->{'curr_y_max'} = $abs_y_max;

        #draw the title again
        if ( $self->{'title'} )
        {
            $self->_draw_title;
        }

        #draw the sub title again
        if ( $self->{'sub_title'} )
        {
            $self->_draw_sub_title;
        }

        #draw the top legend again
        if ( $self->{'legend'} =~ /^top$/i )
        {
            $self->_draw_top_legend;
        }

        #reset the actual values
        $self->{'curr_x_min'} = $t_x_min;
        $self->{'curr_x_max'} = $t_x_max;
        $self->{'curr_y_min'} = $t_y_min;
        $self->{'curr_y_max'} = $t_y_max;
    }

    if ($repair_bottom_flag)
    {

        #overwrite the ugly mistakes
        # $self->{'gd_obj'}->filledRectangle ($self->{'curr_x_min'}, $self->{'curr_y_max'}+1,
        $self->{'gd_obj'}->filledRectangle(
            $self->{'curr_x_min'} - ( $self->{'brush_size'} / 2 ),
            $self->{'curr_y_max'} + 1,
            $self->{'curr_x_max'}, $abs_y_max, $self->_color_role_to_index('background')
        );

        #save the actual x and y values
        $t_x_min = $self->{'curr_x_min'};
        $t_x_max = $self->{'curr_x_max'};
        $t_y_min = $self->{'curr_y_min'};
        $t_y_max = $self->{'curr_y_max'};

        #get back to the point, where everything began
        $self->{'curr_x_min'} = 0;
        $self->{'curr_y_min'} = 0;
        $self->{'curr_x_max'} = $abs_x_max;
        $self->{'curr_y_max'} = $abs_y_max - 1;

        # mark off the graph_border space
        $self->{'curr_y_max'} -= 2 * $self->{'graph_border'};

        #draw the bottom legend again
        if ( $self->{'legend'} =~ /^bottom$/i )
        {
            $self->_draw_bottom_legend;
        }

        #draw the x label again
        if ( $self->{'x_label'} )
        {
            $self->_draw_x_label;
        }

        #get back to the start point for the ticks
        $self->{'curr_x_min'} = $self->{'temp_x_min'};
        $self->{'curr_y_min'} = $self->{'temp_y_min'};
        $self->{'curr_x_max'} = $self->{'temp_x_max'};
        $self->{'curr_y_max'} = $self->{'temp_y_max'};

        #draw the x ticks again
        $self->_draw_x_ticks;

        #reset the actual values
        $self->{'curr_x_min'} = $t_x_min;
        $self->{'curr_x_max'} = $t_x_max;
        $self->{'curr_y_min'} = $t_y_min;
        $self->{'curr_y_max'} = $t_y_max;
    }

    return;

}

## be a good module and return 1
1;
