package Data::HashMap::Shared::I32S;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_put"}        = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_get"}        = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_remove"}     = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_exists"}     = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_size"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_keys"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_values"}     = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_items"}      = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_each"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_clear"}      = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_max_size"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_take"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_pop"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_shift"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_drain"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_touch"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_add"}              = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_update"}           = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_swap"}             = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cas"}              = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_persist"}         = 1;
    $^H{"Data::HashMap::Shared::I32S/shm_i32s_set_ttl"}         = 1;
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

Data::HashMap::Shared::I32S - shared-memory hash map, int32 keys to string values

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
