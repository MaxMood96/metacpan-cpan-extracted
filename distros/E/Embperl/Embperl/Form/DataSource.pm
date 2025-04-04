
###################################################################################
#
#   Embperl - Copyright (c) 1997-2008 Gerald Richter / ecos gmbh  www.ecos.de
#   Embperl - Copyright (c) 2008-2015 Gerald Richter
#   Embperl - Copyright (c) 2015-2023 actevy.io
#
#   You may distribute under the terms of either the GNU General Public
#   License or the Artistic License, as specified in the Perl README file.
#
#   THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
#   IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
#   WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
###################################################################################

package Embperl::Form::DataSource ;

use strict ;

# ---------------------------------------------------------------------------
#
#   new - create a new datasource object
#


sub new

    {
    my ($class, $args) = @_ ;

    my $self = {datsrc => $args -> {datasrc}} ;
    bless $self, $class ;

    $self -> init ($args) ;

    return $self ;
    }

# ---------------------------------------------------------------------------
#
#   init - init the new datasource object
#

sub init

    {
    my ($self) = @_ ;

    return $self ;
    }

# ---------------------------------------------------------------------------
#
#   values_no_cache - returns true to inhibit cacheing of values during one request
#

sub values_no_cache { 0 }

# ---------------------------------------------------------------------------
#
#   constrain_attrs - returns attrs that might change the form layout
#                     if there value changes
#

sub constrain_attrs

    {
    my ($self, $req) = @_ ;

    return () if (!$self -> {constrain}) ;
    return ($self -> {constrain}) ;
    }

# ---------------------------------------------------------------------------
#
#   get_constrain_value - returns the constrain value that is need for a
#                         search or undef if there is no constrain
#
#   in  $req        request data
#       $ctrl       control that will display the value
#   ret $constrain          contrain value if any
#       $without_contrain   true if also values that have no contrain value
#                           are part of the resultset
#

sub get_constrain_value

    {
    my ($self, $req, $ctrl) = @_ ;

    return ;
    }
    

# ---------------------------------------------------------------------------
#
#   get_url_modifier - returns modifier for url for requesting datasrc values (selectdyn)
#
#   in  $req        request data
#       $ctrl       control that will display the value
#   ret $search
#       $replace
#

sub get_url_modifier

    {
    my ($self, $req, $ctrl) = @_ ;

    return ;
    }
    
# ---------------------------------------------------------------------------
#
#   get_dbname - returns dbname to pass to control (selectdyn)
#
#   in  $req        request data
#       $ctrl       control that will display the value
#   ret $dbname     if any
#

sub get_dbname

    {
    my ($self, $req, $ctrl) = @_ ;

    return  ;
    }
    
# ---------------------------------------------------------------------------
#
#   sorttype - returns information how to sort this datasource values for displaying
#

sub sorttype { undef }

# ---------------------------------------------------------------------------
#
#   get_values - returns the values and options
#

sub get_values

    {
    my ($self, $req) = @_ ;

    die "Please overwrite get_values in " . ref $self ;
    }

# ---------------------------------------------------------------------------
#
#   get_option_from_value - returns the option for a given value
#
#   in  $value  value
#   ret         option
#

sub get_option_from_value

    {
    my ($self, $value, $req, $ctrl) = @_ ;
    
    
    my ($values, $options) = $self -> get_values ($req, $ctrl) ;

    my $i = 0 ;
    foreach (@$values)
        {
        if ($_ eq $value)
            {
            return $options -> [$i] ;
            }
        $i++ ;
        }

    return ;
    }

# ---------------------------------------------------------------------------
#
#   get_value_from_option - returns the value for a given option
#
#   in  $option option
#   ret         value
#

sub get_value_from_option

    {
    my ($self, $option, $req, $ctrl) = @_ ;
    
    
    my ($values, $options) = $self -> get_values ($req, $ctrl) ;

    my $i = 0 ;
    foreach (@$options)
        {
        if ($_ eq $option)
            {
            return $values -> [$i] ;
            }
        $i++ ;
        }

    return ;
    }

# ---------------------------------------------------------------------------
#
#   get_value_from_id - returns the value for a given id
#
#   in  $id     id
#   ret         value
#

sub get_value_from_id

    {
    my ($self, $option, $req, $ctrl) = @_ ;
    
    return ;
    }


# ---------------------------------------------------------------------------
#
#   get_id_from_value - returns id for a given value
#

sub get_id_from_value

    {
    my ($self, $value, $req) = @_ ;

    return $value ;
    }

# ---------------------------------------------------------------------------
#
#   get_datasource_controls - returns additional controls provided by the
#   datasource object e.g. a browse button
#

sub get_datasource_controls

    {
    my ($self, $req, $ctrl) = @_ ;

    return ;
    }


1 ;

__END__

=pod

=head1 NAME

Embperl::Form::DataSource - Base class for data source objects
which provides the data for ControlMutlValue objects.


=head1 SYNOPSIS

Do not use directly, instead derive a class

=head1 DESCRIPTION

This class is not used directly, it is used as a base class for
all data source objects.
It provides a set of methods
that could be overwritten to customize the behaviour of your controls.

=head1 METHODS

=head2 get_values

returns the values and options. Must be overwritten.

=head3 get_id_from_value

returns an id for a given value. This allows one to have an id form a value/option
pair which is not exactly the same as the value. This is used in json requests
for example for selectdyn control.

=head3 get_datasource_controls 

returns additional controls provided by the
datasource object e.g. a browse button

=head1 AUTHOR

G. Richter (richter at embperl dot org)

=head1 SEE ALSO

perl(1), Embperl, Embperl::Form, Embperl::From::ControlMultValue



