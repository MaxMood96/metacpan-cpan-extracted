package Data::HashMap::Shared::II;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::II/shm_ii_put"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_get"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_remove"}     = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_exists"}     = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_incr"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_decr"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_incr_by"}    = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_max"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_min"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_size"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_keys"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_values"}     = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_items"}      = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_each"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_clear"}      = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_max_size"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_ttl"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_take"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_pop"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_shift"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_drain"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_touch"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_add"}              = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_update"}           = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_swap"}             = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cas"}             = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_persist"}         = 1;
    $^H{"Data::HashMap::Shared::II/shm_ii_set_ttl"}         = 1;
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

Data::HashMap::Shared::II - shared-memory hash map, int64 keys to int64 values

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
