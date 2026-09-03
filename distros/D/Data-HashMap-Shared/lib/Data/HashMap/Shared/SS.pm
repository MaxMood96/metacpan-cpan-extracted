package Data::HashMap::Shared::SS;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::SS/shm_ss_put"}        = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_get"}        = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_remove"}     = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_exists"}     = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_size"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_keys"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_values"}     = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_items"}      = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_each"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_clear"}      = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_max_size"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_take"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_pop"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_shift"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_drain"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_touch"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_add"}              = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_update"}           = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_swap"}             = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cas"}              = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_persist"}         = 1;
    $^H{"Data::HashMap::Shared::SS/shm_ss_set_ttl"}         = 1;
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

Data::HashMap::Shared::SS - shared-memory hash map, string keys to string values

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
