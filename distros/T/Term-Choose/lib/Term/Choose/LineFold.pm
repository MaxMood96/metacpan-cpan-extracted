package Term::Choose::LineFold;

use warnings;
use strict;
use 5.10.0;

our $VERSION = '1.768';

use Exporter qw( import );

our @EXPORT_OK = qw( line_fold print_columns cut_to_printwidth );

use Term::Choose::Constants qw( PH SGR_ES );


BEGIN {
    if ( $ENV{TC_AMBIGUOUS_WIDE} ) {
        require Term::Choose::LineFold::CharWidthAmbiguousWide;
        Term::Choose::LineFold::CharWidthAmbiguousWide->import( 'table_char_width' );
    }
    else {
        require Term::Choose::LineFold::CharWidthDefault;
        Term::Choose::LineFold::CharWidthDefault->import( 'table_char_width' );
    }
}


my $table = table_char_width();

my $cache = {};


sub _char_width {
    #my $c = $_[0];
    my $min = 0;
    my $mid;
    my $max = $#$table;
    if ( $_[0] < $table->[0][0] || $_[0] > $table->[$max][1] ) {
        return 1;
    }
    while ( $max >= $min ) {
        $mid = int( ( $min + $max ) / 2 );
        if ( $_[0] > $table->[$mid][1] ) {
            $min = $mid + 1;
        }
        elsif ( $_[0] < $table->[$mid][0] ) {
            $max = $mid - 1;
        }
        else {
            return $table->[$mid][2];
        }
    }
    return 1;
}


sub print_columns {
    #my $str = $_[0];
    my $width = 0;
    my $c;
    for my $i ( 0 .. ( length( $_[0] ) - 1 ) ) {
        $c = ord substr $_[0], $i, 1;
        $width = $width + (
            defined $cache->{$c}
            ? $cache->{$c}
            : ( $cache->{$c} = _char_width( $c ) )
        );
    }
    return $width;
}


sub cut_to_printwidth {
    my ( $str, $avail_width, $return_remainder ) = @_;
    my $count = 0;
    my $total = 0;
    my $c;
    for my $i ( 0 .. ( length( $str ) - 1 ) ) {
        $c = ord substr $str, $i, 1;
        if ( ! defined $cache->{$c} ) {
            $cache->{$c} = _char_width( $c )
        }
        if ( ( $total = $total + $cache->{$c} ) > $avail_width ) {
            if ( ( $total - $cache->{$c} ) < $avail_width ) {
                return substr( $str, 0, $count ) . ' ', substr( $str, $count ) if $return_remainder;
                return substr( $str, 0, $count ) . ' ';
            }
            return substr( $str, 0, $count ), substr( $str, $count ) if $return_remainder;
            return substr( $str, 0, $count );

        }
        ++$count;
    }
    return $str, '' if $return_remainder;
    return $str;
}


sub line_fold {
    my ( $str, $avail_width, $opt ) = @_; #copy $str
    if ( ! length $str ) {
        return $str;
    }
    my $max_tab_width = int( $avail_width / 2 );
    for ( $opt->{init_tab}, $opt->{subseq_tab} ) {
        if ( length ) {
            s/\t/ /g;
            s/\v+/\ \ /g;
            s/[\p{Cc}\p{Noncharacter_Code_Point}\p{Cs}]//g;
            if ( length > $max_tab_width ) {
                $_ = cut_to_printwidth( $_, $max_tab_width );
            }
        }
        else {
            $_ = '';
        }
    }
    my @color;
    if ( $opt->{color} ) {
        $str =~ s/${\PH}//g;
        $str =~ s/(${\SGR_ES})/push( @color, $1 ) && ${\PH}/ge;
    }
    if ( $opt->{binary_filter} && substr( $str, 0, 100 ) =~ /[\x00-\x08\x0B-\x0C\x0E-\x1F]/ ) {
        #$str = $self->{binary_filter} == 2 ? sprintf("%v02X", $_[0]) =~ tr/./ /r : 'BNRY';  # perl 5.14
        if ( $opt->{binary_filter} == 2 ) {
            ( $str = sprintf( "%v02X", $_[0] ) ) =~ tr/./ /; # use unmodified string
        }
        else {
            $str = 'BNRY';
        }
    }
    $str =~ s/\t/ /g;
    $str =~ s/[^\v\P{Cc}]//g; # remove control chars but keep vertical spaces
    $str =~ s/[\p{Noncharacter_Code_Point}\p{Cs}]//g;
    if ( $str !~ /\R/ && print_columns( $opt->{init_tab} . $str ) <= $avail_width && ! @color ) {
        return $opt->{init_tab} . $str;
    }
    my @paragraphs;

    for my $row ( split /\R/, $str, -1 ) { # -1 to keep trailing empty fields
        my @lines;
        $row =~ s/\s+\z//;
        my @words = split( /(?<=\S)(?=\s)/, $row );
        my $line = $opt->{init_tab};

        for my $i ( 0 .. $#words ) {
            if ( print_columns( $line . $words[$i] ) <= $avail_width ) {
                $line .= $words[$i];
            }
            else {
                my $tmp;
                if ( $i == 0 ) {
                    $tmp = $opt->{init_tab} . $words[$i];
                }
                else {
                    push( @lines, $line );
                    $words[$i] =~ s/^\s+//;
                    $tmp = $opt->{subseq_tab} . $words[$i];
                }
                ( $line, my $remainder ) = cut_to_printwidth( $tmp, $avail_width, 1 );
                while ( length $remainder ) {
                    push( @lines, $line );
                    $tmp = $opt->{subseq_tab} . $remainder;
                    ( $line, $remainder ) = cut_to_printwidth( $tmp, $avail_width, 1 );
                }
            }
            if ( $i == $#words ) {
                push( @lines, $line );
            }
        }
        if ( $opt->{join} ) {
            push( @paragraphs, join( "\n", @lines ) );
        }
        else {
            if ( @lines ) {
                push( @paragraphs, @lines );
            }
            else {
                push( @paragraphs, '' );
            }
        }
    }
    if ( @color ) {
        my $last_color;
        for my $paragraph ( @paragraphs ) {
            if ( ! $opt->{join} ) {
                if ( $last_color ) {
                    $paragraph = $last_color . $paragraph;
                }
                my $count = () = $paragraph =~ /${\PH}/g;
                if ( $count ) {
                    $last_color = $color[$count - 1];
                }
            }
            $paragraph =~ s/${\PH}/shift @color/ge;
            if ( ! @color ) {
                last;
            }
        }
        $paragraphs[-1] .= "\e[0m";
    }
    if ( $opt->{join} ) {
        return join( "\n", @paragraphs );
    }
    else {
        return @paragraphs;
    }
}



1;
