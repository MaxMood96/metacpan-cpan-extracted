package Bio::Palantir::Parser::Cluster;
# ABSTRACT: BiosynML DTD-derived internal class
$Bio::Palantir::Parser::Cluster::VERSION = '0.211420';
use Moose;
use namespace::autoclean;

# AUTOGENERATED CODE! DO NOT MODIFY THIS FILE!

use XML::Bare qw(forcearray);
use Data::UUID;

use aliased 'Bio::Palantir::Parser::Gene';
use aliased 'Bio::Palantir::Parser::Location';


# private attributes
has '_root' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
);

has 'module_delineation' => (
    is      => 'ro',
    isa     => 'Str',
);

has 'uui' => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    default  => sub {
        my $self = shift;
        my $ug = Data::UUID->new;
        my $uui = $ug->create_str();    
        return $uui;
    }
);

has 'rank' => (
    is      => 'ro',
    isa     => 'Num',
	default => -1,
	writer  => '_set_rank',
);


# public array(s) of composed objects


has 'genes' => (
    traits   => ['Array'],
    is       => 'ro',
    isa      => 'ArrayRef[Bio::Palantir::Parser::Gene]',
    handles  => {
         count_genes => 'count',
           all_genes => 'elements',
           get_gene  => 'get',
          next_gene  => 'shift',        
    },
);

with 'Bio::Palantir::Roles::Modulable';
## no critic (ProhibitUnusedPrivateSubroutines)


## use critic



# public composed object(s)


has 'locations' => (
    is       => 'ro',
    isa      => 'Bio::Palantir::Parser::Location',
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_locations',
	handles  => {
		      genomic_dna_begin => 'dna_begin',
		        genomic_dna_end => 'dna_end',
		       genomic_dna_size => 'dna_size',
        genomic_dna_coordinates => 'dna_coordinates',
         genomic_prot_begin => 'prot_begin',
           genomic_prot_end => 'prot_end',
          genomic_prot_size => 'prot_size',
       genomic_prot_coordinates => 'prot_coordinates',
	},
);

## no critic (ProhibitUnusedPrivateSubroutines)

sub _build_locations {
    my $self = shift;
    return Location->new(
        _root => $self->_root->{region}
    );
}

# use critic


# public deep methods


# public methods


sub name {
    return shift->_root->{'name'}->{'value'} // 'NA'
}


sub shortname {
    return shift->_root->{'shortname'}->{'value'} // 'NA'
}


sub status {
    return shift->_root->{'status'}->{'value'} // 'NA'
}


sub type {
    return shift->_root->{'type'}->{'value'} // 'NA'
}


sub identifier {
    return shift->_root->{'identifier'}->{'value'} // 'NA'
}


sub citation {
    return shift->_root->{'citation'}->{'value'} // 'NA'
}


sub sequence {
    return shift->_root->{'sequence'}->{'value'} // 'NA'
}



# public aliases


__PACKAGE__->meta->make_immutable;
1;

__END__

=pod

=head1 NAME

Bio::Palantir::Parser::Cluster - BiosynML DTD-derived internal class

=head1 VERSION

version 0.211420

=head1 SYNOPSIS

    # TODO

=head1 DESCRIPTION

    # TODO

=head1 ATTRIBUTES

=head2 genes

ArrayRef of L<Bio::Palantir::Parser::Gene>

=head2 locations

L<Bio::Palantir::Parser::Location> composed object

=head1 METHODS

=head2 count_genes

Returns the number of Genes of the Cluster.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $count = $cluster->count_genes;

This method does not accept any arguments.

=head2 all_genes

Returns all the Genes of the Cluster (not an array reference).

    # $cluster is a Bio::Palantir::Parser::Cluster
    my @genes = $cluster->all_genes;

This method does not accept any arguments.

=head2 get_gene

Returns one Gene of the Cluster by its index. You can also use
negative index numbers, just as with Perl's core array handling. If the
specified Gene does not exist, this method will return C<undef>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $gene = $cluster->get_gene($index);
    croak "Gene $index not found!" unless defined $gene;

This method accepts just one argument (and not an array slice).

=head2 next_gene

Shifts the first Gene of the array off and returns it, shortening the
array by 1 and moving everything down. If there are no more Genes in
the array, returns C<undef>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    while (my $gene = $cluster->next_gene) {
        # process $gene
        # ...
    }

This method does not accept any arguments.

=head2 name

Returns the value of the element C<<name>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $name = $cluster->name;

This method does not accept any arguments.

=head2 shortname

Returns the value of the element C<<shortname>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $shortname = $cluster->shortname;

This method does not accept any arguments.

=head2 status

Returns the value of the element C<<status>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $status = $cluster->status;

This method does not accept any arguments.

=head2 type

Returns the value of the element C<<type>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $type = $cluster->type;

This method does not accept any arguments.

=head2 identifier

Returns the value of the element C<<identifier>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $identifier = $cluster->identifier;

This method does not accept any arguments.

=head2 citation

Returns the value of the element C<<citation>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $citation = $cluster->citation;

This method does not accept any arguments.

=head2 sequence

Returns the value of the element C<<sequence>>.

    # $cluster is a Bio::Palantir::Parser::Cluster
    my $sequence = $cluster->sequence;

This method does not accept any arguments.

=head1 AUTHOR

Loic MEUNIER <lmeunier@uliege.be>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2019 by University of Liege / Unit of Eukaryotic Phylogenomics / Loic MEUNIER and Denis BAURAIN.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
