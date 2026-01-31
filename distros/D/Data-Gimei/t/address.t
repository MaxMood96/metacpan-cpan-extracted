use 5.010;
use strict;
use warnings;
use utf8;

use Data::Gimei;
Data::Gimei::Address::load('t/addresses.yml');

use Test2::V1 -utf8;
use Test2::Tools::Spec;

describe "Data::Gimei::Address" => sub {
    my ($addr);
    before_all setup => sub {
        $addr = Data::Gimei::Address->new();
    };

    it "to_s" => sub {
        T2->is( $addr->to_s,
                '北海道 札幌市中央区 モエレ沼公園, '
              . 'ほっかいどう さっぽろしちゅうおうく もえれぬまこうえん, '
              . 'ホッカイドウ サッポロシチュウオウク モエレヌマコウエン' );
    };

    it "getter" => sub {
        T2->is( $addr->kanji,    '北海道札幌市中央区モエレ沼公園' );
        T2->is( $addr->hiragana, 'ほっかいどうさっぽろしちゅうおうくもえれぬまこうえん' );
        T2->is( $addr->katakana, 'ホッカイドウサッポロシチュウオウクモエレヌマコウエン' );
        T2->ok( !$addr->can('romaji'), 'Address doesn\'t define method romaji().' );

        T2->is( $addr->prefecture->to_s,   '北海道, ほっかいどう, ホッカイドウ, ', 'prefecture' );
        T2->is( $addr->prefecture->romaji, undef );
        T2->is( $addr->city->to_s,         '札幌市中央区, さっぽろしちゅうおうく, サッポロシチュウオウク, ', 'city' );
        T2->is( $addr->city->romaji,       undef );
        T2->is( $addr->town->to_s,         'モエレ沼公園, もえれぬまこうえん, モエレヌマコウエン, ', 'town' );
        T2->is( $addr->town->romaji,       undef );
    };

    it "getter with separator" => sub {
        T2->is( $addr->kanji('/'),    '北海道/札幌市中央区/モエレ沼公園' );
        T2->is( $addr->hiragana('/'), 'ほっかいどう/さっぽろしちゅうおうく/もえれぬまこうえん' );
        T2->is( $addr->katakana('/'), 'ホッカイドウ/サッポロシチュウオウク/モエレヌマコウエン' );
    };
};
T2->done_testing;
