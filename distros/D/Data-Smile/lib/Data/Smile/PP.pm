use 5.008008;
use strict;
use warnings;

package Data::Smile::PP;

use Scalar::Util qw( blessed dualvar looks_like_number );
use constant HEADER              => "\x3A\x29\x0A\x03";
use constant MAX_SAFE_INT_DOUBLE => 9_007_199_254_740_992;
use constant MIN_SIGNED_64BIT    => -9_223_372_036_854_775_808;
use constant MAX_UNSIGNED_64BIT  => 18_446_744_073_709_551_615;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.001000';

use Exporter::Tiny;
our @ISA       = qw( Exporter::Tiny );
our @EXPORT_OK = qw( encode_smile decode_smile dump_smile load_smile );

BEGIN {
	my @HELPERS = (
		_is_arrayref => [
			[ 'Ref::Util::XS', 'is_plain_arrayref' ],
			[ 'Type::Tiny::XS', 'ArrayRef' ],
			q{
				my ( $v ) = @_;
				ref( $v ) eq 'ARRAY';
			},
		],
		_is_hashref => [
			[ 'Ref::Util::XS', 'is_plain_hashref' ],
			[ 'Type::Tiny::XS', 'HashRef' ],
			q{
				my ( $v ) = @_;
				ref( $v ) eq 'HASH';
			},
		],
		_is_dual => [
			[ 'Scalar::Util', 'isdual' ],
			q{
				use B ();
				my $f = B::svref_2object(\$_[0])->FLAGS;
				my $SVp_POK = eval { B::SVp_POK() } || 0;
				my $SVp_IOK = eval { B::SVp_IOK() } || 0;
				my $SVp_NOK = eval { B::SVp_NOK() } || 0;
				my $pok  = $f & ( B::SVf_POK | $SVp_POK );
				my $niok = $f & ( B::SVf_IOK | B::SVf_NOK | $SVp_IOK | $SVp_NOK );
				!!( $pok and $niok );
			},
		],
		_is_bool => [
			[ 'builtin', 'is_bool' ],
			q{
				my $value = shift;
				return !!0 unless defined $value;
				return !!0 if ref $value;
				return !!0 unless _is_dual( $value );
				return !!1 if  $value and "$value" eq '1' and $value + 0 == 1;
				return !!1 if not $value and "$value" eq q'' and $value + 0 == 0;
				return !!0;
			},
		],
		_created_as_number => [
			[ 'builtin', 'created_as_number' ],
			q{
				use B ();
				my $value = shift;
				return !!0 unless defined $value;
				return !!0 if ref $value;
				return !!0 if utf8::is_utf8( $value );
				my $b_obj = B::svref_2object(\$value);
				my $flags = $b_obj->FLAGS;
				return !!1 if $flags & ( B::SVp_IOK() | B::SVp_NOK() ) and not( $flags & B::SVp_POK() );
				return !!0;
			},
		],
		_created_as_string => [
			[ 'builtin', 'created_as_string' ],
			q{
				my $value = shift;
				defined $value
					and not ref $value
					and not _is_bool( $value )
					and not _created_as_number( $value );
			},
		],
	);

	HELPER: while ( @HELPERS ) {
		my ( $name, $implementation_list ) = splice @HELPERS, 0, 2;
		IMPLEMENTATION: for my $i ( @$implementation_list ) {
			if ( ref $i ) {
				no strict 'refs';
				my ( $module, $external_function_name ) = @$i;
				if ( $module eq 'builtin' ) {
					$] >= 5.038 or next IMPLEMENTATION;
					require experimental;
					experimental->import( 'builtin' );
					if ( defined &{"builtin::$external_function_name"} ) {
						*$name = \&{"builtin::$external_function_name"};
						next HELPER;
					}
				}
				else {
					eval "require $module; 1" or next IMPLEMENTATION;
					my $f = $module->can( $external_function_name ) or next IMPLEMENTATION;
					*$name = $f;
					next HELPER;
				}
			}
			else {
				next HELPER if eval "sub $name { $i }; 1";
			}
		}
	}
}

sub _check_opts {
	my ( $name, $opts, $allowed ) = @_;
	return {} if not defined $opts;
	die 'Options must be a hash reference' if not _is_hashref( $opts );
	for my $k ( keys %$opts ) {
		die "Unknown option for $name: $k" if not $allowed->{$k};
	}
	return $opts;
}

sub _pack_u32 { pack('N', $_[0]) }
sub _unpack_u32 {
	my ( $buf, $pos ) = @_;
	die 'Unexpected EOF' if $$pos + 4 > length $$buf;
	my $v = unpack('N', substr($$buf, $$pos, 4));
	$$pos += 4;
	return $v;
}

