use v5.42;
use feature 'class';
no warnings 'experimental::class';
#
class Net::uTP v1.0.0 {
    use Carp qw[carp croak];
    use Time::HiRes qw[gettimeofday time];

    # uTP Packet Types
    use constant { ST_DATA => 0, ST_FIN => 1, ST_STATE => 2, ST_RESET => 3, ST_SYN => 4 };

    # Protocol version
    use constant VERSION => 1;

    # LEDBAT Constants
    use constant TARGET_DELAY => 100_000;       # 100ms in microseconds
    field $conn_id_send : param;
    field $conn_id_recv : param;
    field $state        : reader = 'CLOSED';    # CLOSED, SYN_SENT, SYN_RECV, CONNECTED, FIN_SENT, RESET
    field $seq_nr;
    field $ack_nr : reader : writer = 0;
    field $window_size              = 1500;
    field $cur_window               = 0;
    field @base_delays;
    field $last_delay = 0;
    field %out_buffer : reader;
    field %in_buffer  : reader;                 # seq_nr => payload (for SACK/out-of-order)
    field $rto     = 1.0;
    field $rtt     = 0;
    field $rtt_var = 0.8;
    field %on;
    method set_in_buffer_val  ( $sn, $data ) { $in_buffer{$sn}  = $data }
    method set_out_buffer_val ( $sn, $data ) { $out_buffer{$sn} = $data }
    ADJUST { $seq_nr = int( rand(65535) ) + 1 }
    method on ( $event, $cb ) { push $on{$event}->@*, $cb }

    method _emit ( $event, @args ) {
        for my $cb ( $on{$event}->@* ) {
            try { $cb->(@args) } catch ($e) {
                carp "uTP event $event failed: $e"
            }
        }
    }

    method connect () {
        $state = 'SYN_SENT';
        my $pkt = $self->pack_header( ST_SYN, 0, $conn_id_recv );
        $out_buffer{$seq_nr} = { data => $pkt, ts => time, retries => 0 };
        $seq_nr = ( $seq_nr + 1 ) & 0xFFFF;
        $pkt;
    }

    method send_data ($data) {
        return undef unless $state eq 'CONNECTED' && defined $data && length($data) > 0;
        my $out = '';
        my $now = time;
        while ( length($data) > 0 ) {
            my $chunk = substr( $data, 0, 1400, '' );
            my $pkt   = $self->pack_header(ST_DATA) . $chunk;
            $out_buffer{$seq_nr} = { data => $pkt, ts => $now, retries => 0 };
            $out .= $pkt;
            $cur_window += length($pkt);
            $seq_nr = ( $seq_nr + 1 ) & 0xFFFF;
        }
        $out;
    }

    method tick ($delta) {
        my $now = time;
        my @to_resend;
        for my $sn ( sort { $a <=> $b } keys %out_buffer ) {
            my $entry = $out_buffer{$sn};
            if ( $now - $entry->{ts} > $rto ) {
                $entry->{retries}++;
                if ( $entry->{retries} > 4 ) {
                    $state = 'CLOSED';
                    $self->_emit('closed');
                    return $self->pack_header(ST_RESET);
                }
                $rto *= 2;
                $rto = 30 if $rto > 30;
                $entry->{ts} = $now;
                push @to_resend, $entry->{data};
                last    # Fast Retransmit: only resend the first timed out packet
            }
        }
        join '', @to_resend;
    }

    method _build_sack_extension () {
        return '' unless keys %in_buffer;

        # SACK bitmask starts from ack_nr + 2
        my $base    = ( $ack_nr + 2 ) & 0xFFFF;
        my $mask    = 0;
        my $max_bit = 0;
        for my $sn ( keys %in_buffer ) {
            my $diff = ( $sn - $base ) & 0xFFFF;
            if ( $diff >= 0 && $diff < 32 ) {
                $mask |= ( 1 << $diff );
                $max_bit = $diff if $diff > $max_bit;
            }
        }

        # Round up to nearest byte, min 4 bytes per spec recommendation
        pack 'C C V', 0, 4, $mask;    # next_ext=0, len=4, mask=32bits
    }

    method pack_header ( $type, $extension //= 0, $conn_id //= undef ) {
        my ( $s, $us ) = gettimeofday();
        my $timestamp = ( $s * 1_000_000 + $us ) & 0xFFFFFFFF;
        $conn_id //= $conn_id_send;
        my $vt   = ( VERSION << 4 ) | $type;
        my $sack = $self->_build_sack_extension();
        $extension = 1 if $sack;      # 1 = SACK
        pack( 'C C n N N N n n', $vt, $extension, $conn_id, $timestamp, $last_delay, $window_size, $seq_nr, $ack_nr ) . $sack;
    }

    method unpack_header ($data) {
        return undef if length($data) < 20;
        my %h;
        ( $h{vt}, $h{ext}, $h{conn_id}, $h{ts}, $h{t_diff}, $h{wnd}, $h{seq}, $h{ack} ) = unpack 'C C n N N N n n', $data;
        $h{type}    = $h{vt} & 0x0F;
        $h{version} = $h{vt} >> 4;
        \%h;
    }

