package Number::Nary 1.100313;
# ABSTRACT: encode and decode numbers as n-ary strings

use strict;
use warnings;

use Carp qw(croak);
use Scalar::Util 0.90 qw(reftype);
use List::MoreUtils 0.09 qw(uniq);
use UDCode ();

use Sub::Exporter -setup => {
  exports => [ qw(n_codec n_encode n_decode) ],
  groups  => {
    default    => [ qw(n_codec) ],
    codec_pair => \&_generate_codec_pair,
  }
};

sub _generate_codec_pair {
  my (undef, undef, $arg, undef) = @_;

  my $local_arg = {%$arg};
  my $digits    = delete $local_arg->{digits};

  my %pair;
  @pair{qw(encode decode)} = n_codec($digits, $local_arg);
  return \%pair;
}

#pod =head1 SYNOPSIS
#pod
#pod This module lets you convert numbers into strings that encode the number using
#pod the digit set of your choice.  For example, you could get routines to convert
#pod to and from hex like so:
#pod
#pod   my ($enc_hex, $dec_hex) = n_codec('0123456789ABCDEF');
#pod
#pod   my $hex = $enc_hex->(255);  # sets $hex to FF
#pod   my $num = $dec_hex->('A0'); # sets $num to 160
#pod
#pod This would be slow and stupid, since Perl already provides the means to easily
#pod and quickly convert between decimal and hex representations of numbers.
#pod Number::Nary's utility comes from the fact that it can encode into bases
#pod composed of arbitrary digit sets.
#pod
#pod   my ($enc, $dec) = n_codec('0123'); # base 4 (for working with nybbles?)
#pod
#pod   # base64
#pod   my ($enc, $dec) = n_codec(
#pod     join('', 'A' .. 'Z', 'a' .. 'z', 0 .. 9, '+', '/', '=')
#pod   );
#pod
#pod =func n_codec
#pod
#pod   my ($encode_sub, $decode_sub) = n_codec($digit_string, \%arg);
#pod
#pod This routine returns a reference to a subroutine which will encode numbers into
#pod the given set of digits and a reference which will do the reverse operation.
#pod
#pod The digits may be given as a string or an arrayref.  This routine will croak if
#pod the set of digits contains repeated digits, or if there could be ambiguity
#pod in decoding a string of the given digits.  (Number::Nary is overly aggressive
#pod about weeding out possibly ambiguous digit sets, for the sake of the author's
#pod sanity.)
#pod
#pod The encode sub will croak if it is given input other than a non-negative
#pod integer. 
#pod
#pod The decode sub will croak if given a string that contains characters not in the
#pod digit string, or, for fixed-string digit sets, if the lenth of the string to
#pod decode is not a multiple of the length of the component digits.
#pod
#pod Valid arguments to be passed in the second parameter are:
#pod
#pod   predecode  - if given, this coderef will be used to preprocess strings
#pod                passed to the decoder
#pod
#pod   postencode - if given, this coderef will be used to postprocess strings
#pod                produced by the encoder
#pod
#pod =cut

sub _split_len_iterator {
  my ($length) = @_;

  return sub {
    my ($string, $callback) = @_;

    my $places = length($string) / $length;

    croak "string length is not a multiple of digit length"
      unless $places == int $places;

    for my $position (1 .. $places) {
      my $digit = substr $string, (-$length * $position), $length;
      $callback->($digit, $position);
    }
  }
}

sub _split_digit_iterator {
  my ($digits) = @_;

  sub {
    my ($string, $callback) = @_;
    my @digits;
    ITER: while (length $string) {
      for (@$digits) {
        if (index($string, $_) == 0) {
          push @digits, substr($string, 0, length $_, '');
          next ITER;
        }
      }
      croak "could not decompose string '$string'";
    }

    for (1 .. @digits) {
      $callback->($digits[-$_], $_);
    }
  }
}

sub _set_iterator {
  my ($digits, $length_ref) = @_;

  croak "digit set is empty" unless @$digits;
  croak "digit set contains zero-length digit"
    if do { no warnings 'uninitialized'; grep { ! length $_ } @$digits };
  croak "digit set contains repeated digits" if @$digits != uniq @$digits;

  my @lengths = uniq map { length } @$digits;

  return _split_len_iterator($lengths[0]) if @lengths == 1;

  croak "digit set may be ambiguous" if ! UDCode::is_udcode(@$digits);

  return _split_digit_iterator($digits);
}

