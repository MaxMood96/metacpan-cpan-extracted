#! perl

use strict;
use warnings;

use Test2::V0;
use Test::Lib;

use My::Test::TO_JSON::C2_C1_R1;
use constant CLASS => 'My::Test::TO_JSON::C2_C1_R1';

# cow & hen & pig are always there
# duck & horse & donkey only if not empty
# duck becomes goose
# secret_admirer is never there

#--------------------------------------------------------#

subtest 'specify all values' => sub {

    my $obj;

    ok(
        lives {
            $obj = CLASS->new(
                cow            => 'Daisy',
                hen            => 'Ruby',
                duck           => 'Donald',
                horse          => 'Ed',
                pig            => 'Wilbur',
                donkey         => 'Donkey',
                secret_admirer => 'Nemo'
            );
        },
        'obj created'
    ) or bail_out $@;

    is( $obj, D(), 'obj defined' ) or bail_out;

    is(
        $obj->TO_JSON,
        hash {
            field c1_bool       => exact_ref JSON::MaybeXS::true;
            field c1_num        => number 14;
            field c1_str        => '13';
            field c2_c1_r1_bool => exact_ref JSON::MaybeXS::true;
            field c2_c1_r1_num  => number 84;
            field c2_c1_r1_str  => '83';
            field r1_bool       => exact_ref JSON::MaybeXS::true;
            field r1_num        => number 54;
            field r1_str        => '53';
            field cow           => 'Daisy';
            field hen           => 'Ruby';
            field pig           => 'Wilbur';
            field donkey        => 'Donkey';
            field goose         => 'Donald';
            field horse         => 'Ed';
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
        'obj created'
    ) or bail_out $@;

    is( $obj, D(), 'obj defined' ) or bail_out;

    is(
        $obj->TO_JSON,
        hash {
            field c1_bool       => exact_ref JSON::MaybeXS::true;
            field c1_num        => number 14;
            field c1_str        => '13';
            field c2_c1_r1_bool => exact_ref JSON::MaybeXS::true;
            field c2_c1_r1_num  => number 84;
            field c2_c1_r1_str  => '83';
            field r1_bool       => exact_ref JSON::MaybeXS::true;
            field r1_num        => number 54;
            field r1_str        => '53';
            field cow           => U();
            field hen           => U();
            field pig           => U();
            end;
        },
        'value'
    );
};

done_testing;