sub _pack_str {
	my ( $s ) = @_;
	my $flag = utf8::is_utf8( $s ) ? 1 : 0;
	my $bytes = $s;
	utf8::encode( $bytes ) if $flag;
	return chr( $flag ) . _pack_u32( length( $bytes ) ) . $bytes;
}

sub _unpack_str {
	my ( $buf, $pos ) = @_;
	die 'Unexpected EOF' if $$pos >= length $$buf;
	my $flag = ord substr( $$buf, $$pos++, 1 );
	my $len = _unpack_u32( $buf, $pos );
	die 'Unexpected EOF' if $$pos + $len > length $$buf;
	my $s = substr( $$buf, $$pos, $len );
	$$pos += $len;
	utf8::decode( $s ) if $flag;
	return $s;
}

sub _maybe_to_json {
	my ( $v ) = @_;
	return $v if not ref $v;
	return $v if not blessed $v;
	return $v if not $v->can( 'TO_JSON' );
	return $v->TO_JSON;
}

sub _encode_value {
	my ( $v ) = @_;
	$v = _maybe_to_json( $v );

	if ( not defined $v ) {
		return 'U';
	}

	if ( _is_arrayref( $v ) ) {
		my $out = 'A' . _pack_u32(scalar @$v);
		$out .= _encode_value( $_ ) for @$v;
		return $out;
	}

	if ( _is_hashref( $v ) ) {
		my @keys = keys %$v;
		my $out = 'H' . _pack_u32(scalar @keys);
		for my $k (@keys) {
			$out .= _pack_str( $k );
			$out .= _encode_value( $v->{$k} );
		}
		return $out;
	}

	die 'Unsupported reference in encode_smile' if ref $v;

	if ( _is_bool( $v ) ) {
		return 'b' . ($v ? "\x01" : "\x00");
	}

	if ( _created_as_string( $v ) ) {
		return 'S' . _pack_str( $v );
	}

	if ( _created_as_number( $v ) or looks_like_number( $v ) ) {
		if ( $v =~ /\A-?[0-9]+\z/ and $v >= -9_223_372_036_854_775_808 and $v <= 9_223_372_036_854_775_807 ) {
			return 'I' . pack('q>', 0 + $v);
		}
		my $n = "$v";
		return 'N' . _pack_str( $n );
	}

	return 'S' . _pack_str( "$v" );
}

my ( $jppT, $jppF );

sub _decode_value {
	my ( $buf, $pos, $json_bool, $use_bigint ) = @_;
	die 'Unexpected EOF' if $$pos >= length $$buf;
	my $tag = substr $$buf, $$pos++, 1;

	return undef if $tag eq 'U';
	if ( $tag eq 'b' ) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		if ( $json_bool ) {
			if ( not defined $jppT ) {
				require JSON::PP;
				$jppT = JSON::PP::true();
				$jppF = JSON::PP::false();
			}
			return ord substr( $$buf, $$pos++, 1 ) ? $jppT : $jppF;
		}
		return ord substr( $$buf, $$pos++, 1 ) ? !!1 : !!0;
	}
	if ( $tag eq 'S' ) {
		return _unpack_str( $buf, $pos );
	}
	if ( $tag eq 'I' ) {
		die 'Unexpected EOF' if $$pos + 8 > length $$buf;
		my $v = unpack( 'q>', substr( $$buf, $$pos, 8 ) );
		$$pos += 8;
		return 0 + $v;
	}
	if ( $tag eq 'N' ) {
		my $s = _unpack_str( $buf, $pos );

		if ( $use_bigint and $s =~ /\A-?[0-9]{19,}\z/ ) {
			require Math::BigInt;
			return Math::BigInt->new( $s );
		}

		return 0 + $s;
	}
	if ( $tag eq 'A' ) {
		my $n = _unpack_u32( $buf, $pos );
		my @a;
		push @a, _decode_value( $buf, $pos, $json_bool, $use_bigint ) for 1..$n;
		return \@a;
	}
	if ( $tag eq 'H' ) {
		my $n = _unpack_u32( $buf, $pos );
		my %h;
		for (1..$n) {
			my $k = _unpack_str( $buf, $pos );
			$h{$k} = _decode_value( $buf, $pos, $json_bool, $use_bigint );
		}
		return \%h;
	}

	die "Unknown type tag in payload";
}


