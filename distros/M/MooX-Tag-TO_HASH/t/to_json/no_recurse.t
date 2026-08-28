#! perl

use strict;
use warnings;

use Test2::V0;
use Test::Lib;

use My::Test::TO_JSON::C3;
use constant CLASS => 'My::Test::TO_JSON::C3';

{
    package My::Test::TO_JSON::Default_No_Recurse;

    use Moo;
    with 'MooX::Tag::TO_JSON';

    has child => ( is => 'ro', to_json => 1 );
}

# cow & hen are always there
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
                hen            => 'Ruby',
                duck           => 'Donald',
                horse          => CLASS->new( horse => 'Ed' ),
                secret_admirer => 'Nemo'
            );
        },
        'obj created'
    ) or bail_out $@;

    is( $obj, D(), 'obj defined' ) or bail_out;

    is(
        $obj->TO_JSON,
        hash {
            field c3_bool => exact_ref JSON::MaybeXS::true;
            field c3_num  => number 34;
            field c3_str  => '33';
            field cow     => 'Daisy';
            field hen     => 'Ruby';
            field goose   => 'Donald';
            field horse   => object {
                call horse => 'Ed';
                call cow   => U();
                call hen   => U();
            };
            end;
        },
        'value'
    );
};

subtest 'default does not recurse' => sub {

    my $child  = CLASS->new( horse => 'Ed' );
    my $parent = My::Test::TO_JSON::Default_No_Recurse->new( child => $child );

    is(
        $parent->TO_JSON,
        hash {
            field child => object {
                call horse => 'Ed';
                call cow   => U();
                call hen   => U();
            };
            end;
        },
        'value'
    );
};

done_testing;
