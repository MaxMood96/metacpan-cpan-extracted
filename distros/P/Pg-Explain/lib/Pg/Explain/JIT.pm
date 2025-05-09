package Pg::Explain::JIT;

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

use Carp;

=head1 NAME

Pg::Explain::JIT - Stores information about JIT from PostgreSQL's explain analyze.

=head1 VERSION

Version 2.9

=cut

our $VERSION = '2.9';

=head1 SYNOPSIS

This module provides wrapper around various information about JIT that can be parsed from plans returned by explain analyze in PostgreSQL.

Object of this class is created by Pg::Explain when parsing plan, and is later available as $explain->jit.

=head1 ACCESSORS

=head2 functions( [val] )

Returns/sets number of functions / operators that were JIT compiled.

=head2 options( [val] )

Returns/sets whole hashref of options that were used by JIT compiler.

=head2 option( name, [val] )

Returns/sets value of single option that was used by JIT compiler.

=head2 timings( [val] )

Returns/sets whole hashref of how long it took to process various stages of JIT compiling.

=head2 timing( name, [val] )

Returns/sets time of single stage of JIT compiling.

=cut

sub functions { my $self = shift; $self->{ 'functions' } = $_[ 0 ] if 0 < scalar @_; return $self->{ 'functions' }; }
sub options   { my $self = shift; $self->{ 'options' }   = $_[ 0 ] if 0 < scalar @_; return $self->{ 'options' }; }
sub timings   { my $self = shift; $self->{ 'timings' }   = $_[ 0 ] if 0 < scalar @_; return $self->{ 'timings' }; }

sub option { my $self = shift; my $name = shift; $self->options->{ $name } = $_[ 0 ] if 0 < scalar @_; return $self->options->{ $name }; }
sub timing { my $self = shift; my $name = shift; $self->timings->{ $name } = $_[ 0 ] if 0 < scalar @_; return $self->timings->{ $name }; }

=head1 METHODS

=head2 new

Object constructor. Should get one of:

=over

=item * struct - hashref based on parsing of JSON/YAML/XML plans

=item * lines - arrayref of strings containling lines describing JIT from text plans

=back

=cut

sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = bless {}, $class;
    $self->{ 'options' } = {};
    $self->{ 'timings' } = {};
    if ( $args{ 'struct' } ) {
        croak "Pg::Explain::JIT constructor cannot be called with both struct and lines!" if $args{ 'lines' };
        $self->_parse_struct( $args{ 'struct' } );
    }
    else {
        $self->_parse_lines( $args{ 'lines' } );
    }
    return $self;
}

=head2 as_text

Returns text that represents the JIT info as in explain analyze output for 'text' format.

=cut

sub as_text {
    my $self   = shift;
    my $output = "JIT:\n";
    if ( $self->functions ) {
        $output .= sprintf "  Functions: %s\n", $self->functions;
    }
    if ( 0 < scalar keys %{ $self->options } ) {
        my $str = join( ', ', map { "$_ " . ( $self->option( $_ ) ? "true" : "false" ) } keys %{ $self->options } );
        $output .= sprintf "  Options: %s\n", $str;
    }

    # Shortcircuit as logic to build timings line will be slightly longer than options…
    return $output if 0 == scalar keys %{ $self->timings };

    my @parts = ();
    for my $key ( sort keys %{ $self->timings } ) {
        my $val = $self->timings->{ $key };

        # Two potential cases, value is scalar, and it's simply time, and it's hash, in which case we have to build all subparts
        if ( '' eq ref $val ) {
            push @parts, "${key} ${val} ms";
            next;
        }

        # This is the more complex case:
        my @subelements = map { sprintf "%s %s ms", $_, $val->{ $_ } } grep { $_ ne 'Total' } sort keys %{ $val };
        push @parts, sprintf "%s %s ms (%s)", $key, $val->{ 'Total' }, join( ', ', @subelements );
    }
    $output .= sprintf "  Timing: %s\n", join( ', ', @parts );

    return $output;
}

=head1 INTERNAL METHODS

=head2 _parse_struct

Parses given struct, as returned from parsing JSON/YAML/XML formats.

=cut

sub _parse_struct {
    my $self   = shift;
    my $struct = shift;
    $self->functions( $struct->{ 'Functions' } );
    while ( my ( $key, $val ) = each %{ $struct->{ 'Options' } } ) {
        $val = undef if $val eq 'false';
        $self->option( $key, $val ? 1 : 0 );
    }
    $self->timings( $struct->{ 'Timing' } );
    return;
}

=head2 _parse_lines

Parses given lines, as parsed out of TEXT explain format.

=cut

sub _parse_lines {
    my $self  = shift;
    my $lines = shift;
    for my $line ( @{ $lines } ) {
        if ( $line =~ m{ \A \s* Functions: \s+ (\d+) \s* \z }xms ) {
            $self->functions( $1 );
        }
        elsif ( $line =~ m{ \A \s* Options: \s+ (\S.*\S) \s* \z }xms ) {
            my @parts = split( /\s*,\s*/, $1 );
            for my $e ( @parts ) {
                $e =~ s/\s*(true|false)\z//;
                $self->option( $e, $1 eq "true" ? 1 : 0 );
            }
        }
        elsif ( $line =~ m{ \A \s* Timing: \s+ (\S.*\S) \s* \z }xms ) {
            my $timings = $1;

            # Two types of timing information:
            # 1: "Optimization 11.314 ms"
            # 2: "Generation 0.327 ms (Deform 0.131 ms)"
            while (
                $timings =~ s{ \A
                    (?<name> \S+ )
                    \s+
                    (?<total> \d+\.\d+ )
                    \s+
                    ms
                    (?: \s+ \( (?<subelements> [^\)]+ ) \) )? 
                    (?: \z | , \s+ )
                }{}x
                )
            {
                my ( $t_name, $t_total, $t_subelements ) = ( $+{ 'name' }, $+{ 'total' }, $+{ 'subelements' } );
                if ( !defined $t_subelements ) {

                    # This is the simple format of timing information
                    $self->timing( $t_name, $t_total );
                    next;
                }

                # In here, we have subelements, so extract them separately, and put the total timing into Total key
                my @parts = $t_subelements =~ m{(\S+)\s+(\d+\.\d+)\s+ms(?:$|, )}g;
                my $val   = { @parts };
                $val->{ "Total" } = $t_total;
                $self->timing( $t_name, $val );
            }
        }
    }
}

=head1 AUTHOR

hubert depesz lubaczewski, C<< <depesz at depesz.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<depesz at depesz.com>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Pg::Explain::JIT

=head1 COPYRIGHT & LICENSE

Copyright 2008-2023 hubert depesz lubaczewski, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Pg::Explain::JIT
