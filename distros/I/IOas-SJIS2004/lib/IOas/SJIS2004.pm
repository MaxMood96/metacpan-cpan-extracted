package IOas::SJIS2004;
######################################################################
#
# IOas::SJIS2004 - provides SJIS2004 I/O subroutines for UTF-8 script
#
# http://search.cpan.org/dist/IOas-SJIS2004/
#
# Copyright (c) 2019 INABA Hitoshi <ina@cpan.org> in a CPAN
######################################################################

use 5.00503;    # Universal Consensus 1998 for primetools
# use 5.008001; # Lancaster Consensus 2013 for toolchains

$VERSION = '0.10';
$VERSION = $VERSION;

use strict;
BEGIN { $INC{'warnings.pm'} = '' if $] < 5.006 }; use warnings; $^W=1;
use Symbol ();
use Jacode4e::RoundTrip; # pmake.bat makes META.yml, META.json and Makefile.PL by /^use /

#-----------------------------------------------------------------------------
# import
#-----------------------------------------------------------------------------

sub import {
    my $self = shift @_;
    if (defined($_[0]) and ($_[0] =~ /\A[0123456789]/)) {
        if ($_[0] != $IOas::SJIS2004::VERSION) {
            my($package,$filename,$line) = caller;
            die "$filename requires @{[__PACKAGE__]} $_[0], this is version $IOas::SJIS2004::VERSION, stopped at $filename line $line.\n";
        }
        shift @_;
    }
}

#-----------------------------------------------------------------------------
# autodetect I/O encoding from package name
#-----------------------------------------------------------------------------

(my $__package__ = __PACKAGE__) =~ s/utf81/utf8.1/i;
my $io_encoding = lc((split /::/, $__package__)[-1]);

sub _io_input ($) {
    my($s) = @_;
    if (defined $s) {
        Jacode4e::RoundTrip::convert(\$s, 'utf8.1', $io_encoding);
    }
    return $s;
};

sub _io_output ($) {
    my($s) = @_;
    Jacode4e::RoundTrip::convert(\$s, $io_encoding, 'utf8.1', {
        'OVERRIDE_MAPPING' => {

            # UTF-8.0 was popular in old days
            "\xE2\x80\x95" => "\x81\x5C", # U+2015 HORIZONTAL BAR
            "\xE2\x88\xA5" => "\x81\x61", # U+2225 PARALLEL TO
            "\xEF\xBC\x8D" => "\x81\x7C", # U+FF0D FULLWIDTH HYPHEN-MINUS

            # UTF-8.1 will be popular in someday
            "\xE2\x80\x94" => "\x81\x5C", # U+2014 EM DASH
            "\xE2\x80\x96" => "\x81\x61", # U+2016 DOUBLE VERTICAL LINE
            "\xE2\x88\x92" => "\x81\x7C", # U+2212 MINUS SIGN
        },
    });
    return $s;
};

#-----------------------------------------------------------------------------
# Octet Length as I/O Encoding
#-----------------------------------------------------------------------------

sub length (;$) {
    return CORE::length _io_output(@_ ? $_[0] : $_);
}

sub sprintf ($@) {
    my($format, @list) = map { _io_output($_) } @_;
    return _io_input(CORE::sprintf($format, @list));
}

sub substr ($$;$$) {
    if (@_ == 4) {
        my $expr = _io_output($_[0]);
        my $substr = CORE::substr($expr, $_[1], $_[2], _io_output($_[3]));
        $_[0] = _io_input($expr);
        return _io_input($substr);
    }
    elsif (@_ == 3) {
        return _io_input(CORE::substr(_io_output($_[0]), $_[1], $_[2]));
    }
    else {
        return _io_input(CORE::substr(_io_output($_[0]), $_[1]));
    }
}

#-----------------------------------------------------------------------------
# String Comparison as I/O Encoding
#-----------------------------------------------------------------------------

sub cmp ($$) { _io_output($_[0]) cmp _io_output($_[1]) }
sub eq  ($$) { _io_output($_[0]) eq  _io_output($_[1]) } # must not optimize like "$_[0] eq $_[1]"
sub ne  ($$) { _io_output($_[0]) ne  _io_output($_[1]) } # must not optimize like "$_[0] ne $_[1]"
sub ge  ($$) { _io_output($_[0]) ge  _io_output($_[1]) }
sub gt  ($$) { _io_output($_[0]) gt  _io_output($_[1]) }
sub le  ($$) { _io_output($_[0]) le  _io_output($_[1]) }
sub lt  ($$) { _io_output($_[0]) lt  _io_output($_[1]) }
sub sort (@) {
    map { $_->[0] }
    CORE::sort { $a->[1] cmp $b->[1] }
    map { [ $_, _io_output($_) ] }
    @_;
}

#-----------------------------------------------------------------------------
# Encoding Convert on I/O Operations
#-----------------------------------------------------------------------------

