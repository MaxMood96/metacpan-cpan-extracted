package Data::HashMap::Shared::IS;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::IS/shm_is_put"}        = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_get"}        = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_remove"}     = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_exists"}     = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_size"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_keys"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_values"}     = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_items"}      = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_each"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_clear"}      = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_max_size"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_ttl"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_take"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_pop"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_shift"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_drain"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_touch"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_add"}              = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_update"}           = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_swap"}             = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cas"}              = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_persist"}         = 1;
    $^H{"Data::HashMap::Shared::IS/shm_is_set_ttl"}         = 1;
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

Data::HashMap::Shared::IS - shared-memory hash map, int64 keys to string values

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
