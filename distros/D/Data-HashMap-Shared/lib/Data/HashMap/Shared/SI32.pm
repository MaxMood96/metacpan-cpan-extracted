package Data::HashMap::Shared::SI32;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::SI32/shm_si32_put"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_get"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_remove"}     = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_exists"}     = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_incr"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_decr"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_incr_by"}    = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_max"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_min"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_size"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_keys"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_values"}     = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_items"}      = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_each"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_clear"}      = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_max_size"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_take"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_pop"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_shift"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_drain"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_touch"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_add"}              = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_update"}           = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_swap"}             = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cas"}             = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_persist"}         = 1;
    $^H{"Data::HashMap::Shared::SI32/shm_si32_set_ttl"}         = 1;
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

Data::HashMap::Shared::SI32 - shared-memory hash map, string keys to int32 values

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