sub getc (;*) {
    my $fh = @_ ? Symbol::qualify_to_ref($_[0],caller()) : \*STDIN;
    my $octet = CORE::getc($fh);
    if ($io_encoding =~ /^(?:sjis2004|cp932|cp932ibm|cp932nec|sjis2004)$/) {
        if ($octet =~ /\A[\x81-\x9F\xE0-\xFC]\z/) {
            $octet .= CORE::getc($fh);

            # ('cp932'.'x') to escape from build system
            if (($io_encoding eq ('cp932'.'x')) and ($octet eq "\x9C\x5A")) {
                $octet .= CORE::getc($fh);
                $octet .= CORE::getc($fh);
            }
        }
    }
    return _io_input($octet);
}

sub readline (;*) {
    my $fh = @_ ? Symbol::qualify_to_ref($_[0],caller()) : \*ARGV;
    return wantarray ? map { _io_input($_) } <$fh> : _io_input(scalar <$fh>);
}

sub print (;*@) {
    my $fh = ((@_ >= 1) and defined(fileno(Symbol::qualify_to_ref($_[0],caller())))) ? Symbol::qualify_to_ref(shift,caller()) : Symbol::qualify_to_ref(select,caller());
    return CORE::print {$fh} (map { _io_output($_) } (@_ ? @_ : $_));
}

sub printf (;*@) {
    my $fh = ((@_ >= 1) and defined(fileno(Symbol::qualify_to_ref($_[0],caller())))) ? Symbol::qualify_to_ref(shift,caller()) : Symbol::qualify_to_ref(select,caller());
    my($format, @list) = map { _io_output($_) } (@_ ? @_ : $_);
    return CORE::printf {$fh} ($format, @list);
}

1;

__END__

=pod

=head1 NAME

IOas::SJIS2004 - provides SJIS2004 I/O subroutines for UTF-8 script

=head1 SYNOPSIS

  use IOas::SJIS2004;

    # Octet Length as I/O Encoding
    $result = IOas::SJIS2004::length($utf8str);
    $result = IOas::SJIS2004::sprintf($utf8format, @utf8list);
    $result = IOas::SJIS2004::substr($utf8expr, $offset_as_sjis2004, $length_as_sjis2004, $utf8replacement);
    $result = IOas::SJIS2004::substr($utf8expr, $offset_as_sjis2004, $length_as_sjis2004);
    $result = IOas::SJIS2004::substr($utf8expr, $offset_as_sjis2004);

    # String Comparison as I/O Encoding
    $result = IOas::SJIS2004::cmp($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::eq($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::ne($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::ge($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::gt($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::le($utf8str_a, $utf8str_b);
    $result = IOas::SJIS2004::lt($utf8str_a, $utf8str_b);
    @result = IOas::SJIS2004::sort(@utf8str);

    # Encoding Convert on I/O Operations
    $result = IOas::SJIS2004::getc(FILEHANDLE);
    $scalar = IOas::SJIS2004::readline(FILEHANDLE);
    @list   = IOas::SJIS2004::readline(FILEHANDLE);
    $result = IOas::SJIS2004::print(FILEHANDLE, @utf8str);
    $result = IOas::SJIS2004::printf(FILEHANDLE, $utf8format, @utf8list);

=head1 Count Length by

  --------------------------------------------------------
  count by    count by              count by octet
  octet       UTF-8 codepoint       in I/O encoding
  (useful)    (not so useful)       (useful)
  --------------------------------------------------------
  length      UTF8::R2::length      IOas::SJIS2004::length
  sprintf                           IOas::SJIS2004::sprintf
  substr      UTF8::R2::substr      IOas::SJIS2004::substr
  --------------------------------------------------------

=head1 Compare String by

  --------------------------------------------------------
  compare by                        compare by
  script encoding                   I/O encoding
  --------------------------------------------------------
  cmp                               IOas::SJIS2004::cmp
  eq                                IOas::SJIS2004::eq
  ne                                IOas::SJIS2004::ne
  ge                                IOas::SJIS2004::ge
  gt                                IOas::SJIS2004::gt
  le                                IOas::SJIS2004::le
  lt                                IOas::SJIS2004::lt
  sort                              IOas::SJIS2004::sort
  --------------------------------------------------------

=head1 I/O Operations

  --------------------------------------------------------
  raw I/O       I/O operations      I/O operations
  operations    in UTF-8 encoding   with encoding convert
  --------------------------------------------------------
  getc          UTF8::R2::getc      IOas::SJIS2004::getc
  <FILEHANDLE>                      IOas::SJIS2004::readline
  print                             IOas::SJIS2004::print
  printf                            IOas::SJIS2004::printf
  --------------------------------------------------------

=head1 AUTHOR

INABA Hitoshi E<lt>ina@cpan.orgE<gt>

This project was originated by INABA Hitoshi.

=head1 LICENSE AND COPYRIGHT

This software is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This software is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
