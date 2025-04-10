package Benchmark::Perl::Formance::Plugin::AccessorsHash;
our $AUTHORITY = 'cpan:SCHWIGON';
# ABSTRACT: benchmark plugin - Compare OO'ish accessors

use strict;
use warnings;

our $VERSION = "0.001";

#############################################################
#                                                           #
# Benchmark Code ahead - Don't touch without strong reason! #
#                                                           #
#############################################################

our $goal;
our $count;

use Benchmark ':hireswallclock';

sub new {
        bless { zomtec => 42 }, shift;
}

sub zomtec
{
        my $self = shift;

        $self->{zomtec} = $_[0] if @_;
        return $self->{zomtec};
}

sub main
{
        my ($options) = @_;

        # ensure same values over all Accessors* plugins!
        $goal  = $options->{fastmode} ? 100_000 : 2_000_000;
        $count = 5;

        my $result;
        my $obj = __PACKAGE__->new;
        my $t_get   = timeit $count, sub { $result = $obj->zomtec()   for 1..$goal };
        my $t_set   = timeit $count, sub { $result = $obj->zomtec(23) for 1..$goal };
        return {
                get => {
                        Benchmark => $t_get,
                        result    => $result,
                        goal      => $goal,
                       },
                set => {
                        Benchmark => $t_set,
                        result    => $result,
                        goal      => $goal,
                       },
               };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Benchmark::Perl::Formance::Plugin::AccessorsHash - benchmark plugin - Compare OO'ish accessors

=head1 AUTHOR

Steffen Schwigon <ss5@renormalist.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Steffen Schwigon.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