    method _handle_sack ( $bitmask, $ack_nr ) {
        my $base  = ( $ack_nr + 2 ) & 0xFFFF;
        my @bytes = unpack 'C*', $bitmask;
        for my $i ( 0 .. @bytes ) {
            my $byte = $bytes[$i];
            for ( my $bit = 0; $bit < 8; $bit++ ) {
                $self->_ack_packet( ( $base + ( $i * 8 ) + $bit ) & 0xFFFF ) if $byte & ( 1 << $bit );
            }
        }
    }

    method _ack_packet ($sn) {
        if ( exists $out_buffer{$sn} ) {
            my $entry        = $out_buffer{$sn};
            my $measured_rtt = time - $entry->{ts};
            if ( $rtt == 0 ) {
                $rtt     = $measured_rtt;
                $rtt_var = $measured_rtt / 2;
            }
            else {
                my $alpha = 0.125;
                my $beta  = 0.25;
                $rtt_var = ( 1 - $beta ) * $rtt_var + $beta * abs( $rtt - $measured_rtt );
                $rtt     = ( 1 - $alpha ) * $rtt + $alpha * $measured_rtt;
            }
            $rto = $rtt + $rtt_var * 4;
            $rto = 0.5 if $rto < 0.5;
            $cur_window -= length $entry->{data};
            delete $out_buffer{$sn};
        }
    }

    method receive_packet ($data) {
        my $header  = $self->unpack_header($data) or return undef;
        my $payload = substr( $data, 20 );

        # Handle Extensions
        my $ext_type = $header->{ext};
        while ( $ext_type != 0 && length($payload) >= 2 ) {
            my ( $next_ext, $ext_len ) = unpack 'C C', $payload;
            if ( length($payload) < 2 + $ext_len ) {
                carp 'Malformed uTP extension';
                last;
            }
            my $ext_data = substr( $payload, 2, $ext_len );
            substr( $payload, 0, 2 + $ext_len, '' );
            $self->_handle_sack( $ext_data, $header->{ack} ) if $ext_type == 1;    # SACK
            $ext_type = $next_ext;
        }

        # Update metrics
        my ( $s, $us ) = gettimeofday();
        my $now   = ( $s * 1_000_000 + $us ) & 0xFFFFFFFF;
        my $delay = ( $now - $header->{ts} ) & 0xFFFFFFFF;
        $self->_update_base_delay($delay);
        my $min_delay = $self->_min_base_delay;
        if ($min_delay) {
            my $our_delay  = ( $delay - $min_delay ) & 0xFFFFFFFF;
            my $off_target = TARGET_DELAY - $our_delay;
            my $adj        = ( $off_target / TARGET_DELAY ) * 100;
            $window_size += $adj;
            $window_size = 1500 if $window_size < 1500;
        }
        $last_delay = $delay;

        # Handle ACKs (Cumulative)
        for my $sn ( sort { $a <=> $b } keys %out_buffer ) {
            $self->_ack_packet($sn) if ( ( ( $header->{ack} - $sn ) & 0xFFFF ) < 0x8000 );
        }
        if ( $header->{type} == ST_SYN ) {
            if ( $state eq 'CLOSED' ) {
                $state  = 'CONNECTED';
                $ack_nr = $header->{seq};
                $self->_emit('connected');
                return $self->pack_header(ST_STATE);
            }
        }
        elsif ( $header->{type} == ST_STATE ) {
            if ( $state eq 'SYN_SENT' ) {
                $state = 'CONNECTED';
                $self->_emit('connected');
            }
            $ack_nr = $header->{seq};
        }
        elsif ( $header->{type} == ST_DATA ) {
            my $sn = $header->{seq};
            if ( $sn == ( ( $ack_nr + 1 ) & 0xFFFF ) || $ack_nr == 0 ) {
                $ack_nr = $sn;
                $self->_emit( 'data', $payload );
                while ( exists $in_buffer{ ( $ack_nr + 1 ) & 0xFFFF } ) {
                    $ack_nr = ( $ack_nr + 1 ) & 0xFFFF;
                    my $buffered_payload = delete $in_buffer{$ack_nr};
                    $self->_emit( 'data', $buffered_payload );
                }
            }
            elsif ( ( ( $sn - $ack_nr ) & 0xFFFF ) < 0x8000 && $sn != $ack_nr ) {
                $in_buffer{$sn} = $payload;
            }
            return $self->pack_header(ST_STATE);
        }
        elsif ( $header->{type} == ST_RESET ) {
            $state = 'CLOSED';
            $self->_emit('closed');
        }
        elsif ( $header->{type} == ST_FIN ) {
            $state = 'CLOSED';
            $self->_emit('closed');
            return $self->pack_header(ST_STATE);
        }
        undef;
    }

    method _update_base_delay ($delay) {
        push @base_delays, $delay;
        shift @base_delays if @base_delays > 60;
    }

    method _min_base_delay () {
        return undef unless @base_delays;
        my $min = $base_delays[0];
        for (@base_delays) { $min = $_ if $_ < $min }
        $min;
    }
};
1;
