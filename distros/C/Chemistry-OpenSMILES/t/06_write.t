#!/usr/bin/perl

use strict;
use warnings;
use Chemistry::OpenSMILES::Parser;
use Chemistry::OpenSMILES::Writer qw(write_SMILES);
use Test::More;

my @cases = (
    [ 'C', 'C' ],
    [ 'C=C', 'C(=C)' ],
    [ 'C=1=C=C=C=1', 'C=1(=C(=C(=C=1)))' ],
    [ 'C#C.c1ccccc1', 'C(#C).c:1(:c(:c(:c(:c(:c:1)))))' ],
    [ 'C1CC2CCCCC2CC1', 'C1(C(C2(C(C(C(C(C2(C(C1)))))))))' ],
    # A strange way to write fused rings:
    [ 'C1(CCCCC11)(CCCC1)', 'C12(C(C(C(C(C1(C(C(C(C2)))))))))' ],
    # Single bonds between two aromatic atoms must be explicitly represented:
    [ 'c1cc-ccc1', 'c:1(:c(:c(-c(:c(:c:1)))))' ],
    # Chirality information is preserved:
    [ 'N[C@](Br)(O)C', 'N([C@](Br)(O)(C))' ],
    [ 'N[C@@](Br)(O)C', 'N([C@@](Br)(O)(C))' ],
    # A regression test for previously incorrectly identified aromatic bond:
    [ 'c1(c(cccc1)F)C(=O)[O-]', 'c:1(:c(:c(:c(:c(:c:1))))(F))(C(=O)([O-]))' ],
    # Cyclooctatetraene adapted from OpenSMILES v1.0 specification:
    [ 'C/1=C/C=C\C=C/C=C\1', 'C/1(=C(/C(=C(\C(=C(/C(=C\1)))))))' ],
    # A regression test for impropertly recorded fact that 0 H atoms are present:
    [ '[C]#[O]', '[C](#[O])' ],
);

plan tests => 2 * scalar @cases;

for my $case (@cases) {
    my $parser;
    my @moieties;
    my $result;

    $parser = Chemistry::OpenSMILES::Parser->new;
    @moieties = $parser->parse( $case->[0], { raw => 1 } );
    $result = write_SMILES( \@moieties, { raw => 1 } );
    is $result, $case->[1];

    $parser = Chemistry::OpenSMILES::Parser->new;
    @moieties = $parser->parse( $result, { raw => 1 } );
    $result = write_SMILES( \@moieties, { raw => 1 } );
    is $result, $case->[1];
}
