package Devel::StatProfiler::EvalSource;

use strict;
use warnings;

use Devel::StatProfiler::EvalSourceStorage;
use Devel::StatProfiler::Utils qw(
    check_serializer
    read_data
    read_file
    state_dir
    utf8_sha1
    write_data_any
    write_file
);
use File::Path;
use File::Spec::Functions;

sub new {
    my ($class, %opts) = @_;
    my $self = bless {
        all             => {},
        seen_in_process => {},
        hashed          => {},
        serializer      => $opts{serializer} || 'storable',
        root_dir        => $opts{root_directory},
        shard           => $opts{shard},
        genealogy       => $opts{genealogy},
        storage         => undef,
    }, $class;

    if ($self->{root_dir}) {
        my $storage_base = File::Spec::Functions::catdir($self->{root_dir}, '__source__');
        $self->{storage} = Devel::StatProfiler::EvalSourceStorage->new(
            base_dir    => $storage_base,
        ),
    }

    check_serializer($self->{serializer});

    return $self;
}

my $HOLE = "\x00" x 20;

sub add_sources_from_reader {
    my ($self, $r) = @_;

    my ($process_id, $process_ordinal) = @{$r->get_genealogy_info};
    my $source_code = $r->get_source_code;
    for my $name (keys %$source_code) {
        my $hash = utf8_sha1($source_code->{$name});

        warn "Duplicate eval STRING source code for eval '$name'"
            if exists $self->{seen_in_process}{$process_id}{$name} &&
               $self->{seen_in_process}{$process_id}{$name} ne $hash;
        $self->{seen_in_process}{$process_id}{$name} = $hash;
        $self->{all}{$process_id}{$process_ordinal}{sparse}{$name} = $hash;
        $self->{hashed}{$hash} = $source_code->{$name};
    }
}

sub update_genealogy {
    my ($self, $process_id, $process_ordinal, $parent_id, $parent_ordinal) = @_;

    $self->{genealogy}{$process_id}{$process_ordinal} = [$parent_id, $parent_ordinal];
}

# this tries to optimize for the case where we dumped all evals, the number
# of evals is unlikely to be an issue when we only dump traced ones
sub _pack_data {
    my ($self) = @_;
    my $all = $self->{all};

    for my $process_id (keys %$all) {
        ORDINAL: for my $ordinal (keys %{$all->{$process_id}}) {
            my $first = $all->{$process_id}{$ordinal}{first};
            my $next = $first && $first + length($all->{$process_id}{$ordinal}{packed}) / 20;

            # files are processed in sequential order, and either we have all the
            # evals handed to us in order, or we have holes in the sequence
            # (depending on save_source mode)
            next if $first && !exists $all->{$process_id}{$ordinal}{sparse}{"(eval $next)"};
            my @indices = sort { $a <=> $b }
                          map  { /^\(eval ([0-9]+)\)$/ ? ($1) : () }
                               keys %{$all->{$process_id}{$ordinal}{sparse}};
            my $curr;
            if (!$first) {
                for my $index (@indices) {
                    if (!$first) {
                        $first = $index;
                        $next = $first + 1;
                    } elsif ($next == $index) {
                        ++$next
                    } else {
                        # not contiguous, bail out
                        next ORDINAL;
                    }
                }
                $all->{$process_id}{$ordinal}{first} = $curr = $first;
            } else {
                $curr = $next;
            }

            for my $name (@indices) {
                my $hash = delete $all->{$process_id}{$ordinal}{sparse}{"(eval $curr)"};
                $all->{$process_id}{$ordinal}{packed} .= $hash;
                ++$curr;
            }
        }
    }
}

sub _save {
    my ($self, $state_dir, $is_part) = @_;

    $state_dir //= state_dir($self);
    $self->_pack_data;

    # $self->{seen_in_process} can be reconstructed from $self->{all}
    write_data_any($is_part, $self, $state_dir, 'source', $self->{all})
        if %{$self->{all}};

    my $storage = $self->{storage};
    for my $hash (keys %{$self->{hashed}}) {
        my $unpacked = unpack "H*", $hash;

        $storage->add_source_string($unpacked, $self->{hashed}{$hash});
    }
}

sub save_part { $_[0]->_save($_[1], 1) }
sub save_merged { $_[0]->_save(undef, 0) }

sub _merge_source {
    my ($self, $all) = @_;

    for my $process_id (keys %$all) {
        for my $ordinal (keys %{$all->{$process_id}}) {
            my $entry = $all->{$process_id}{$ordinal};
            my $self_entry = $self->{all}{$process_id}{$ordinal} //= {};

            for my $name (keys %{$entry->{sparse} //
                                     # backwards compatibility
                                     $entry}) {
                my $hash = $entry->{sparse}{$name} //
                    # backwards compatibility
                    $entry->{$name};
                # backwards compatibility
                $hash = pack "H*", $hash if length($hash) == 40;

                warn "Duplicate eval STRING source code for eval '$name'"
                    if exists $self->{seen_in_process}{$process_id}{$name} &&
                       $self->{seen_in_process}{$process_id}{$name} ne $hash;
                $self->{seen_in_process}{$process_id}{$name} = $hash;
                $self_entry->{sparse}{$name} = $hash;
            }

            if ($entry->{first}) {
                if ($self_entry->{first}) {
                    my ($af, $bf) = ($self_entry->{first}, $entry->{first});
                    my ($ap, $bp);

                    if ($af < $bf) {
                        ($ap, $bp) = ($self_entry->{packed}, $entry->{packed});
                    } else {
                        ($af, $bf) = ($bf, $af);
                        ($ap, $bp) = ($entry->{packed}, $self_entry->{packed});
                    }
                    my $an = $af + length($ap) / 20;
                    my $bn = $bf + length($bp) / 20;

                    # TODO it does not handle overlapping ranges
                    #      (probably overkill)
                    if ($an == $bf) {
                        # contiguous
                        $self_entry->{first} = $af;
                        $self_entry->{packed} = $ap . $bp;
                    } elsif (
                            $an < $bf && (
                                ($bf - $an) < 5 ||
                                ($bf - $an) < ($bn - $af) / 5)) {
                        # close enough that leaving an "hole" is ok
                        $self_entry->{first} = $af;
                        $self_entry->{packed} = $ap . ($HOLE x ($bf - $an)) . $bp;
                    } else {
                        # unpack the second entry (arbitrary)
                        $self_entry->{first} = $af;
                        $self_entry->{packed} = $ap;

                        for my $i ($bf..$bf + length($bp) / 20 - 1) {
                            $self_entry->{sparse}{"(eval $i)"} =
                                substr $bp, ($i - $bf) * 20, 20;
                        }
                    }
                } else {
                    $self_entry->{first} = $entry->{first};
                    $self_entry->{packed} = $entry->{packed};
                }

                my $seen = $self->{seen_in_process}{$process_id} //= {};
                for my $i (0 .. length($entry->{packed}) / 20 - 1) {
                    my $name = "(eval " . ($entry->{first} + $i) . ")";
                    my $hash = substr $entry->{packed}, $i * 20, 20;

                    warn "Duplicate eval STRING source code for eval '$name'"
                        if exists $seen->{$name} &&
                            $seen->{$name} ne $hash;
                    $seen->{$name} = $hash;
                }
            }
        }
    }
}

sub load_and_merge {
    my ($self, @files) = @_;

    $self->_merge_source(read_data($self->{serializer}, $_))
        for @files;

    $self->_pack_data;
}

sub _get_source_by_hash {
    my ($self, $hash) = @_;

    return $self->{hashed}{$hash} //
        $self->{storage}->get_source_by_hash(unpack "H*", $hash);
}

sub _get_hash_by_name {
    my ($self, $process_id, $name) = @_;
    my ($ordinal) = sort { $b <=> $a } keys %{$self->{all}{$process_id} || {}};
    my ($p_id, $o) = ($process_id, $ordinal);

    for (;;) {
        if (my $by_process = $self->{all}{$p_id}) {
            # sorting is there for "extra correctness"
            for my $ord (sort { $b <=> $a } grep $_ <= $o, keys %$by_process) {
                my $entry = $by_process->{$ord};
                my $hash = $entry->{sparse}{$name};
                return $hash if $hash;
                if ($entry->{first} &&
                        $name =~ /^\(eval ([0-9]+)\)$/ &&
                        $1 >= $entry->{first} &&
                        $1 < $entry->{first} + length($entry->{packed}) / 20) {
                    return substr(
                        $entry->{packed},
                        ($1 - $entry->{first}) * 20,
                        20,
                    );
                }
            }
        }

        if ($self->{genealogy}{$p_id}) {
            # we only need to get a random value, but using just
            # each() returns undef from time to time (when it reaches the
            # end of the hash)
            keys(%{$self->{genealogy}{$p_id}});
            my (undef, $parent) = each %{$self->{genealogy}{$p_id}};

            if ($parent &&
                    # the root process has parent ['0000...0000', 0]
                    $parent->[1] != 0) {
                ($p_id, $o) = @$parent;
            } else {
                last;
            }
        } else {
            last;
        }
    }

    return undef;
}

sub get_hash_by_name {
    my ($self, $process_id, $name) = @_;
    my $hash = $self->_get_hash_by_name($process_id, $name);

    return $hash && $hash ne $HOLE ? unpack "H*", $hash : undef;
}

sub get_source_by_name {
    my ($self, $process_id, $name) = @_;
    my $hash = $self->_get_hash_by_name($process_id, $name);

    return $hash ? $self->_get_source_by_hash($hash) : '';
}

sub get_source_by_hash {
    my ($self, $hash) = @_;

    return $self->_get_source_by_hash(pack "H*", $hash);
}

sub delete_process {
    my ($self, $process_id) = @_;

    delete $self->{seen_in_process}{$process_id};
    delete $self->{all}{$process_id};
}

sub is_processed {
    my ($self, $process_id, $process_ordinal) = @_;
    my $genealogy = $self->{genealogy};

    return 1 if $genealogy &&
        $genealogy->{$process_id} &&
        $genealogy->{$process_id}{$process_ordinal};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Devel::StatProfiler::EvalSource

=head1 VERSION

version 0.56

=head1 AUTHORS

=over 4

=item *

Mattia Barbon <mattia@barbon.org>

=item *

Steffen Mueller <smueller@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Mattia Barbon, Steffen Mueller.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
