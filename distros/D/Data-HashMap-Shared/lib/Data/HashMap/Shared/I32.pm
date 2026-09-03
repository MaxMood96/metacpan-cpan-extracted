package Data::HashMap::Shared::I32;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::I32/shm_i32_put"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_get"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_remove"}     = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_exists"}     = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_incr"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_decr"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_incr_by"}    = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_max"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_min"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_size"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_keys"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_values"}     = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_items"}      = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_each"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_clear"}      = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_max_size"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_take"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_pop"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_shift"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_drain"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_touch"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_add"}              = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_update"}           = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_swap"}             = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cas"}             = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_persist"}         = 1;
    $^H{"Data::HashMap::Shared::I32/shm_i32_set_ttl"}         = 1;
}

# `no Data::HashMap::Shared::XX;` disables this variant's keywords for the rest
# of the enclosing scope; without it the `no` was a silent no-op.
sub unimport {
    my $prefix = __PACKAGE__ . '/';
    delete $^H{$_} for grep { index($_, $prefix) == 0 } CORE::keys(%^H);
}

1;

__END__

=head1 NAME

Data::HashMap::Shared::I32 - shared-memory hash map, int32 keys to int32 values

=head1 DESCRIPTION

One of the ten typed variants of L<Data::HashMap::Shared>. See that module for
the constructor, the full API and the keyword forms, and
L<Data::HashMap::Shared/Variants> for choosing between them.

=head1 AUTHOR

vividsnow

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
