package Data::HashMap::Shared::SI16;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::SI16/shm_si16_put"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_get"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_remove"}     = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_exists"}     = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_incr"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_decr"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_incr_by"}    = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_max"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_min"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_size"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_keys"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_values"}     = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_items"}      = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_each"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_clear"}      = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_max_size"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_take"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_pop"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_shift"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_drain"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_touch"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_add"}              = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_update"}           = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_swap"}             = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cas"}             = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_persist"}         = 1;
    $^H{"Data::HashMap::Shared::SI16/shm_si16_set_ttl"}         = 1;
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

Data::HashMap::Shared::SI16 - shared-memory hash map, string keys to int16 values

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