sub n_codec {
  my ($digit_set, $arg) = @_;

  my @digits;

  if (ref $digit_set) {
    croak "digit set must be a string or arrayref"
      unless reftype $digit_set eq 'ARRAY';
    @digits = @$digit_set;
  } else {
    @digits = split //, $digit_set;
  }

  my $iterator = _set_iterator(\@digits);

  my $encode_sub = sub {
    my ($value) = @_;

    croak "value isn't an non-negative integer"
      if not defined $value
      or $value !~ /\A\d+\z/;

    my $string = '';

    if (@digits == 1) {
      $string = $digits[0] x $value;
    } else {
      while (1) {
        my $digit = $value % @digits;
        $value = int($value / @digits);
        $string = "$digits[$digit]$string";
        last unless $value;
      }
    }

    $string = $arg->{postencode}->($string) if $arg->{postencode};
    return $string;
  };

  my %digit_value = do { my $i = 0; map { $_ => $i++ } @digits; };

  my $decode_sub = sub {
    my ($string) = @_;
    return unless defined $string;

    $string = $arg->{predecode}->($string) if $arg->{predecode};

    my $value = 0;

    $iterator->($string, sub {
      my ($digit, $position) = @_;
      croak "string to decode contains invalid digits"
        unless exists $digit_value{$digit};

      # Stupid hack, but I'm just cramming unary support in here at the moment.
      # It can be polished up later, if needed.  -- rjbs, 2009-11-22
      $value += @digits == 1
              ? 1
              : ($digit_value{$digit}  *  @digits ** ($position++ - 1));
    });

    return $value;
  };

  return ($encode_sub, $decode_sub);
}

#pod =func n_encode
#pod
#pod   my $string = n_encode($value, $digit_string);
#pod
#pod This encodes the given value into a string using the given digit string.  It is
#pod written in terms of C<n_codec>, above, so it's not efficient at all for
#pod multiple uses in one process.
#pod
#pod =func n_decode
#pod
#pod   my $number = n_decode($string, $digit_string);
#pod
#pod This is the decoding equivalent to C<n_encode>, above.
#pod
#pod =cut

# If you really can't stand using n_codec, you could memoize these.
sub n_encode { (n_codec($_[1]))[0]->($_[0]) }
sub n_decode { (n_codec($_[1]))[1]->($_[0]) }

#pod =head1 EXPORTS
#pod
#pod C<n_codec> is exported by default.  C<n_encode> and C<n_decode> are exported.
#pod
#pod Pairs of routines to encode and decode may be imported by using the
#pod C<codec_pair> group as follows:
#pod
#pod   use Number::Nary -codec_pair => { digits => '01234567', -suffix => '8' };
#pod
#pod   my $encoded = encode8($number);
#pod   my $decoded = decode8($encoded);
#pod
#pod For more information on this kind of exporting, see L<Sub::Exporter>.
#pod
#pod =head1 SECRET ORIGINS
#pod
#pod I originally used this system to produce unique worksheet names in Excel.  I
#pod had a large report generating system that used Win32::OLE, and to keep track of
#pod what was where I'd Storable-digest the options used to produce each worksheet
#pod and then n-ary encode them into the set of characters that were valid in
#pod worksheet names.  Working out that set of characters was by far the hardest
#pod part.
#pod
#pod =head1 ACKNOWLEDGEMENTS
#pod
#pod Thanks, Jesse Vincent.  When I remarked, on IRC, that this would be trivial to
#pod do, he said, "Great.  Would you mind doing it?"  (Well, more or less.)  It was
#pod a fun little distraction.
#pod
#pod Mark Jason Dominus and Michael Peters offered some useful advice on how to weed
#pod out ambiguous digit sets, enabling me to allow digit sets made up of
#pod varying-length digits.
#pod
#pod =head1 SEE ALSO
#pod
#pod L<Math::BaseCalc> is in the same problem space wth Number::Nary.  It provides
#pod only an OO interface and does not reliably handle multicharacter digits or
#pod recognize ambiguous digit sets.
#pod
#pod =cut

1; # my ($encode_sub, $decode_sub) = n_codec('8675309'); # jennynary

__END__

=pod

=encoding UTF-8

