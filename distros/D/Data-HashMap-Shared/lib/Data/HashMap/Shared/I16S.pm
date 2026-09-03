package Data::HashMap::Shared::I16S;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_put"}        = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_get"}        = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_remove"}     = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_exists"}     = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_size"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_keys"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_values"}     = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_items"}      = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_each"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_clear"}      = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_max_size"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_ttl"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_take"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_pop"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_shift"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_drain"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_touch"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_add"}              = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_update"}           = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_swap"}             = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cas"}              = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_persist"}         = 1;
    $^H{"Data::HashMap::Shared::I16S/shm_i16s_set_ttl"}         = 1;
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

Data::HashMap::Shared::I16S - shared-memory hash map, int16 keys to string values

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