sub _normalize_smile_float {
	my ( $v ) = @_;
	my $text = "$v";
	my $num = 0 + $v;
	my $integer_text = sprintf '%.0f', $num;

	if (
		$num == 0 + $integer_text
		and abs( $num ) >= MAX_SAFE_INT_DOUBLE
		and $num >= MIN_SIGNED_64BIT
		and $num <= MAX_UNSIGNED_64BIT
	) {
		return dualvar( $num, $integer_text );
	}

	return dualvar( $num, $text );
}

sub _decode_vint {
	my ( $buf, $pos ) = @_;
	my $v = 0;

	while (1) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $byte = ord substr( $$buf, $$pos++, 1 );
		if ( $byte & 0x80 ) {
			$v = ( $v << 6 ) | ( $byte & 0x3F );
			last;
		}
		$v = ( $v << 7 ) | ( $byte & 0x7F );
	}

	return $v;
}

sub _zigzag_decode {
	my ( $v ) = @_;
	return ( $v & 1 ) ? -( ( $v + 1 ) >> 1 ) : ( $v >> 1 );
}


sub _decode_fixed_7bit_bytes {
	my ( $buf, $pos, $groups, $bits_needed ) = @_;
	my $bits = q{};

	for ( 1 .. $groups ) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $byte = ord substr( $$buf, $$pos++, 1 );
		$bits .= sprintf '%07b', $byte & 0x7F;
	}

	if ( defined $bits_needed and length( $bits ) > $bits_needed ) {
		$bits = substr( $bits, -$bits_needed );
	}

	my $out = q{};
	for ( my $i = 0; $i < length $bits; $i += 8 ) {
		$out .= chr oct( '0b' . substr( $bits, $i, 8 ) );
	}

	return $out;
}

sub _decode_7bit_binary {
	my ( $buf, $pos, $len ) = @_;
	my $bits = q{};

	while ( length $bits < $len * 8 ) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $byte = ord substr( $$buf, $$pos++, 1 );
		$bits .= sprintf '%07b', $byte & 0x7F;
	}

	$bits = substr( $bits, 0, $len * 8 );
	my $out = q{};
	for ( my $i = 0; $i < length $bits; $i += 8 ) {
		$out .= chr oct( '0b' . substr( $bits, $i, 8 ) );
	}

	return $out;
}


sub _raw_bytes_to_native_number {
	my ( $raw ) = @_;
	my $v = 0.0;

	for my $byte ( unpack 'C*', $raw ) {
		$v = ( $v * 256 ) + $byte;
	}

	return 0 + $v;
}

sub _decode_long_text {
	my ( $buf, $pos, $utf8 ) = @_;
	my $s = q{};

	while (1) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $byte = ord substr( $$buf, $$pos++, 1 );
		last if $byte == 0xFC;
		$s .= chr $byte;
	}

	utf8::decode( $s ) if $utf8;
	return $s;
}

sub _shared_push {
	my ( $ary, $v ) = @_;
	return if not defined $v;

	if ( @$ary >= 1024 ) {
		@$ary = ();
	}

	push @$ary, $v;
}

