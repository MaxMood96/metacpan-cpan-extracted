#! perl

use strict;
use warnings;

use Test2::V0;
use Test::Lib;

use My::Test::TO_JSON::C1;
use constant CLASS => 'My::Test::TO_JSON::C1';

# cow & hen are always there
# duck & horse only if not empty
# hen, duck & horse recurse
# duck becomes goose
# secret_admirer is never there

#--------------------------------------------------------#

my $obj;

ok(
    lives {
        $obj = CLASS->new(
            cow => 'Daisy',
            hen => {
                Camilla => 'friendly',
                Ginger  => CLASS->new( hen => 'Ginger' ),
                Babs    => CLASS->new( hen => 'Babs' ),
                Bunty   => CLASS->new( hen => 'Bunty' ),
            },
            duck => [
                'Donald',
                CLASS->new( duck => 'Huey' ),
                CLASS->new( duck => 'Duey' ),
                CLASS->new( duck => 'Luey' ),
            ],
            horse => CLASS->new(
                horse => CLASS->new( horse => 'Ed' )
            ),
            secret_admirer => 'Nemo'
        );
    },
    'obj created'
) or bail_out $@;

is( $obj, D(), 'obj defined' ) or bail_out;

is(
    $obj->TO_JSON,
    hash {
        field c1_bool => exact_ref JSON::MaybeXS::true;
        field c1_num  => number 14;
        field c1_str  => '13';
        field cow     => 'Daisy';
        field hen     => hash {
            field Camilla => 'friendly';
            field Ginger  => hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field hen     => 'Ginger';
                field cow     => U();
                end;
            };
            field Babs => hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field hen     => 'Babs';
                field cow     => U();
                end;
            };
            field Bunty => hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field hen     => 'Bunty';
                field cow     => U();
                end;
            };
        };
        field goose => array {
            item 'Donald';
            item hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field goose   => 'Huey';
                field cow     => U();
                field hen     => U();
                end;
            };
            item hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field goose   => 'Duey';
                field cow     => U();
                field hen     => U();
                end;
            };
            item hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field goose   => 'Luey';
                field cow     => U();
                field hen     => U();
                end;
            };
            end;
        };
        field horse => meta {
            prop blessed => undef;
            prop this    => hash {
                field c1_bool => exact_ref JSON::MaybeXS::true;
                field c1_num  => number 14;
                field c1_str  => '13';
                field horse   => meta {
                    prop blessed => undef;
                    prop this    => hash {
                        field c1_bool => exact_ref JSON::MaybeXS::true;
                        field c1_num  => number 14;
                        field c1_str  => '13';
                        field horse   => 'Ed';
                        field cow     => U();
                        field hen     => U();
                        end;
                    };
                };
                field cow => U();
                field hen => U();
                end;
            };
        };
        end;
    },
    'value'
);


done_testing;
