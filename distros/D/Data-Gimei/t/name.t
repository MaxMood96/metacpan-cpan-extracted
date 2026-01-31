use 5.010;
use strict;
use warnings;
use utf8;

use Data::Gimei;

use Test2::V1 -utf8;
use Test2::Tools::Spec;

describe "Data::Gimei::Name" => sub {
    my ( $male, $female );
    before_all setup => sub {
        Data::Gimei::Name::load('t/names.yml');
        $male   = Data::Gimei::Name->new( gender => 'male' );
        $female = Data::Gimei::Name->new( gender => 'female' );
    };

    it "to_s" => sub {
        T2->is( $male->to_s,   'male, 佐藤 愛斗, さとう あいと, サトウ アイト, Aito Sato', 'male' );
        T2->is( $female->to_s, 'female, 佐藤 和柚, さとう わゆ, サトウ ワユ, Wayu Sato', 'female' );
    };

    it "getter" => sub {
        T2->is( $male->gender,   'male' );
        T2->is( $male->kanji,    '佐藤 愛斗' );
        T2->is( $male->hiragana, 'さとう あいと' );
        T2->is( $male->katakana, 'サトウ アイト' );
        T2->is( $male->romaji,   'Aito Sato', "romaji() returns capitalized romaji" );
        T2->is( $male->forename->to_s, '愛斗, あいと, アイト, Aito' );
        T2->is( $male->surname->to_s,  '佐藤, さとう, サトウ, Sato' );
        T2->is( $female->gender,       'female' );
    };

    it "getter with separator" => sub {
        T2->is( $male->kanji('/'),    '佐藤/愛斗' );
        T2->is( $male->hiragana('/'), 'さとう/あいと' );
        T2->is( $male->katakana('/'), 'サトウ/アイト' );
        T2->is( $male->romaji('/'),   'Aito/Sato' );
    };
};

T2->done_testing();