sub _decode_value_smile {
	my ( $buf, $pos, $ctx, $json_bool, $use_bigint ) = @_;
	die 'Unexpected EOF' if $$pos >= length $$buf;
	my $t = ord substr( $$buf, $$pos++, 1 );

	if ( $t <= 0x1F ) {
		die 'Invalid shared value reference' if $t == 0 or not defined $ctx->{shared_values}[ $t - 1 ];
		return $ctx->{shared_values}[ $t - 1 ];
	}
	if ( $t == 0x20 ) {
		_shared_push( $ctx->{shared_values}, q{} ) if $ctx->{enable_shared_values};
		return q{};
	}
	if ( $t == 0x21 ) {
		return undef;
	}
	if ( $t == 0x22 or $t == 0x23 ) {
		my $is_true = $t == 0x23;
		if ( $json_bool ) {
			if ( not defined $jppT ) {
				require JSON::PP;
				$jppT = JSON::PP::true();
				$jppF = JSON::PP::false();
			}
			return $is_true ? $jppT : $jppF;
		}
		return $is_true ? !!1 : !!0;
	}
	if ( $t == 0x24 or $t == 0x25 ) {
		my $v = _zigzag_decode( _decode_vint( $buf, $pos ) );
		return $v;
	}
	if ( $t == 0x26 ) {
		my $len = _decode_vint( $buf, $pos );
		my $raw = _decode_7bit_binary( $buf, $pos, $len );
		my $hex = unpack 'H*', $raw;

		if ( $use_bigint ) {
			require Math::BigInt;
			return Math::BigInt->from_hex( '0x' . ( $hex or '0' ) );
		}

		return _raw_bytes_to_native_number( $raw );
	}
	if ( $t == 0x2A ) {
		my $scale = _zigzag_decode( _decode_vint( $buf, $pos ) );
		my $len = _decode_vint( $buf, $pos );
		my $raw = _decode_7bit_binary( $buf, $pos, $len );
		require Math::BigInt;
		require Math::BigFloat;
		my $hex = unpack 'H*', $raw;
		my $unscaled = Math::BigInt->from_hex( '0x' . ( $hex or '0' ) );
		my $v = Math::BigFloat->new( $unscaled );
		if ( $scale > 0 ) {
			$v->bdiv( Math::BigFloat->new( 10 )->bpow( $scale ) );
		}
		elsif ( $scale < 0 ) {
			$v->bmul( Math::BigFloat->new( 10 )->bpow( -$scale ) );
		}
		return $use_bigint ? $v : 0 + $v;
	}
	if ( $t == 0x28 ) {
		my $raw = _decode_fixed_7bit_bytes( $buf, $pos, 5, 32 );
		my $v = unpack( 'f>', $raw );
		return _normalize_smile_float( $v );
	}
	if ( $t == 0x29 ) {
		my $raw = _decode_fixed_7bit_bytes( $buf, $pos, 10, 64 );
		my $v = unpack( 'd>', $raw );
		return _normalize_smile_float( $v );
	}
	if ( $t >= 0x40 and $t <= 0x7F ) {
		my $len = ( $t <= 0x5F ) ? ( ( $t & 0x1F ) + 1 ) : ( ( $t & 0x1F ) + 33 );
		die 'Unexpected EOF' if $$pos + $len > length $$buf;
		my $s = substr( $$buf, $$pos, $len );
		$$pos += $len;
		_shared_push( $ctx->{shared_values}, $s ) if $ctx->{enable_shared_values};
		return $s;
	}
	if ( $t >= 0x80 and $t <= 0xBF ) {
		my $len = ( $t <= 0x9F ) ? ( ( $t & 0x1F ) + 2 ) : ( ( $t & 0x1F ) + 34 );
		die 'Unexpected EOF' if $$pos + $len > length $$buf;
		my $s = substr( $$buf, $$pos, $len );
		$$pos += $len;
		utf8::decode( $s );
		_shared_push( $ctx->{shared_values}, $s ) if $ctx->{enable_shared_values};
		return $s;
	}
	if ( $t >= 0xC0 and $t <= 0xDF ) {
		return _zigzag_decode( $t & 0x1F );
	}
	if ( $t >= 0xE0 and $t <= 0xE3 ) {
		return _decode_long_text( $buf, $pos, 0 );
	}
	if ( $t >= 0xE4 and $t <= 0xE7 ) {
		return _decode_long_text( $buf, $pos, 1 );
	}
	if ( $t == 0xE8 ) {
		my $len = _decode_vint( $buf, $pos );
		return _decode_7bit_binary( $buf, $pos, $len );
	}
	if ( $t >= 0xEC and $t <= 0xEF ) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $lsb = ord substr( $$buf, $$pos++, 1 );
		my $idx = ( ( $t & 0x03 ) << 8 ) | $lsb;
		die 'Invalid shared value reference' if $idx < 31 or not defined $ctx->{shared_values}[$idx];
		return $ctx->{shared_values}[$idx];
	}
	if ( $t == 0xF8 ) {
		my @a;
		while (1) {
			die 'Unexpected EOF' if $$pos >= length $$buf;
			last if ord substr( $$buf, $$pos, 1 ) == 0xF9;
			push @a, _decode_value_smile( $buf, $pos, $ctx, $json_bool, $use_bigint );
		}
		$$pos++;
		return \@a;
	}
	if ( $t == 0xFA ) {
		my %h;
		while (1) {
			my $k = _decode_key_smile( $buf, $pos, $ctx );
			last if not defined $k;
			$h{$k} = _decode_value_smile( $buf, $pos, $ctx, $json_bool, $use_bigint );
		}
		return \%h;
	}

	die "Unknown type tag in payload";
}