=head1 NAME

Number::Nary - encode and decode numbers as n-ary strings

=head1 VERSION

version 1.100313

=head1 SYNOPSIS

This module lets you convert numbers into strings that encode the number using
the digit set of your choice.  For example, you could get routines to convert
to and from hex like so:

  my ($enc_hex, $dec_hex) = n_codec('0123456789ABCDEF');

  my $hex = $enc_hex->(255);  # sets $hex to FF
  my $num = $dec_hex->('A0'); # sets $num to 160

This would be slow and stupid, since Perl already provides the means to easily
and quickly convert between decimal and hex representations of numbers.
Number::Nary's utility comes from the fact that it can encode into bases
composed of arbitrary digit sets.

  my ($enc, $dec) = n_codec('0123'); # base 4 (for working with nybbles?)

  # base64
  my ($enc, $dec) = n_codec(
    join('', 'A' .. 'Z', 'a' .. 'z', 0 .. 9, '+', '/', '=')
  );

=head1 PERL VERSION

This library should run on perls released even a long time ago.  It should work
on any version of perl released in the last five years.

Although it may work on older versions of perl, no guarantee is made that the
minimum required version will not be increased.  The version may be increased
for any reason, and there is no promise that patches will be accepted to lower
the minimum required perl.

=head1 FUNCTIONS

=head2 n_codec

  my ($encode_sub, $decode_sub) = n_codec($digit_string, \%arg);

This routine returns a reference to a subroutine which will encode numbers into
the given set of digits and a reference which will do the reverse operation.

The digits may be given as a string or an arrayref.  This routine will croak if
the set of digits contains repeated digits, or if there could be ambiguity
in decoding a string of the given digits.  (Number::Nary is overly aggressive
about weeding out possibly ambiguous digit sets, for the sake of the author's
sanity.)

The encode sub will croak if it is given input other than a non-negative
integer. 

The decode sub will croak if given a string that contains characters not in the
digit string, or, for fixed-string digit sets, if the lenth of the string to
decode is not a multiple of the length of the component digits.

Valid arguments to be passed in the second parameter are:

  predecode  - if given, this coderef will be used to preprocess strings
               passed to the decoder

  postencode - if given, this coderef will be used to postprocess strings
               produced by the encoder

=head2 n_encode

  my $string = n_encode($value, $digit_string);

This encodes the given value into a string using the given digit string.  It is
written in terms of C<n_codec>, above, so it's not efficient at all for
multiple uses in one process.

=head2 n_decode

  my $number = n_decode($string, $digit_string);

This is the decoding equivalent to C<n_encode>, above.

=head1 EXPORTS

C<n_codec> is exported by default.  C<n_encode> and C<n_decode> are exported.

Pairs of routines to encode and decode may be imported by using the
C<codec_pair> group as follows:

  use Number::Nary -codec_pair => { digits => '01234567', -suffix => '8' };

  my $encoded = encode8($number);
  my $decoded = decode8($encoded);

For more information on this kind of exporting, see L<Sub::Exporter>.

=head1 SECRET ORIGINS

I originally used this system to produce unique worksheet names in Excel.  I
had a large report generating system that used Win32::OLE, and to keep track of
what was where I'd Storable-digest the options used to produce each worksheet
and then n-ary encode them into the set of characters that were valid in
worksheet names.  Working out that set of characters was by far the hardest
part.

=head1 ACKNOWLEDGEMENTS

Thanks, Jesse Vincent.  When I remarked, on IRC, that this would be trivial to
do, he said, "Great.  Would you mind doing it?"  (Well, more or less.)  It was
a fun little distraction.

Mark Jason Dominus and Michael Peters offered some useful advice on how to weed
out ambiguous digit sets, enabling me to allow digit sets made up of
varying-length digits.

=head1 SEE ALSO

L<Math::BaseCalc> is in the same problem space wth Number::Nary.  It provides
only an OO interface and does not reliably handle multicharacter digits or
recognize ambiguous digit sets.

=head1 AUTHOR

Ricardo Signes <cpan@semiotic.systems>

=head1 CONTRIBUTORS

=for stopwords Ricardo SIGNES Signes

=over 4

=item *

Ricardo SIGNES <rjbs@codesimply.com>

=item *

Ricardo Signes <rjbs@semiotic.systems>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2022 by Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
