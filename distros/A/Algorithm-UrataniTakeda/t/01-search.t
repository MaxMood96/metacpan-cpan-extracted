#!perl

use v5.26;

use Test2::V0 -no_srand => 1;;

use Algorithm::UrataniTakeda;

use experimental qw( signatures );

my @patterns = qw( trace artist smart great test );


my $m = Algorithm::UrataniTakeda->new( \@patterns );

subtest 'search all' => sub {

    my @output;

    $m->search(
        "the-greatest-artist-has-the-smartest-traces",
        sub( $pos, $phrase ) {
            push @output, [ $pos, $phrase ];    # implicitly returns true
        }
    );

    is \@output, [

        [ 4,  "great" ],
        [ 8,  "test" ],
        [ 13, "artist" ],
        [ 28, "smart" ],
        [ 32, "test" ],
        [ 37, "trace" ]

    ],
    "expected output";

};

subtest 'search with callback indicating stop' => sub {

    my @output;

    $m->search(
        "the-greatest-artist-has-the-smartest-traces",
        sub( $pos, $phrase ) {
            push @output, [ $pos, $phrase ];
            return $phrase !~ /st$/;
        }
    );

    is \@output, [

        [ 4,  "great" ],
        [ 8,  "test" ],

    ],
    "expected output";

};

subtest 'matches' => sub {

    is [ $m->matches("the-greatest-artist-has-the-smartest-traces") ],
      [qw( great test artist smart test trace )], "expected result";

    is [ $m->matches("the-quick-brown-fox-jumped") ], [], "no result";

};

subtest 'first' => sub {

    is $m->first("the-greatest-artist-has-the-smartest-traces"), "great", "expected result";

    is $m->first("the-quick-brown-fox-jumped"), undef, "no result";

};

subtest 'has_match' => sub {

    ok $m->first("the-greatest-artist-has-the-smartest-traces"), "expected result";

    ok !$m->first("the-quick-brown-fox-jumped"), undef, "no result";

};


done_testing;