sub _decode_key_smile {
	my ( $buf, $pos, $ctx ) = @_;
	die 'Unexpected EOF' if $$pos >= length $$buf;
	my $t = ord substr( $$buf, $$pos++, 1 );

	return undef if $t == 0xFB;

	if ( $t == 0x20 ) {
		_shared_push( $ctx->{shared_names}, q{} ) if $ctx->{enable_shared_names};
		return q{};
	}
	if ( $t >= 0x30 and $t <= 0x33 ) {
		die 'Unexpected EOF' if $$pos >= length $$buf;
		my $lsb = ord substr( $$buf, $$pos++, 1 );
		my $idx = ( ( $t & 0x03 ) << 8 ) | $lsb;
		die 'Invalid shared name reference' if $idx < 64 or not defined $ctx->{shared_names}[$idx];
		return $ctx->{shared_names}[$idx];
	}
	if ( $t >= 0x40 and $t <= 0x7F ) {
		my $idx = $t & 0x3F;
		die 'Invalid shared name reference' if not defined $ctx->{shared_names}[$idx];
		return $ctx->{shared_names}[$idx];
	}
	if ( $t >= 0x80 and $t <= 0xBF ) {
		my $len = ( $t & 0x3F ) + 1;
		die 'Unexpected EOF' if $$pos + $len > length $$buf;
		my $k = substr( $$buf, $$pos, $len );
		$$pos += $len;
		_shared_push( $ctx->{shared_names}, $k ) if $ctx->{enable_shared_names};
		return $k;
	}
	if ( $t >= 0xC0 and $t <= 0xF7 ) {
		my $len = ( $t & 0x3F ) + 2;
		die 'Unexpected EOF' if $$pos + $len > length $$buf;
		my $k = substr( $$buf, $$pos, $len );
		$$pos += $len;
		utf8::decode( $k );
		_shared_push( $ctx->{shared_names}, $k ) if $ctx->{enable_shared_names};
		return $k;
	}
	if ( $t == 0x34 ) {
		my $k = _decode_long_text( $buf, $pos, 1 );
		_shared_push( $ctx->{shared_names}, $k ) if $ctx->{enable_shared_names};
		return $k;
	}

	die 'Invalid object key token';
}

sub _contains_shared_name_pattern {
	my ( $v ) = @_;
	return 0 if not _is_arrayref( $v );
	my %seen;
	for my $e ( @$v ) {
		next if not _is_hashref( $e );
		for my $k ( keys %$e ) {
			return 1 if ++$seen{$k} > 1;
		}
	}
	return 0;
}

sub _contains_shared_short_string_value {
	my ( $v ) = @_;
	return 0 if not _is_arrayref( $v );
	my %seen;
	for my $e ( @$v ) {
		next if ref $e;
		next if not defined( $e ) or utf8::is_utf8( $e ) or length( $e ) > 64;
		return 1 if ++$seen{$e} > 1;
	}
	return 0;
}

sub _encode_vint {
	my ( $v ) = @_;
	my @groups;

	do {
		unshift @groups, $v & 0x7F;
		$v >>= 7;
	} while ( $v > 0 );

	$groups[-1] |= 0x80;
	return pack 'C*', @groups;
}

sub _zigzag_encode {
	my ( $v ) = @_;
	return ( $v < 0 ) ? ( ( -$v ) * 2 - 1 ) : ( $v * 2 );
}

sub _encode_7bit_binary {
	my ( $raw ) = @_;
	my $bits = join q{}, map { sprintf '%08b', $_ } unpack 'C*', $raw;
	my $pad = ( 7 - ( length( $bits ) % 7 ) ) % 7;
	$bits .= '0' x $pad;

	my @bytes;
	for ( my $i = 0; $i < length $bits; $i += 7 ) {
		push @bytes, oct '0b' . substr( $bits, $i, 7 );
	}

	return pack 'C*', @bytes;
}

sub _encode_short_or_long_text {
	my ( $bytes, $is_utf8 ) = @_;
	my $len = length $bytes;

	if ( not $is_utf8 and $len >= 1 and $len <= 32 ) {
		return chr( 0x40 + $len - 1 ) . $bytes;
	}
	if ( not $is_utf8 and $len >= 33 and $len <= 64 ) {
		return chr( 0x60 + $len - 33 ) . $bytes;
	}
	if ( $is_utf8 and $len >= 2 and $len <= 33 ) {
		return chr( 0x80 + $len - 2 ) . $bytes;
	}
	if ( $is_utf8 and $len >= 34 and $len <= 65 ) {
		return chr( 0xA0 + $len - 34 ) . $bytes;
	}

	my $marker = $is_utf8 ? 0xE4 : 0xE0;
	return chr( $marker ) . $bytes . "\xFC";
}

