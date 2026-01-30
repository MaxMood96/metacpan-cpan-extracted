use v5.42;
use feature 'class';
no warnings 'experimental::class';
#
class Acme::Selection::RarestFirst v1.0.0 {
    use List::Util qw[shuffle];
    field $size : param;
    field @availability = (0) x $size;    # index => count

    #
    method update ( $bitfield, $delta ) {
        for ( my $i = 0; $i < $size; $i++ ) {
            if ( $bitfield->get($i) ) {
                $availability[$i] += $delta;
            }
        }
    }

    method pick ( $my_bitfield, $priorities //= () ) {
        my @candidates;
        for ( my $i = 0; $i < $size; $i++ ) {
            next if $my_bitfield->get($i);
            next if defined $priorities && ( $priorities->[$i] // 1 ) <= 0;
            push @candidates, $i;
        }
        return undef unless @candidates;

        # Sort by:
        # 1. User priority (higher first)
        # 2. Availability (lowest first)
        # 3. Random tie-break (achieved by shuffling before sort)
        @candidates = shuffle @candidates;
        @candidates = sort {
            my $p_a     = $priorities ? ( $priorities->[$a] // 1 ) : 1;
            my $p_b     = $priorities ? ( $priorities->[$b] // 1 ) : 1;
            my $avail_a = $availability[$a] // 0;
            my $avail_b = $availability[$b] // 0;
            ( $p_b <=> $p_a ) || ( $avail_a <=> $avail_b )
        } @candidates;
        return $candidates[0];
    }

    method get_availability ($index) {
        return $availability[$index] // 0;
    }
};
#
1;
