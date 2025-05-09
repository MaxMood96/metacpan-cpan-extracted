package Pg::Explain::FromXML;

# UTF8 boilerplace, per http://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/
use v5.18;
use strict;
use warnings;
use warnings qw( FATAL utf8 );
use utf8;
use open qw( :std :utf8 );
use Unicode::Normalize qw( NFC );
use Unicode::Collate;
use Encode qw( decode );

if ( grep /\P{ASCII}/ => @ARGV ) {
    @ARGV = map { decode( 'UTF-8', $_ ) } @ARGV;
}

# UTF8 boilerplace, per http://stackoverflow.com/questions/6162484/why-does-modern-perl-avoid-utf-8-by-default/

use base qw( Pg::Explain::From );
use XML::Simple;
use Carp;
use Pg::Explain::JIT;
use Pg::Explain::Buffers;

=head1 NAME

Pg::Explain::FromXML - Parser for explains in XML format

=head1 VERSION

Version 2.9

=cut

our $VERSION = '2.9';

=head1 SYNOPSIS

It's internal class to wrap some work. It should be used by Pg::Explain, and not directly.

=head1 FUNCTIONS

=head2 normalize_node_struct

XML structure is different than JSON/YAML (after parsing), so we need to normalize it.
=cut

sub normalize_node_struct {
    my $self   = shift;
    my $struct = shift;

    my @keys = keys %{ $struct };
    for my $key ( @keys ) {
        my $new_key = $key;
        $new_key =~ s{^I-O-(Read|Write)-Time$}{I/O $1 Time};
        $new_key =~ s/-/ /g;
        $struct->{ $new_key } = delete $struct->{ $key } if $key ne $new_key;
    }

    my $subplans = [];
    if (   ( $struct->{ 'Plans' } )
        && ( $struct->{ 'Plans' }->{ 'Plan' } ) )
    {
        if ( 'HASH' eq ref $struct->{ 'Plans' }->{ 'Plan' } ) {
            push @{ $subplans }, $struct->{ 'Plans' }->{ 'Plan' };
        }
        else {
            $subplans = $struct->{ 'Plans' }->{ 'Plan' };
        }
    }
    $struct->{ 'Plans' } = $subplans;

    if ( $struct->{ 'Group Key' } ) {
        my $items = $struct->{ 'Group Key' }->{ 'Item' };
        if ( 'ARRAY' eq ref $items ) {
            $struct->{ 'Group Key' } = $items;
        }
        else {
            $struct->{ 'Group Key' } = [ $items ];
        }
    }

    if ( $struct->{ 'Conflict Arbiter Indexes' } ) {
        $struct->{ 'Conflict Arbiter Indexes' } = [ $struct->{ 'Conflict Arbiter Indexes' }->{ 'Item' } ];
    }
    return $struct;
}

=head2 parse_source

Function which parses actual plan, and constructs Pg::Explain::Node objects
which represent it.

Returns Top node of query plan.

=cut

sub parse_source {
    my $self   = shift;
    my $source = shift;

    unless ( $source =~ s{\A .*? ^ \s* (<explain \s+ xmlns="http://www.postgresql.org/2009/explain">) \s* $}{$1}xms ) {
        carp( 'Source does not match first s///' );
        return;
    }
    unless ( $source =~ s{^ \s* </explain> \s* $ .* \z}{</explain>}xms ) {
        carp( 'Source does not match second s///' );
        return;
    }

    my $struct = XMLin( $source );

    # Need this to work around a bit different format from auto-explain module
    $struct = $struct->{ 'Query' } if defined $struct->{ 'Query' };

    my $top_node = $self->make_node_from( $struct->{ 'Plan' } );

    if ( $struct->{ 'Planning' } ) {
        $self->explain->planning_time( $struct->{ 'Planning' }->{ 'Planning-Time' } );
        my $buffers = Pg::Explain::Buffers->new( $self->normalize_node_struct( $struct->{ 'Planning' } ) );
        $self->explain->planning_buffers( $buffers ) if $buffers;
    }
    elsif ( $struct->{ 'Planning-Time' } ) {
        $self->explain->planning_time( $struct->{ 'Planning-Time' } );
    }
    $self->explain->execution_time( $struct->{ 'Execution-Time' } ) if $struct->{ 'Execution-Time' };
    $self->explain->total_runtime( $struct->{ 'Total-Runtime' } )   if $struct->{ 'Total-Runtime' };
    if ( $struct->{ 'Triggers' } ) {
        for my $t ( @{ $struct->{ 'Triggers' }->{ 'Trigger' } } ) {
            my $ts = {};
            $ts->{ 'calls' }    = $t->{ 'Calls' }        if defined $t->{ 'Calls' };
            $ts->{ 'time' }     = $t->{ 'Time' }         if defined $t->{ 'Time' };
            $ts->{ 'relation' } = $t->{ 'Relation' }     if defined $t->{ 'Relation' };
            $ts->{ 'name' }     = $t->{ 'Trigger-Name' } if defined $t->{ 'Trigger-Name' };
            $self->explain->add_trigger_time( $ts );
        }
    }
    $self->explain->jit( Pg::Explain::JIT->new( 'struct' => $struct->{ 'JIT' } ) ) if $struct->{ 'JIT' };

    $self->explain->query( $struct->{ 'Query-Text' } ) if $struct->{ 'Query-Text' };

    $self->explain->settings( $struct->{ 'Settings' } ) if ( $struct->{ 'Settings' } ) && ( 0 < scalar keys %{ $struct->{ 'Settings' } } );

    return $top_node;
}

=head1 AUTHOR

hubert depesz lubaczewski, C<< <depesz at depesz.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<depesz at depesz.com>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Pg::Explain

=head1 COPYRIGHT & LICENSE

Copyright 2008-2023 hubert depesz lubaczewski, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Pg::Explain::FromXML