sub _encode_key_smile {
	my ( $key, $ctx ) = @_;

	if ( defined $ctx->{name_to_idx}{$key} ) {
		my $idx = $ctx->{name_to_idx}{$key};
		if ( $idx <= 63 ) {
			return chr( 0x40 + $idx );
		}
		if ( $idx <= 1023 ) {
			my $msb = ( $idx >> 8 ) & 0x03;
			my $lsb = $idx & 0xFF;
			return chr( 0x30 + $msb ) . chr( $lsb );
		}
	}

	if ( $ctx->{enable_shared_names} and @{$ctx->{shared_names}} < 1024 ) {
		if ( @{$ctx->{shared_names}} >= 1024 ) {
			$ctx->{shared_names} = [];
			$ctx->{name_to_idx} = {};
		}

		my $idx = scalar @{$ctx->{shared_names}};
		$ctx->{name_to_idx}{$key} = $idx;
		push @{$ctx->{shared_names}}, $key;
	}

	return "\x20" if $key eq q{};

	my $bytes = $key;
	my $is_utf8 = utf8::is_utf8 $bytes;
	utf8::encode( $bytes ) if $is_utf8;
	my $len = length $bytes;

	if ( not $is_utf8 and $len >= 1 and $len <= 64 ) {
		return chr( 0x80 + $len - 1 ) . $bytes;
	}
	if ( $is_utf8 and $len >= 2 and $len <= 65 ) {
		return chr( 0xC0 + $len - 2 ) . $bytes;
	}

	return "\x34" . $bytes . "\xFC";
}

sub _encode_value_smile {
	my ( $v, $ctx ) = @_;
	$v = _maybe_to_json( $v );

	if ( not defined $v ) {
		return "\x21";
	}

	if ( _is_arrayref( $v ) ) {
		my $out = "\xF8";
		$out .= _encode_value_smile( $_, $ctx ) for @$v;
		$out .= "\xF9";
		return $out;
	}

	if ( _is_hashref( $v ) ) {
		my @keys = keys %$v;
		@keys = sort @keys if $ctx->{canonical};

		my $out = "\xFA";
		for my $k ( @keys ) {
			$out .= _encode_key_smile( $k, $ctx );
			$out .= _encode_value_smile( $v->{$k}, $ctx );
		}
		$out .= "\xFB";
		return $out;
	}

	die 'Unsupported reference in encode_smile' if ref $v;

	if ( _is_bool( $v ) ) {
		return $v ? "\x23" : "\x22";
	}

	if ( _created_as_number( $v ) or looks_like_number( $v ) ) {
		if ( $v =~ /\A-?[0-9]+\z/ ) {
			my $n = 0 + $v;
			if ( $n >= -16 and $n <= 15 ) {
				return chr( 0xC0 + _zigzag_encode( $n ) );
			}
			return "\x24" . _encode_vint( _zigzag_encode( $n ) );
		}

		my $raw = pack 'd>', 0 + $v;
		return "\x29" . _encode_7bit_binary( $raw );
	}

	my $text = "$v";
	my $cache_key = utf8::is_utf8( $text ) ? "u\0$text" : "b\0$text";

	if ( $ctx->{enable_shared_values} and defined $ctx->{value_to_idx}{$cache_key} ) {
		my $idx = $ctx->{value_to_idx}{$cache_key};
		if ( $idx <= 30 ) {
			return chr( $idx + 1 );
		}
		if ( $idx <= 1023 ) {
			my $msb = ( $idx >> 8 ) & 0x03;
			my $lsb = $idx & 0xFF;
			return chr( 0xEC + $msb ) . chr( $lsb );
		}
	}

	if ( $ctx->{enable_shared_values} ) {
		if ( @{$ctx->{shared_values}} >= 1024 ) {
			$ctx->{shared_values} = [];
			$ctx->{value_to_idx} = {};
		}

		my $idx = scalar @{$ctx->{shared_values}};
		$ctx->{value_to_idx}{$cache_key} = $idx;
		push @{$ctx->{shared_values}}, $text;
	}

	my $bytes = $text;
	my $is_utf8 = utf8::is_utf8 $bytes;
	utf8::encode( $bytes ) if $is_utf8;
	return _encode_short_or_long_text( $bytes, $is_utf8 );
}

