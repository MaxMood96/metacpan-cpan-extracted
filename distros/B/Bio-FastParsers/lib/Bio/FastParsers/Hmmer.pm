package Bio::FastParsers::Hmmer;
# ABSTRACT: Classes for parsing HMMER output
# CONTRIBUTOR: Arnaud DI FRANCO <arnaud.difranco@gmail.com>
$Bio::FastParsers::Hmmer::VERSION = '0.221230';
use strict;
use warnings;

use Bio::FastParsers::Hmmer::Model;
use Bio::FastParsers::Hmmer::Standard;
use Bio::FastParsers::Hmmer::Table;
use Bio::FastParsers::Hmmer::DomTable;

1;

__END__

=pod

=head1 NAME

Bio::FastParsers::Hmmer - Classes for parsing HMMER output

=head1 VERSION

version 0.221230

=head1 SYNOPSIS

    # see Bio::FastParsers::Hmmer::Model
    # see Bio::FastParsers::Hmmer::Standard
    # see Bio::FastParsers::Hmmer::Table;
    # see Bio::FastParsers::Hmmer::DomTable;

=head1 DESCRIPTION

Parsers for the HMMER model and three output formats are available: standard,
tabular and domain-wise tabular.

=head1 AUTHOR

Denis BAURAIN <denis.baurain@uliege.be>

=head1 CONTRIBUTOR

=for stopwords Arnaud DI FRANCO

Arnaud DI FRANCO <arnaud.difranco@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by University of Liege / Unit of Eukaryotic Phylogenomics / Denis BAURAIN.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
