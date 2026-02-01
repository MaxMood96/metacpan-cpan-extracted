NAME
    Digest::MD5::Perl - Perl implementation of Ron Rivest's MD5 Algorithm

DISCLAIMER
    This is not an interface (like "Digest::MD5") but a Perl implementation
    of MD5. It is written in perl only and because of this it is slow but it
    works without C-Code. You should use "Digest::MD5" instead of this
    module if it is available. This module is only useful for

    *   computers where you cannot install "Digest::MD5" (e.g. lack of a
        C-Compiler)

    *   hashing only small amounts of data (less than one million bytes). I
        use it to hash passwords.

    *   educational purposes

SYNOPSIS
     # Functional style
     use Digest::MD5  qw(md5 md5_hex md5_base64);

     $hash = md5 $data;
     $hash = md5_hex $data;
     $hash = md5_base64 $data;
    

     # OO style
     use Digest::MD5;

     $ctx = Digest::MD5->new;

     $ctx->add($data);
     $ctx->addfile(*FILE);

     $digest = $ctx->digest;
     $digest = $ctx->hexdigest;
     $digest = $ctx->b64digest;

DESCRIPTION
    This module has the same interface as the much faster "Digest::MD5". So
    you can easily exchange them, e.g.

            BEGIN {
              eval {
                require Digest::MD5;
                import Digest::MD5 'md5_hex'
              };
              if ($@) { # oops, no Digest::MD5
                require Digest::Perl::MD5;
                import Digest::Perl::MD5 'md5_hex'
              }             
            }

    If the "Digest::MD5" module is available it is used and if not you take
    "Digest::Perl::MD5".

    You can also install the Perl part of Digest::MD5 together with
    Digest::Perl::MD5 and use Digest::MD5 as normal, it falls back to
    Digest::Perl::MD5 if it cannot load its object files.

    For detailed documentation see the "Digest::MD5" module.

EXAMPLES
    The simplest way to use this library is to import the md5_hex() function
    (or one of its cousins):

        use Digest::Perl::MD5 'md5_hex';
        print 'Digest is ', md5_hex('foobarbaz'), "\n";

    The above example would print out the message

        Digest is 6df23dc03f9b54cc38a0fc1483df6e21

    provided that the implementation is working correctly. The same checksum
    can also be calculated in OO style:

        use Digest::MD5;
    
        $md5 = Digest::MD5->new;
        $md5->add('foo', 'bar');
        $md5->add('baz');
        $digest = $md5->hexdigest;
    
        print "Digest is $digest\n";

    The digest methods are destructive. That means you can only call them
    once and the $md5 object is reset after use. You can make a copy with
    clone:

            $md5->clone->hexdigest

LIMITATIONS
    This implementation of the MD5 algorithm has some limitations:

    *   It's slow, very slow. I've done my very best but Digest::MD5 is
        still about 100 times faster. You can only hash data up to one
        million bytes in an acceptable time. But it's very useful for
        hashing small amounts of data like passwords.

    *   You can only hash up to 2^32 bits = 512 MB on 32-bit archs. But you
        should use "Digest::MD5" for those amounts of data anyway.

SEE ALSO
    Digest::MD5

    md5(1)

    RFC 1321

    tools/md5: a small BSD compatible md5 tool written in pure perl.

COPYRIGHT
    This library is free software; you can redistribute it and/or modify it
    under the same terms as Perl itself.

     Copyright 2000 Christian Lackas, Imperia Software Solutions
     Copyright 1998-1999 Gisle Aas.
     Copyright 1995-1996 Neil Winton.
     Copyright 1991-1992 RSA Data Security, Inc.

    The MD5 algorithm is defined in RFC 1321. The basic C code implementing
    the algorithm is derived from that in the RFC and is covered by the
    following copyright:

    *   Copyright (C) 1991-1992, RSA Data Security, Inc. Created 1991. All
        rights reserved.

        License to copy and use this software is granted provided that it is
        identified as the "RSA Data Security, Inc. MD5 Message-Digest
        Algorithm" in all material mentioning or referencing this software
        or this function.

        License is also granted to make and use derivative works provided
        that such works are identified as "derived from the RSA Data
        Security, Inc. MD5 Message-Digest Algorithm" in all material
        mentioning or referencing the derived work.

        RSA Data Security, Inc. makes no representations concerning either
        the merchantability of this software or the suitability of this
        software for any particular purpose. It is provided "as is" without
        express or implied warranty of any kind.

        These notices must be retained in any copies of any part of this
        documentation and/or software.

    This copyright does not prohibit distribution of any version of Perl
    containing this extension under the terms of the GNU or Artistic
    licenses.

AUTHORS
    The original MD5 interface was written by Neil Winton (<N.Winton (at)
    axion.bt.co.uk>).

    "Digest::MD5" was made by Gisle Aas <gisle (at) aas.no> (I took his
    Interface and part of the documentation).

    Thanks to Guido Flohr for his 'use integer'-hint.

    This release was made by Christian Lackas <delta (at) lackas.net>.

