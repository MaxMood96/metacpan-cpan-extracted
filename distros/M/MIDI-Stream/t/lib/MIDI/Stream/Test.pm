use strict;
use warnings;
package
    MIDI::Stream::Test;

# ABSTRACT: Common test functions

use v5.26;
use Test2::V0;
use FindBin;

use MIDI::Stream::Encoder;
use MIDI::Stream::Decoder;

my $test_data_dir = "$FindBin::Bin/test_data/";

BEGIN {
    return if eval {
        require JSON::MaybeXS;
        JSON::MaybeXS->import( 'decode_json' ); 1;
    };
    require JSON::PP;
    JSON::PP->import( 'decode_json' );
}

use experimental qw/ signatures /;

use parent 'Exporter';

sub test_data( $file ) {
    decode_json do {
        open my $fh, '<', $file or die "Can't open $file: $!";
        local $/ = undef;
        <$fh>;
    }
}

sub encode_hex( $string ) {
    join ' ', unpack '(H2)*', $string;
}

sub decode_hex( $string ) {
    pack 'H*', $string =~ y/ //dr;
}

sub midi_eq( $string, $midi ) {
    decode_hex( $string ) eq $midi;
}

sub random_chunks {
    my @bytes = @_ == 1
        ? unpack( '(a1)*', $_[0] )
        : @_;
    my @chunks;

    while ( @bytes ) {
        push @chunks, join '', splice @bytes, 0, rand( @bytes / 2 ) + 1;
    }

    @chunks;
}

sub run_encoding_tests( $data, $params = {} ) {
    $params->{ concat } //= rand() < 0.5;
    my $encoder = MIDI::Stream::Encoder->new( $params->%* );
    for my $test ( $data->{ tests }->@* ) {
        my $midi = $params->{ concat }
            ? $encoder->encode_events( $test->{ data }->@* )
            : join '', $encoder->encode_events( $test->{ data }->@* );
        is( encode_hex( $midi ), $test->{expect}, "$test->{description}" );
    }
}

sub run_decoding_tests( $data, $params = {} ) {
    my $decoder = MIDI::Stream::Decoder->new( $params->%* );
    for my $test ( $data->{ tests }->@* ) {
        $decoder->decode( decode_hex( $test->{ data } ) );
        my @events = map {
            $_->TO_JSON
        } $decoder->events;
        is( \@events, $test->{expect}, "$test->{description}" );
    }
}

sub run_file( $spec ) {
    my ( $midi_version, $test_type, $filename, $params ) = $spec->@{ qw/ midi_version test_type filename params / };
    $midi_version //= 1;
    my $data = test_data( qq{$test_data_dir/MIDI_$midi_version/$test_type/$filename} );
    my $run_tests = __PACKAGE__->can( qq(run_${test_type}_tests) );

    $run_tests->( $data, $params );
}

our @EXPORT_OK = qw/
    test_data
    encode_hex
    decode_hex
    midi_eq
    random_chunks
    run_file
/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );
