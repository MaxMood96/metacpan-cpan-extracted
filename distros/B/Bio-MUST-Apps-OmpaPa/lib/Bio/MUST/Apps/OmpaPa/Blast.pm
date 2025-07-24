package Bio::MUST::Apps::OmpaPa::Blast;
# ABSTRACT: internal class for XML BLAST parser
# CONTRIBUTOR: Amandine BERTRAND <amandine.bertrand@doct.uliege.be>
$Bio::MUST::Apps::OmpaPa::Blast::VERSION = '0.252040';
use Moose;
use namespace::autoclean;

use autodie;
use feature qw(say);

use Smart::Comments;

use Carp;

extends 'Bio::FastParsers::Blast::Xml';
with 'Bio::MUST::Apps::OmpaPa::Roles::Parsable';


sub collect_hits {
    my $self = shift;

    my @hits;

    # parse BLAST report
    my $iter = $self->blast_output->next_iteration;
    my $qlen = $iter->query_len;

    HIT:
    while (my $hit = $iter->next_hit) {

        # honor --max-hits limit
        if (@hits >= $self->max_hits) {
            carp 'Reached --max-hits limit; truncating report!';
            last HIT;
        }

        # split hit desc on Ctrl-A and keep only first line (nr database)
        # this is needed for table formatting as Ctrl-A has zero-width
        my ($desc) = split /\cA.*/xms, ( $hit->def // $hit->id );
        my $hsp = $hit->next_hsp;       # workaround for XML report change

        # collect useful hit/HSP attributes
        push @hits, {
            'acc'       => ( $hit->id =~ m/^gnl\|/xms ? $hit->def : $hit->id ),
                        # workaround to accommodate change in BLAST XML report
            'dsc'       => $desc,
            'exp'       => $hsp->evalue,
            'bit'       => $hsp->bit_score,
            'qlen'      => $qlen,
            'len'       => $hit->len,
            'hmm_from'  => $hsp->query_start,       # for consistent naming
            'hmm_to'    => $hsp->query_end,
        };
    }

    return \@hits;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

Bio::MUST::Apps::OmpaPa::Blast - internal class for XML BLAST parser

=head1 VERSION

version 0.252040

=head1 SYNOPSIS

    # TODO

=head1 DESCRIPTION

    # TODO

=head1 AUTHOR

Denis BAURAIN <denis.baurain@uliege.be>

=head1 CONTRIBUTOR

=for stopwords Amandine BERTRAND

Amandine BERTRAND <amandine.bertrand@doct.uliege.be>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by University of Liege / Unit of Eukaryotic Phylogenomics / Denis BAURAIN.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
