package 
	TOTPDemo::Backend::Memory;

use strict;
use warnings;

my %TABLES;
my $NEXT = 1;

sub _rows { $TABLES{ $_[0] } ||= {} }

sub new { my ($class, %a) = @_; bless { table => $a{table} }, $class }

sub get { my ($self, %k) = @_; _rows($self->{table})->{ $k{id} } }

sub search {
    my ($self, $filter) = @_;
    my @rows = grep {
        my $row = $_;
        !grep { ($row->{$_} // '') ne ($filter->{$_} // '') }
             keys %{ $filter || {} };
    } values %{ _rows($self->{table}) };
    return { rows => \@rows, has_more_data => 0, next => undef };
}

sub all { $_[0]->search({}) }

sub create {
    my ($self, $d) = @_;
    my $row = { %$d };
    $row->{id} //= $NEXT++;
    _rows($self->{table})->{ $row->{id} } = $row;
    return { %$row };
}

sub update {
    my ($self, $d) = @_;
    my $row = _rows($self->{table})->{ $d->{id} } ||= {};
    @{$row}{ keys %$d } = values %$d;
    return { %$row };
}

sub delete {
    my ($self, %k) = @_;
    delete _rows($self->{table})->{ $k{id} } ? 1 : 0;
}

1;
