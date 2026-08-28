package Linux::Event::Framer::LengthPrefix;
use v5.36;
use strict;
use warnings;

our $VERSION = '0.103';

use Carp qw(croak);
use bytes ();

sub _build_definition ($class, @args) {
    croak 'LengthPrefix options must be key/value pairs' if @args % 2;
    my %opt = @args;
    my $bytes = delete $opt{bytes} // 4;
    croak 'bytes must be 1, 2, or 4'
        if $bytes != 1 && $bytes != 2 && $bytes != 4;
    my $endian = delete $opt{endian} // 'big';
    croak 'endian must be big or little'
        if $endian ne 'big' && $endian ne 'little';
    my $include_prefix = delete $opt{include_prefix} // 0;
    my $max_frame = delete $opt{max_frame};
    croak 'max_frame must be a non-negative integer'
        if defined($max_frame) && ($max_frame !~ /\A\d+\z/ || $max_frame < 0);
    croak 'unknown LengthPrefix options: ' . join(', ', sort keys %opt) if %opt;

    my $native = {
        read_mode      => 4,
        prefix_bytes   => 0 + $bytes,
        prefix_little  => $endian eq 'little' ? 1 : 0,
        include_prefix => $include_prefix ? 1 : 0,
        max_frame      => $max_frame,
    };
    return { native => $native, frame => \&_frame };
}

sub _frame ($config, $payload) {
    $payload = '' if !defined $payload;
    my $length = bytes::length($payload);
    my $bytes = $config->{prefix_bytes};
    my $max = $bytes == 1 ? 0xff : $bytes == 2 ? 0xffff : 0xffffffff;
    croak "send(): payload length $length exceeds prefix capacity $max"
        if $length > $max;
    croak "send(): payload length $length exceeds max_frame=$config->{max_frame}"
        if defined($config->{max_frame}) && $length > $config->{max_frame};

    my @octets;
    my $value = $length;
    for (1 .. $bytes) {
        unshift @octets, $value & 0xff;
        $value >>= 8;
    }
    @octets = reverse @octets if $config->{prefix_little};
    return pack('C*', @octets) . $payload;
}

1;

__END__

=head1 NAME

Linux::Event::Framer::LengthPrefix - native binary length framing declaration

=head1 SYNOPSIS

  package MessageStream;
  use parent 'Linux::Event::Stream';
  use Linux::Event::Framer 'LengthPrefix',
      bytes     => 2,         # optional; default 4
      endian    => 'big',     # default
      max_frame => 1_048_576; # optional

=head1 DESCRIPTION

Uses an unsigned one-, two-, or four-byte binary payload length in big- or
little-endian order. C<include_prefix> controls inbound delivery and
C<max_frame> bounds payload length. C<send> prepends the configured length.

=cut