sub encode_smile {
	my ( $data, $opts ) = @_;
	die 'encode_smile expects at most 2 arguments' if @_ > 2;
	$opts = _check_opts( 'encode_smile', $opts, { write_header => 1, shared_values => 1, shared_names => 1, canonical => 1 } );

	my $write_header = exists $opts->{write_header} ? !!$opts->{write_header} : 1;
	my $shared_values = exists $opts->{shared_values} ? !!$opts->{shared_values} : 1;
	my $shared_names = exists $opts->{shared_names} ? !!$opts->{shared_names} : 1;
	my $canonical = exists $opts->{canonical} ? !!$opts->{canonical} : 0;

	my %ctx = (
		shared_names => [],
		name_to_idx => {},
		shared_values => [],
		value_to_idx => {},
		enable_shared_names => !!$shared_names,
		enable_shared_values => !!$shared_values,
		canonical => $canonical,
	);

	my $payload = _encode_value_smile( $data, \%ctx );
	my $out = $write_header
		? substr( HEADER, 0, 3 ) . chr( $shared_names | ( $shared_values << 1 ) )
		: '';
	$out .= $payload;
	return $out;
}

sub decode_smile {
	my ( $bytes, $opts ) = @_;
	die 'decode_smile expects at most 2 arguments' if @_ > 2;
	$opts = _check_opts( 'decode_smile', $opts, { use_bigint => 1, require_header => 1, json_bool => 1 } );
	my $use_bigint = exists $opts->{use_bigint} ? !!$opts->{use_bigint} : 1;
	my $require_header = exists $opts->{require_header} ? !!$opts->{require_header} : 0;
	my $json_bool = exists $opts->{json_bool} ? !!$opts->{json_bool} : 1;

	my $pos = 0;
	my $has_header = 0;
	if ( substr( $bytes, 0, 3 ) eq "\x3A\x29\x0A" ) {
		$pos = 4;
		$has_header = 1;
	}
	elsif ( $require_header ) {
		die 'Smile header required';
	}

	if ( $pos < length $bytes and substr( $bytes, $pos, 1 ) eq "\x7A" ) {
		$pos++;
		die 'Unexpected EOF' if $pos >= length $bytes;
		my $flags = ord substr( $bytes, $pos++, 1 );
		$pos++ if $flags & 0x01;
		$pos++ if $flags & 0x02;

		my $len = _unpack_u32( \$bytes, \$pos );
		die 'Unexpected EOF' if $pos + $len > length $bytes;
		my $payload = substr( $bytes, $pos, $len );
		$pos += $len;

		my $inner = 0;
		my $value = _decode_value( \$payload, \$inner, $json_bool, $use_bigint );
		return $value;
	}

	my $flags = $has_header ? ord substr( $bytes, 3, 1 ) : 0x01;
	my %ctx = (
		shared_names => [],
		shared_values => [],
		enable_shared_names => $has_header ? !!($flags & 0x01) : !!1,
		enable_shared_values => $has_header ? !!($flags & 0x02) : !!0,
	);

	my $value = _decode_value_smile( \$bytes, \$pos, \%ctx, $json_bool, $use_bigint );
	while ( $pos < length $bytes ) {
		my $rest = ord substr( $bytes, $pos, 1 );
		last if $rest == 0xFF;
		if ( $rest == 0x0A or $rest == 0x0D or $rest == 0x09 or $rest == 0x20 ) {
			$pos++;
			next;
		}
		die 'Invalid payload';
	}
	return $value;
}

sub _is_pathish_filename {
	my ( $x ) = @_;
	return 0 if not ref $x;
	return 1 if eval { $x->isa('Path::Tiny') } or eval { $x->isa('Path::Class::File') };
	return 0;
}

sub _open_for_read {
	my ( $file ) = @_;

	if ( _is_pathish_filename( $file ) ) {
		$file = "$file";
	}

	if ( not ref $file ) {
		open my $fh, '<:raw', $file or die "open($file) for read: $!";
		return ( $fh, 1 );
	}

	if ( eval { $file->can('read') } or eval { $file->can('getline') } or ref( $file ) eq 'GLOB' ) {
		binmode( $file, ':raw' );
		return ( $file, 0 );
	}

	die "Unsupported file argument for read";
}

sub _open_for_write {
	my ( $file ) = @_;

	if ( _is_pathish_filename( $file ) ) {
		$file = "$file";
	}

	if ( not ref $file ) {
		open my $fh, '>:raw', $file or die "open($file) for write: $!";
		return ( $fh, 1 );
	}

	if ( eval { $file->can('print') } or eval { $file->can('write') } or ref( $file ) eq 'GLOB' ) {
		binmode( $file, ':raw' );
		return ( $file, 0 );
	}

	die "Unsupported file argument for write";
}

sub dump_smile {
	my ( $file, $data, $opts ) = @_;
	die 'dump_smile expects at most 3 arguments' if @_ > 3;

	if ( @_ >= 3 and defined $opts ) {
		die 'Options must be a hash reference' if not _is_hashref( $opts );
	}

	my ( $fh, $close ) = _open_for_write( $file );

	my $bytes = encode_smile( $data, $opts );
	my $ok = eval {
		print {$fh} $bytes or die "write: $!";
		1;
	} ? 1 : 0;

	if ( $close ) {
		close $fh or $ok = 0;
	}

	return $ok ? 1 : 0;
}

sub load_smile {
	my ( $file, $opts ) = @_;
	die 'load_smile expects at most 2 arguments' if @_ > 2;

	if ( @_ >= 2 and defined $opts ) {
		die 'Options must be a hash reference' if not _is_hashref( $opts );
	}

	my ( $fh, $close ) = _open_for_read( $file );

	my $buf = do { local $/; <$fh> };
	die "read failed" if not defined $buf;

	if ( $close ) {
		close $fh or die "close: $!";
	}

	return decode_smile( $buf, $opts );
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Data::Smile::PP - pure-Perl encoder/decoder for Smile data

=head1 SYNOPSIS

	use Data::Smile::PP qw( encode_smile decode_smile dump_smile load_smile );

	my $bytes = encode_smile( { hello => 'world' } );
	my $data  = decode_smile( $bytes );

	dump_smile( 'example.smile', { answer => 42 } );
	my $round_trip = load_smile( 'example.smile' );

=head1 DESCRIPTION

This module provides a pure Perl implementation of Smile serialisation.
It exports four optional functions:

=over 4

=item * C<encode_smile>

=item * C<decode_smile>

=item * C<dump_smile>

=item * C<load_smile>

=back

All option arguments are optional hashrefs. Passing any other kind of
reference for options throws an exception.

=head1 FUNCTIONS

=head2 encode_smile( $data, \%options )

Encodes a Perl data structure into Smile bytes and returns a byte string.

Recognised options:

=over 4

=item * C<write_header> (boolean, default true)

Include the module's Smile transport header before the payload.

=item * C<shared_names> (boolean, default true)

Enable the shared-name marker flag when repeated object/hash key names are
observed.

=item * C<shared_values> (boolean, default true)

Enable the shared short-string-value marker flag when repeated short,
non-UTF-8 scalar values are observed.

=item * C<canonical> (boolean, default false)

If true, encode hashes/objects with keys sorted lexically.

This is slower, but should (in theory) result in byte-identical output
every time, given the same input. If you care about speed, you should be
using L<Data::Smile::XS> anyway.

=back

Unknown option keys throw an exception.

=head2 decode_smile( $bytes, \%options )

Decodes Smile bytes into Perl data and returns the resulting structure.

Recognised options:

=over 4

=item * C<use_bigint> (boolean, default true)

For Smile big-integer and big-decimal values, return big-number
objects (C<Math::BigInt>/C<Math::BigFloat>) instead of native
numeric scalars.

=item * C<require_header> (boolean, default false)

Require the Smile header to be present. If true and no header is found,
decoding throws an exception.

=item * C<json_bool> (boolean, default true)

If true, decode booleans as C<JSON::PP> booleans (C<JSON::PP::true> and
C<JSON::PP::false>) when available. If false, decode booleans as native Perl
booleans.

=back

Unknown option keys throw an exception.

=head2 dump_smile( $file, $data, \%options )

Encodes C<$data> using C<encode_smile> and writes the bytes to C<$file>.
Returns true on success and false on write/close failure.

C<$file> may be:

=over 4

=item * a filename string

=item * an open writable filehandle

=item * a C<Path::Tiny> object

=item * a C<Path::Class::File> object

=back

The C<\%options> hashref is passed through to C<encode_smile>, so it accepts
the same options and defaults: C<write_header>, C<shared_names>,
C<shared_values>, and C<canonical>.

=head2 load_smile( $file, \%options )

Reads Smile bytes from C<$file>, decodes them with C<decode_smile>, and
returns the resulting data structure.

C<$file> may be:

=over 4

=item * a filename string

=item * an open readable filehandle

=item * a C<Path::Tiny> object

=item * a C<Path::Class::File> object

=back

The C<\%options> hashref is passed through to C<decode_smile>, so it accepts
the same options and defaults: C<use_bigint>, C<require_header>, and
C<json_bool>.

=head1 BUGS

Please report any bugs to
L<https://github.com/tobyink/p5-data-smile/issues>.

=head1 SEE ALSO

L<Data::Smile>,
L<Data::Smile::XS>,
L<https://github.com/FasterXML/smile-format-specification/blob/master/smile-specification.md>
(Smile format specification),
L<https://en.wikipedia.org/wiki/Smile_(data_interchange_format)>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2026 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
