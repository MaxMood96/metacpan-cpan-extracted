# This file was autogenerated.

=head1 NAME

t/unit/Hydrogen/Curry/ArrayRef.t - unit tests for Hydrogen::Curry::ArrayRef

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2022-2025 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

use 5.008001;
use strict;
use warnings;
use Test2::V0 -target => "Hydrogen::Curry::ArrayRef";

isa_ok( 'Hydrogen::Curry::ArrayRef', 'Exporter::Tiny' );

my %EXPORTS = map +( $_ => 1 ), @Hydrogen::Curry::ArrayRef::EXPORT_OK;

subtest 'curry_accessor' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_accessor), 'function exists';
    ok $EXPORTS{'curry_accessor'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_accessor( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_accessor';
};

subtest 'curry_all' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_all), 'function exists';
    ok $EXPORTS{'curry_all'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_all( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_all';
};

subtest 'curry_all_true' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_all_true), 'function exists';
    ok $EXPORTS{'curry_all_true'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_all_true( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_all_true';
};

subtest 'curry_any' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_any), 'function exists';
    ok $EXPORTS{'curry_any'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_any( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_any';
};

subtest 'curry_apply' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_apply), 'function exists';
    ok $EXPORTS{'curry_apply'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_apply( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_apply';
};

subtest 'curry_clear' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_clear), 'function exists';
    ok $EXPORTS{'curry_clear'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_clear( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_clear';
};

subtest 'curry_count' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_count), 'function exists';
    ok $EXPORTS{'curry_count'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_count( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_count';
};

subtest 'curry_delete' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_delete), 'function exists';
    ok $EXPORTS{'curry_delete'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_delete( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_delete';
};

subtest 'curry_elements' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_elements), 'function exists';
    ok $EXPORTS{'curry_elements'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_elements( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_elements';
};

subtest 'curry_first' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_first), 'function exists';
    ok $EXPORTS{'curry_first'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_first( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_first';
};

subtest 'curry_first_index' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_first_index), 'function exists';
    ok $EXPORTS{'curry_first_index'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_first_index( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_first_index';
};

subtest 'curry_flatten' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_flatten), 'function exists';
    ok $EXPORTS{'curry_flatten'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_flatten( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_flatten';
};

subtest 'curry_flatten_deep' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_flatten_deep), 'function exists';
    ok $EXPORTS{'curry_flatten_deep'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_flatten_deep( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_flatten_deep';
};

subtest 'curry_for_each' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_for_each), 'function exists';
    ok $EXPORTS{'curry_for_each'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_for_each( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_for_each';
};

subtest 'curry_for_each_pair' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_for_each_pair), 'function exists';
    ok $EXPORTS{'curry_for_each_pair'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_for_each_pair( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_for_each_pair';
};

subtest 'curry_get' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_get), 'function exists';
    ok $EXPORTS{'curry_get'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_get( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_get';
};

subtest 'curry_grep' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_grep), 'function exists';
    ok $EXPORTS{'curry_grep'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_grep( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_grep';
};

subtest 'curry_head' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_head), 'function exists';
    ok $EXPORTS{'curry_head'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_head( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_head';
};

subtest 'curry_indexed' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_indexed), 'function exists';
    ok $EXPORTS{'curry_indexed'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_indexed( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_indexed';
};

subtest 'curry_insert' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_insert), 'function exists';
    ok $EXPORTS{'curry_insert'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_insert( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_insert';
};

subtest 'curry_is_empty' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_is_empty), 'function exists';
    ok $EXPORTS{'curry_is_empty'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_is_empty( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_is_empty';
};

subtest 'curry_join' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_join), 'function exists';
    ok $EXPORTS{'curry_join'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_join( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_join';
};

subtest 'curry_map' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_map), 'function exists';
    ok $EXPORTS{'curry_map'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_map( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_map';
};

subtest 'curry_max' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_max), 'function exists';
    ok $EXPORTS{'curry_max'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_max( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_max';
};

subtest 'curry_maxstr' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_maxstr), 'function exists';
    ok $EXPORTS{'curry_maxstr'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_maxstr( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_maxstr';
};

subtest 'curry_min' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_min), 'function exists';
    ok $EXPORTS{'curry_min'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_min( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_min';
};

subtest 'curry_minstr' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_minstr), 'function exists';
    ok $EXPORTS{'curry_minstr'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_minstr( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_minstr';
};

subtest 'curry_natatime' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_natatime), 'function exists';
    ok $EXPORTS{'curry_natatime'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_natatime( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_natatime';
};

subtest 'curry_not_all_true' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_not_all_true), 'function exists';
    ok $EXPORTS{'curry_not_all_true'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_not_all_true( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_not_all_true';
};

subtest 'curry_pairfirst' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairfirst), 'function exists';
    ok $EXPORTS{'curry_pairfirst'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairfirst( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairfirst';
};

subtest 'curry_pairgrep' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairgrep), 'function exists';
    ok $EXPORTS{'curry_pairgrep'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairgrep( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairgrep';
};

subtest 'curry_pairkeys' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairkeys), 'function exists';
    ok $EXPORTS{'curry_pairkeys'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairkeys( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairkeys';
};

subtest 'curry_pairmap' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairmap), 'function exists';
    ok $EXPORTS{'curry_pairmap'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairmap( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairmap';
};

subtest 'curry_pairs' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairs), 'function exists';
    ok $EXPORTS{'curry_pairs'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairs( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairs';
};

subtest 'curry_pairvalues' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pairvalues), 'function exists';
    ok $EXPORTS{'curry_pairvalues'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pairvalues( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pairvalues';
};

subtest 'curry_pick_random' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pick_random), 'function exists';
    ok $EXPORTS{'curry_pick_random'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pick_random( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pick_random';
};

subtest 'curry_pop' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_pop), 'function exists';
    ok $EXPORTS{'curry_pop'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_pop( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_pop';
};

subtest 'curry_print' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_print), 'function exists';
    ok $EXPORTS{'curry_print'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_print( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_print';
};

subtest 'curry_product' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_product), 'function exists';
    ok $EXPORTS{'curry_product'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_product( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_product';
};

subtest 'curry_push' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_push), 'function exists';
    ok $EXPORTS{'curry_push'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_push( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_push';
};

subtest 'curry_reduce' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_reduce), 'function exists';
    ok $EXPORTS{'curry_reduce'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_reduce( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_reduce';
};

subtest 'curry_reductions' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_reductions), 'function exists';
    ok $EXPORTS{'curry_reductions'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_reductions( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_reductions';
};

subtest 'curry_reset' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_reset), 'function exists';
    ok $EXPORTS{'curry_reset'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_reset( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_reset';
};

subtest 'curry_reverse' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_reverse), 'function exists';
    ok $EXPORTS{'curry_reverse'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_reverse( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_reverse';
};

subtest 'curry_sample' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_sample), 'function exists';
    ok $EXPORTS{'curry_sample'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_sample( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_sample';
};

subtest 'curry_set' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_set), 'function exists';
    ok $EXPORTS{'curry_set'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_set( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_set';
};

subtest 'curry_shallow_clone' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_shallow_clone), 'function exists';
    ok $EXPORTS{'curry_shallow_clone'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_shallow_clone( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_shallow_clone';
};

subtest 'curry_shift' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_shift), 'function exists';
    ok $EXPORTS{'curry_shift'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_shift( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_shift';
};

subtest 'curry_shuffle' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_shuffle), 'function exists';
    ok $EXPORTS{'curry_shuffle'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_shuffle( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_shuffle';
};

subtest 'curry_shuffle_in_place' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_shuffle_in_place), 'function exists';
    ok $EXPORTS{'curry_shuffle_in_place'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_shuffle_in_place( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_shuffle_in_place';
};

subtest 'curry_sort' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_sort), 'function exists';
    ok $EXPORTS{'curry_sort'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_sort( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_sort';
};

subtest 'curry_sort_in_place' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_sort_in_place), 'function exists';
    ok $EXPORTS{'curry_sort_in_place'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_sort_in_place( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_sort_in_place';
};

subtest 'curry_splice' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_splice), 'function exists';
    ok $EXPORTS{'curry_splice'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_splice( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_splice';
};

subtest 'curry_sum' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_sum), 'function exists';
    ok $EXPORTS{'curry_sum'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_sum( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_sum';
};

subtest 'curry_tail' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_tail), 'function exists';
    ok $EXPORTS{'curry_tail'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_tail( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_tail';
};

subtest 'curry_uniq' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniq), 'function exists';
    ok $EXPORTS{'curry_uniq'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniq( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniq';
};

subtest 'curry_uniq_in_place' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniq_in_place), 'function exists';
    ok $EXPORTS{'curry_uniq_in_place'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniq_in_place( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniq_in_place';
};

subtest 'curry_uniqnum' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniqnum), 'function exists';
    ok $EXPORTS{'curry_uniqnum'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniqnum( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniqnum';
};

subtest 'curry_uniqnum_in_place' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniqnum_in_place), 'function exists';
    ok $EXPORTS{'curry_uniqnum_in_place'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniqnum_in_place( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniqnum_in_place';
};

subtest 'curry_uniqstr' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniqstr), 'function exists';
    ok $EXPORTS{'curry_uniqstr'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniqstr( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniqstr';
};

subtest 'curry_uniqstr_in_place' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_uniqstr_in_place), 'function exists';
    ok $EXPORTS{'curry_uniqstr_in_place'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_uniqstr_in_place( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_uniqstr_in_place';
};

subtest 'curry_unshift' => sub {
    ok exists(&Hydrogen::Curry::ArrayRef::curry_unshift), 'function exists';
    ok $EXPORTS{'curry_unshift'}, 'function is importable';
    my $exception = dies {
        my $curried = Hydrogen::Curry::ArrayRef::curry_unshift( [] );
        is ref( $curried ), 'CODE', 'function returns a coderef';
    };
    is $exception, undef, 'no exception thrown running curry_unshift';
};

done_testing; # :)
