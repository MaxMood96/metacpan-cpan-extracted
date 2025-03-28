#! perl

use Test2::V0;

use Test::Lib;

use Data::Record::Serialize;

subtest "default behavior" => sub {

    my $drs;
    ok( lives { $drs = Data::Record::Serialize->new( encode => '+My::Test::Encode::store' ) },
        'construct object' )
      or note "Error: $@";

    is( $drs->nullified, [], "no nullified fields prior to sending first record" );

    # prime @fields
    $drs->send( { integer => 1, string => '', number => '' } );

    is( $drs->nullified, [], "no nullified fields after sending first record" );

    is(
        $drs->output->[-1],
        hash {
            field integer => 1;
            field string  => "";
            field number  => "";
            end;
        },
        "no output fields nullified"
    );

};


subtest "nullify boolean" => sub {

    my $drs;
    ok(
        lives {
            $drs = Data::Record::Serialize->new(
                encode  => '+My::Test::Encode::store',
                nullify => 1
            )
        },
        'construct object'
    ) or note $@;

    # prime @fields
    $drs->send( { integer => 1, string => 'string', number => 2.2 } );

    # correct list of fields to be nullified
    is(
        $drs->nullified,
        bag {
            item 'integer';
            item 'string';
            item 'number';
            end;
        },
        "correct fields nullified"
    );

    # these will be nullified
    $drs->send( { integer => 1, string => "", number => "" } );

    is(
        $drs->output->[-1],
        hash {
            field integer => 1;
            field string  => undef;
            field number  => undef;
            end;
        },
        "correct output fields nullified"
    );

    ok( lives { $drs->nullify( 0 ) }, "reset nullify" );
    is( $drs->nullified, [], "no fields nullified" );

    $drs->send( { integer => 1, string => "", number => "" } );

    is(
        $drs->output->[-1],
        hash {
            field integer => 1;
            field string  => "";
            field number  => "";
            end;
        },
        "no output fields nullified"
    );

};

subtest "bad field name" => sub {

    my $drs;
    ok(
        lives {
            $drs = Data::Record::Serialize->new(
                encode  => '+My::Test::Encode::store',
                nullify => ['foobar'] )
        },
        'construct object'
    ) or note $@;

    my $error;

    $error
      = dies { $drs->send( { integer => 1, string => "", number => "" } ); };

    isa_ok(
        $error,
        ['Data::Record::Serialize::Error::Role::Base::fields'],
        "send: caught bad nullification field error"
    );
    like( $error, qr/foobar/, 'identified bad field name' );

    $error = dies { $drs->nullified };
    isa_ok(
        $error,
        ['Data::Record::Serialize::Error::Role::Base::fields'],
        "nullified: caught bad nullification field error"
    );
    like( $error, qr/foobar/, 'identified bad field name' );


};

subtest "nullify sub" => sub {

    my $drs;
    ok(
        lives {
            $drs = Data::Record::Serialize->new(
                encode  => '+My::Test::Encode::store',
                nullify => sub { shift->numeric_fields },
            )
        },
        'construct object'
    ) or note $@;

    $drs->send( { integer => 1, string => "string", number => 2.2 } );

    is(
        $drs->nullified,
        bag {
            item 'integer';
            item 'number';
            end;
        },
        "correct fields nullified"
    );

    $drs->send( { integer => 1, string => "", number => '' } );

    is(
        $drs->output->[-1],
        hash {
            field integer => 1;
            field string  => "";
            field number  => undef;
            end;
        },
        "correct output fields nullified"
    );

};

done_testing;
