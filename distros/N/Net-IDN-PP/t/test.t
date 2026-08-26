#!/usr/bin/env perl
use open qw(:std :encoding(UTF-8));
use Test::More;
use vars qw(@ENCODE_TESTS @DECODE_TESTS);
use common::sense;

my $class = q{Net::IDN::PP};

require_ok($class);

@ENCODE_TESTS = (
    [ q{café}                       => q{xn--caf-dma}               ],
    [ q{café.com}                   => q{xn--caf-dma.com}           ],
    [ q{com.café}                   => q{com.xn--caf-dma}           ],
    [ q{CAFÉ}                       => q{xn--caf-dma}               ],
    [ q{müller}                     => q{xn--mller-kva}             ],
    [ q{jürg.xn--mller-kva}         => q{xn--jrg-hoa.xn--mller-kva} ],
    [ qq{\x{1F985}}                 => q{xn--4s9h}                  ],
    [ q{ä ö ü ß}                    => q{xn--   -7kav3ivb}          ],
    [ q{}                           => q{}                          ],

    #
    # see https://www.ietf.org/archive/id/draft-rodenhaeuser-idna-transparent-resolution-00.html#name-test-vectors
    #
    [ q{straße.de}                  => q{xn--strae-oqa.de}          ],  # Nontransitional: ß is preserved.
    [ q{STRAẞE.de}                  => q{xn--strae-oqa.de}          ],  # Requires table version 15.1 or later; older tables yield strasse.de (see Section 9.1).
    [ q{faß.de}                     => q{xn--fa-hia.de}             ],  # Transitional processing would yield fass.de and is forbidden.
    [ q{bloß.de}                    => q{xn--blo-7ka.de}            ],
    [ q{müller-straße.de}           => q{xn--mller-strae-46a18a.de} ],  # (input in NFD) Processing normalizes; callers need not supply NFC.
    [ q{σοφός.gr}                   => q{xn--0xagbn4a.gr}           ],  # Residual case asymmetry of final sigma (Section 9.3).
    [ q{ΣΟΦΌΣ.gr}                   => q{xn--0xahbl4a.gr}           ],  #       "                                       "
#   [ q{日本語。ＪＰ}                 => q{xn--wgv71a119e.jp}         ],  # Ideographic and fullwidth separators and characters are mapped by the processing itself.
    [ q{_dmarc.straße.de}           => q{_dmarc.xn--strae-oqa.de}   ],  # UseSTD3ASCIIRules=false admits the underscore label.
    [ q{_sip._tcp.example.com}      => q{_sip._tcp.example.com}     ],  # ASCII fast path (Section 5.1): no processing at all.
    [ q{xn--strae-oqa.de}           => q{xn--strae-oqa.de}          ],  # ASCII fast path: existing A-labels are never re-mapped.
#   [ q{⒈example.com}              => q{}                          ],  # error: U+2488 is disallowed; fails closed per Section 5.7.
);

@DECODE_TESTS = (
    [ q{xn--caf-dma}                => q{café}                      ],
    [ q{xn--caf-dma.com}            => q{café.com}                  ],
    [ q{com.xn--caf-dma}            => q{com.café}                  ],
    [ q{XN--CAF-DMA}                => q{café}                      ],
    [ q{xn--mller-kva}              => q{müller}                    ],
    [ q{xn--jrg-hoa.xn--mller-kva}  => q{jürg.müller}               ],
    [ q{xn--4s9h}                   => qq{\x{1F985}}                ],
    [ q{xn--   -7kav3ivb}           => q{ä ö ü ß}                   ],
    [ q{cafe.com}                   => q{cafe.com}                  ],
    [ q{CAFE.COM}                   => q{CAFE.COM}                  ],
    [ q{}                           => q{}                          ],
);

foreach my $test (@ENCODE_TESTS) {
    is($class->encode($test->[0]), $test->[1], sprintf(q{check that '%s' encodes to '%s'}, $test->[0], $test->[1]));
}

foreach my $test (@DECODE_TESTS) {
   is($class->decode($test->[0]), $test->[1], sprintf(q{check that '%s' decodes to '%s'}, $test->[0], $test->[1]));
}

done_testing;
