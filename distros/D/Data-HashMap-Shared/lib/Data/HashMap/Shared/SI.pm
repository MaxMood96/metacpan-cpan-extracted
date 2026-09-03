package Data::HashMap::Shared::SI;
use strict;
use warnings;
use Data::HashMap::Shared;
our $VERSION = '0.19';

sub import {
    $^H{"Data::HashMap::Shared::SI/shm_si_put"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_get"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_remove"}     = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_exists"}     = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_incr"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_decr"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_incr_by"}    = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_max"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_min"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_size"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_keys"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_values"}     = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_items"}      = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_each"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_iter_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_clear"}      = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_to_hash"}    = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_max_entries"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_get_or_set"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_put_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_max_size"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_ttl"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cursor"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cursor_next"}  = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cursor_seek"}  = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_ttl_remaining"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_capacity"}     = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_tombstones"}   = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cursor_reset"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_take"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_pop"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_shift"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_drain"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_flush_expired"}  = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_flush_expired_partial"} = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_mmap_size"}      = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_touch"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_reserve"}         = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_stat_evictions"}  = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_stat_expired"}    = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_stat_recoveries"}    = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_arena_used"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_arena_cap"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_add"}              = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_add_ttl"}          = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_update_ttl"}       = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_update"}           = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_swap"}             = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cas"}             = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_cas_take"}        = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_persist"}         = 1;
    $^H{"Data::HashMap::Shared::SI/shm_si_set_ttl"}         = 1;
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

Data::HashMap::Shared::SI - shared-memory hash map, string keys to int64 values

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
