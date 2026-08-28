#! perl

use strict;
use warnings;

use Test2::V0;
use Test::Lib;

use My::Test::TO_HASH::C2_C1;
use constant CLASS => 'My::Test::TO_HASH::C2_C1';

# cow & hen & pig are always there
# duck & horse only if not empty
# duck becomes goose
# secret_admirer is never there

#--------------------------------------------------------#

subtest 'specify all values' => sub {

    my $obj;

    ok(
        lives {
            $obj = CLASS->new(
                cow            => 'Daisy',
                duck           => 'Donald',
                hen            => 'Ruby',
                horse          => 'Ed',
                pig            => 'Wilbur',
                secret_admirer => 'Nemo',
            );
        },
        'obj created',
    ) or bail_out $@;

    is( $obj, D(), 'obj defined' ) or bail_out;

    is(
        $obj->TO_HASH,
        hash {
            field cow       => 'Daisy';
            field goose     => 'Donald';
            field hen       => 'Ruby';
            field horse     => 'Ed';
            field pig       => 'Wilbur';
            field porcupine => 'Prickly';
            end;
        },
        'value'
    );
};

#--------------------------------------------------------#

subtest 'omit values' => sub {

    my $obj;

    ok(
        lives {
            $obj = CLASS->new( secret_admirer => 'Nemo' );
        },
        'obj created',
    ) or bail_out $@;

    is( $obj, D(), 'obj defined' ) or bail_out;

    is(
        $obj->TO_HASH,
        hash {
            field cow       => U();
            field hen       => U();
            field pig       => U();
            field porcupine => 'Prickly';
            end;
        },
        'value',
    );
};

done_testing;
